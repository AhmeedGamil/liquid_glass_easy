import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_uniforms.dart';

class LiquidGlassPainter extends CustomPainter {
  final LiquidGlassPosition position;
  final Offset? dragOffset;
  final double lensWidth;
  final double lensHeight;
  final double magnification;
  final double refractionIndex;
  final double refractionWidth;
  final bool draggable;
  final Size parentSize;
  final LiquidGlassLitShape? border;
  final double borderAlpha;
  final double blur;
  final double dispersion;
  final double saturation;
  final Color color;
  final ui.FragmentShader shader;
  final ui.FragmentShader? borderShader;

  final ui.Image? image;

  /// Paint-time capture fallback. When [image] is null (first frame of a
  /// freshly created view, before any capture has landed), `paint()`
  /// calls this to synchronously rasterize the background boundary —
  /// which has already painted earlier in the same frame — so the lens
  /// refracts correctly with no one-frame gap. The fallback always
  /// captures the full frame, matching the null [imageOffset]/[imageSize]
  /// this painter is constructed with in that situation. Returns null on
  /// failure, in which case the lens skips this frame (soft-fail).
  final ui.Image? Function()? imageFallback;

  /// Top-left (in parent logical px) of the parent-space rectangle the
  /// captured [image] covers. `null` → full-frame capture (offset zero).
  /// Deformed size / rest size while a touch deformation runs; `(1,1)` when
  /// undeformed. Feeds `u_shapeScale` so the shape is evaluated at REST size
  /// -- a stretched circle stays an ellipse instead of growing flat runs.
  final Offset shapeScale;

  final Offset? imageOffset;

  /// Size (in parent logical px) of the parent-space rectangle the
  /// captured [image] covers. `null` → full-frame capture (== resolution).
  final Size? imageSize;

  /// Whether to fold the captured backdrop's alpha into the lens coverage
  /// (the shader's `u_honorBackdropAlpha`). Only meaningful when the
  /// captured background carries *authored* transparency — i.e. the
  /// slider/toggle, whose track is a mostly-transparent capture that must
  /// show the real screen through the glass. `false` (the default) treats
  /// the capture as opaque, matching Impeller; honoring a non-transparent
  /// capture's alpha would otherwise wash the body white and drop the rim.
  final bool honorBackdropAlpha;

  LiquidGlassPainter({
    required this.position,
    required this.dragOffset,
    required this.lensWidth,
    required this.lensHeight,
    required this.magnification,
    required this.refractionIndex,
    required this.refractionWidth,
    required this.draggable,
    required this.parentSize,
    required this.border,
    required this.borderAlpha,
    required this.blur,
    required this.color,
    required this.shader,
    this.borderShader,
    required this.dispersion,
    required this.saturation,
    required this.image,
    this.imageFallback,
    this.shapeScale = const Offset(1, 1),
    this.imageOffset,
    this.imageSize,
    this.honorBackdropAlpha = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? sampledImage = image ?? imageFallback?.call();
    if (sampledImage == null) return;

    final bool useBlur = blur > 0;
    final lensPosition = dragOffset!;

    int index = 0;
    // Pass shader parameters (uniforms) for the GLSL shader
    shader.setFloat(index++, size.width);
    shader.setFloat(index++, size.height);
    shader.setFloat(index++, lensPosition.dx);
    shader.setFloat(index++, lensPosition.dy);

    shader.setFloat(index++, lensWidth);
    shader.setFloat(index++, lensHeight);
    // u_cornerRadius
    shader.setFloat(index++, border?.cornerRadius ?? 0);
    // u_cornerStyle: 2 = continuous (capsule), 1 = squircle, 0 = circular
    shader.setFloat(
        index++, border != null ? liquidGlassCornerStyle(border!) : 0);

    // u_warp = (magnification, refractionIndex, refractionWidthPx,
    // dispersion)
    shader.setFloat(index++, magnification);
    shader.setFloat(index++, refractionIndex);
    shader.setFloat(index++, refractionWidth);
    shader.setFloat(index++, dispersion);

    // The authored border width in logical px, verbatim — the shader
    // expands it into the border's own band.
    // Blur path: suppress the border in the main shader so the
    // second-pass painter draws it sharp on top of the blur.
    shader.setFloat(index++, (!useBlur) ? border!.specular.thickness : 0);
    // u_borderAlpha
    shader.setFloat(index++, borderAlpha);

    // u_specularColor, u_glowColor
    index = packLiquidGlassLightColor(shader, index, border!.specular.color);
    index = packLiquidGlassLightColor(shader, index, border!.glow.color);

    // u_lensColor
    shader.setFloat(index++, color.r);
    shader.setFloat(index++, color.g);
    shader.setFloat(index++, color.b);
    shader.setFloat(index++, color.a);
    // u_packA = (specularIntensity, saturation, glowIntensity, glowThickness)
    shader.setFloat(index++, border!.specular.intensity);
    shader.setFloat(index++, saturation);
    shader.setFloat(index++, border!.glow.intensity);
    shader.setFloat(index++, (!useBlur) ? border!.glow.thickness : 0);
    // u_packB = (specularAngle, specularSpread, borderSharpness, glowAngle)
    shader.setFloat(index++, border!.specular.angle);
    shader.setFloat(index++, border!.specular.spread);
    shader.setFloat(index++, border!.specular.sharpness);
    shader.setFloat(index++, border!.glow.angle);
    // u_packC, u_specular2, u_specular2Color, u_lightOpposite
    index = packLiquidGlassSecondSpecular(shader, index, border!,
        scale: 1,
        drawBorder: !useBlur);

    // u_imageOffset / u_imageSize — map the bound texture to a parent-space
    // rect. Full-frame default: offset (0,0), size == resolution (`size`),
    // which reproduces the old `refrPx / u_resolution` sampling exactly.
    final Offset imgOffset = imageOffset ?? Offset.zero;
    final Size imgSize = imageSize ?? size;
    shader.setFloat(index++, imgOffset.dx);
    shader.setFloat(index++, imgOffset.dy);
    shader.setFloat(index++, imgSize.width);
    shader.setFloat(index++, imgSize.height);

    // u_honorBackdropAlpha — only fold the captured backdrop's alpha into
    // coverage when the capture carries authored transparency (slider /
    // toggle track). Otherwise treat it as opaque (matching Impeller),
    // else a non-transparent capture's alpha washes the body white and
    // drops the rim. Set per-view via [LiquidGlassView.honorBackdropAlpha].
    shader.setFloat(index++, honorBackdropAlpha ? 1.0 : 0.0);
    // u_shapeAaPx — the Skia CustomPaint path runs in logical px, so the
    // edge-AA band is one logical pixel: pass 1.0 (Impeller passes dpr via
    // packLiquidGlassUniforms). Last uniform in liquid_glass.frag.
    shader.setFloat(index++, 1.0);
    // u_shapeScale — last uniform; a ratio, so never scaled.
    shader.setFloat(index++, shapeScale.dx == 0 ? 1.0 : shapeScale.dx);
    shader.setFloat(index++, shapeScale.dy == 0 ? 1.0 : shapeScale.dy);

    shader.setImageSampler(0, sampledImage);

    // final borderExpand = border!.borderWidth / 2;
    // final rectExpandedBorder = Rect.fromLTWH(
    //   lensPosition.dx - borderExpand,
    //   lensPosition.dy - borderExpand,
    //   lensWidth + 2 * borderExpand,
    //   lensHeight + 2 * borderExpand,
    // );
    final rectExpandedBorder = Rect.fromLTWH(
      lensPosition.dx,
      lensPosition.dy,
      lensWidth,
      lensHeight,
    );

    final rectRRect = RRect.fromRectAndRadius(
      rectExpandedBorder,
      Radius.circular(liquidGlassClipCornerRadius(border!)),
    );

    //canvas.save();
    canvas.clipRRect(rectRRect);

    final lensPaint = Paint()..shader = shader;
    canvas.drawRRect(rectRRect, lensPaint);
    //canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) {
    // IMPORTANT (do not shorten this list): the previous implementation
    // compared only `image` and `borderAlpha` and ignored changes to
    // `lensWidth`/`lensHeight`/`cornerRadius`/`color` and other uniforms.
    // In debug builds this was masked by the fact that `_image` changes
    // every frame (so the canvas would repaint regardless). On release
    // builds with Impeller, `toImageSync` can silently fail, so the image
    // stops changing — and the canvas shader then freezes with stale
    // uniforms even though the widget tree already holds a different
    // lens configuration. That's what caused "stale lens content" and
    // "transparent lenses" on release/profile builds.
    //
    // Comparing every parameter guarantees that any real change to the
    // lens configuration triggers a repaint.
    return oldDelegate.image != image ||
        oldDelegate.dragOffset != dragOffset ||
        oldDelegate.lensWidth != lensWidth ||
        oldDelegate.lensHeight != lensHeight ||
        oldDelegate.magnification != magnification ||
        oldDelegate.refractionIndex != refractionIndex ||
        oldDelegate.refractionWidth != refractionWidth ||
        oldDelegate.parentSize != parentSize ||
        !_shapeEquals(oldDelegate.border, border) ||
        oldDelegate.borderAlpha != borderAlpha ||
        oldDelegate.blur != blur ||
        oldDelegate.color != color ||
        oldDelegate.dispersion != dispersion ||
        oldDelegate.saturation != saturation ||
        oldDelegate.shader != shader ||
        oldDelegate.borderShader != borderShader ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.honorBackdropAlpha != honorBackdropAlpha;
  }

  bool _shapeEquals(LiquidGlassLitShape? a, LiquidGlassLitShape? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.runtimeType != b.runtimeType) return false;
    if (!LiquidGlassLitShape.sameBorder(a, b)) return false;
    return a.cornerStyle == b.cornerStyle &&
        a.cornerRadius == b.cornerRadius &&
        a.clipQuality == b.clipQuality;
  }
}

class LiquidGlassBorderPainter extends CustomPainter {
  final ui.FragmentShader borderShader;
  final Offset lensPosition;
  final double lensWidth;
  final double lensHeight;
  final double magnification;
  final double refractionIndex;
  final double refractionWidth;
  final double dispersion;
  final double saturation;
  final LiquidGlassLitShape border;
  final double borderAlpha;
  /// The lens's material colour. The rim lifts from the tinted glass, so
  /// the border shader needs it as much as the main pass does.
  final Color lensColor;
  final ui.Image? image;

  /// See [LiquidGlassPainter.imageFallback]. Paint-time synchronous
  /// capture used when [image] is still null on the first frame.
  final ui.Image? Function()? imageFallback;

  /// See [LiquidGlassPainter.imageOffset]. `null` → full-frame.
  /// Deformed size / rest size while a touch deformation runs; `(1,1)` when
  /// undeformed. Feeds `u_shapeScale` so the shape is evaluated at REST size
  /// -- a stretched circle stays an ellipse instead of growing flat runs.
  final Offset shapeScale;

  final Offset? imageOffset;

  /// See [LiquidGlassPainter.imageSize]. `null` → full-frame.
  final Size? imageSize;

  LiquidGlassBorderPainter({
    required this.borderShader,
    required this.lensPosition,
    required this.lensWidth,
    required this.lensHeight,
    required this.magnification,
    required this.refractionIndex,
    required this.refractionWidth,
    required this.dispersion,
    required this.saturation,
    required this.border,
    required this.borderAlpha,
    required this.image,
    this.lensColor = const Color(0x00000000),
    this.imageFallback,
    this.shapeScale = const Offset(1, 1),
    this.imageOffset,
    this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? sampledImage = image ?? imageFallback?.call();
    if (sampledImage == null) return;


    final rect = Rect.fromLTWH(
      lensPosition.dx,
      lensPosition.dy,
      lensWidth,
      lensHeight,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(liquidGlassClipCornerRadius(border)),
    );

    int index = 0;
    borderShader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, lensPosition.dx)
      ..setFloat(index++, lensPosition.dy)
      ..setFloat(index++, lensWidth)
      ..setFloat(index++, lensHeight)
      // u_cornerRadius
      ..setFloat(index++, border.cornerRadius)
      // u_cornerStyle: 2 = continuous (capsule), 1 = squircle, 0 = circular
      ..setFloat(index++, liquidGlassCornerStyle(border))
      // u_warp = (magnification, refractionIndex, refractionWidthPx,
      // dispersion)
      ..setFloat(index++, magnification)
      ..setFloat(index++, refractionIndex)
      ..setFloat(index++, refractionWidth)
      ..setFloat(index++, dispersion)
      // The authored border width in logical px, as the main pass and the
      // Impeller path pass it.
      ..setFloat(index++, border.specular.thickness)
      // u_borderAlpha
      ..setFloat(index++, borderAlpha);
    // u_specularColor, u_glowColor
    index = packLiquidGlassLightColor(borderShader, index, border.specular.color);
    index = packLiquidGlassLightColor(borderShader, index, border.glow.color);
    borderShader
      // u_lensColor — the same slot as the main shader.
      ..setFloat(index++, lensColor.r)
      ..setFloat(index++, lensColor.g)
      ..setFloat(index++, lensColor.b)
      ..setFloat(index++, lensColor.a)
      // u_packA = (specularIntensity, saturation, glowIntensity, glowThickness)
      ..setFloat(index++, border.specular.intensity)
      ..setFloat(index++, saturation)
      ..setFloat(index++, border.glow.intensity)
      ..setFloat(index++, border.glow.thickness)
      // u_packB = (specularAngle, specularSpread, borderSharpness, glowAngle)
      ..setFloat(index++, border.specular.angle)
      ..setFloat(index++, border.specular.spread)
      ..setFloat(index++, border.specular.sharpness)
      ..setFloat(index++, border.glow.angle);
    // u_packC, u_specular2, u_specular2Color, u_lightOpposite
    index = packLiquidGlassSecondSpecular(borderShader, index, border,
        scale: 1,
        drawBorder: true);

    // u_imageOffset / u_imageSize — full-frame default: (0,0) / size.
    final Offset imgOffset = imageOffset ?? Offset.zero;
    final Size imgSize = imageSize ?? size;
    borderShader
      ..setFloat(index++, imgOffset.dx)
      ..setFloat(index++, imgOffset.dy)
      ..setFloat(index++, imgSize.width)
      ..setFloat(index++, imgSize.height)
      // u_shapeScale — must match the main pass or the rim leaves the fill.
      ..setFloat(index++, shapeScale.dx == 0 ? 1.0 : shapeScale.dx)
      ..setFloat(index++, shapeScale.dy == 0 ? 1.0 : shapeScale.dy);

    borderShader.setImageSampler(0, sampledImage);

    final paint = Paint()..shader = borderShader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidGlassBorderPainter oldDelegate) {
    // Mirror LiquidGlassPainter.shouldRepaint: only repaint when a value
    // that actually feeds the border shader changes. Previously this
    // returned `true` unconditionally, so the second-pass border shader
    // re-ran every frame even for a completely idle lens.
    return oldDelegate.image != image ||
        oldDelegate.lensPosition != lensPosition ||
        oldDelegate.lensWidth != lensWidth ||
        oldDelegate.lensHeight != lensHeight ||
        oldDelegate.magnification != magnification ||
        oldDelegate.refractionIndex != refractionIndex ||
        oldDelegate.refractionWidth != refractionWidth ||
        oldDelegate.dispersion != dispersion ||
        oldDelegate.saturation != saturation ||
        oldDelegate.borderAlpha != borderAlpha ||
        oldDelegate.lensColor != lensColor ||
        oldDelegate.borderShader != borderShader ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageSize != imageSize ||
        !_shapeEquals(oldDelegate.border, border);
  }

  bool _shapeEquals(LiquidGlassLitShape a, LiquidGlassLitShape b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;
    if (!LiquidGlassLitShape.sameBorder(a, b)) return false;
    return a.cornerStyle == b.cornerStyle &&
        a.cornerRadius == b.cornerRadius &&
        a.clipQuality == b.clipQuality;
  }
}
