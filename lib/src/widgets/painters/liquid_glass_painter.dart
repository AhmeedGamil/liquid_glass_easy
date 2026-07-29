import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_light_mode.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_refraction_mode.dart';
import '../utils/liquid_glass_refraction_type.dart';
import '../utils/liquid_glass_shape.dart';

class LiquidGlassPainter extends CustomPainter {
  final LiquidGlassPosition position;
  final Offset? dragOffset;
  final double lensWidth;
  final double lensHeight;
  final double magnification;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final bool enableInnerRadiusTransparent;
  final bool draggable;
  final Size parentSize;
  final LiquidGlassShape? border;
  final double borderAlpha;
  final LiquidGlassBlur blur;
  final double chromaticAberration;
  final double saturation;
  final LiquidGlassRefractionMode? refractionMode;
  final LiquidGlassRefractionType? refractionType;
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
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.enableInnerRadiusTransparent,
    required this.draggable,
    required this.parentSize,
    required this.border,
    required this.borderAlpha,
    required this.blur,
    required this.color,
    required this.shader,
    this.borderShader,
    required this.chromaticAberration,
    required this.saturation,
    required this.refractionMode,
    required this.refractionType,
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

    final bool useBlur = blur.sigmaX > 0 || blur.sigmaY > 0;
    final lensPosition = dragOffset!;
    final double selectedLightMode =
        (border!.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
    final double selectedRefractionMode =
        (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;
    final double selectedRefractionType =
        (refractionType?.isOptical ?? false) ? 1 : 0;
    final double refractionIndex = switch (refractionType) {
      OpticalRefraction(:final refraction) => refraction,
      _ => 1.0,
    };
    final double selectedBorderMode =
        (border!.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;

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

    shader.setFloat(index++, magnification);
    shader.setFloat(index++, distortion);
    shader.setFloat(index++, distortionWidth);

    shader.setFloat(index++, enableInnerRadiusTransparent ? 1.0 : 0.0);
    shader.setFloat(index++, diagonalFlip);

    // No-blur path: main shader draws the border itself. We pass the
    // full border-band width: doubled (the band is centered on the edge
    // and its outer half is clipped by `canvas.clipRRect` below, leaving
    // the intended width inside the shape), plus the optical-mode extra
    // — historically a `+ 2` inside the shader, now added here in
    // logical px so it scales consistently across the Skia and Impeller
    // shader spaces.
    // Blur path: suppress the border in the main shader so the
    // second-pass painter draws it sharp on top of the blur.
    final double opticalExtra =
        (border!.isOpticalBorder && border!.borderWidth > 0) ? 2.0 : 0.0;
    shader.setFloat(
        index++, (!useBlur) ? border!.borderWidth * 2.0 + opticalExtra : 0);
    shader.setFloat(index++, border!.borderSoftness);

    shader.setFloat(index++, border!.borderColor?.r ?? 0);
    shader.setFloat(index++, border!.borderColor?.g ?? 0);
    shader.setFloat(index++, border!.borderColor?.b ?? 0);
    shader.setFloat(index++, border!.borderColor?.a ?? 0);
    shader.setFloat(index++, borderAlpha);

    shader.setFloat(index++, border!.lightIntensity);

    shader.setFloat(index++, border!.lightColor.r);
    shader.setFloat(index++, border!.lightColor.g);
    shader.setFloat(index++, border!.lightColor.b);
    shader.setFloat(index++, border!.lightColor.a);

    shader.setFloat(index++, border!.shadowColor.r);
    shader.setFloat(index++, border!.shadowColor.g);
    shader.setFloat(index++, border!.shadowColor.b);
    shader.setFloat(index++, border!.shadowColor.a);

    shader.setFloat(index++, border!.lightDirection);
    shader.setFloat(index++, color.r);
    shader.setFloat(index++, color.g);
    shader.setFloat(index++, color.b);
    shader.setFloat(index++, color.a);
    // One-side / double-side specular highlights are classic-only:
    // in optical mode the directional term saturates the internal
    // brightness cap so these contributions become invisible. Zero
    // them on the wire to keep behavior consistent with the UI.
    shader.setFloat(
        index++, border!.isOpticalBorder ? 0.0 : border!.oneSideLightIntensity);
    shader.setFloat(index++, chromaticAberration);
    shader.setFloat(index++, saturation);
    shader.setFloat(index++, selectedLightMode);
    shader.setFloat(index++, selectedRefractionMode);
    shader.setFloat(index++, selectedRefractionType);
    shader.setFloat(index++, refractionIndex);
    shader.setFloat(index++, border!.ambientIntensity);
    shader.setFloat(index++,
        border!.isOpticalBorder ? 0.0 : border!.doubleSideLightIntensity);
    shader.setFloat(index++, border!.borderSaturation);
    shader.setFloat(index++, border!.borderSolidity);
    shader.setFloat(index++, selectedBorderMode);
    // u_lightSpread — optical-rim angular spread.
    shader.setFloat(index++, border!.lightSpread);

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
        oldDelegate.distortion != distortion ||
        oldDelegate.distortionWidth != distortionWidth ||
        oldDelegate.diagonalFlip != diagonalFlip ||
        oldDelegate.enableInnerRadiusTransparent !=
            enableInnerRadiusTransparent ||
        oldDelegate.parentSize != parentSize ||
        !_shapeEquals(oldDelegate.border, border) ||
        oldDelegate.borderAlpha != borderAlpha ||
        oldDelegate.blur.sigmaX != blur.sigmaX ||
        oldDelegate.blur.sigmaY != blur.sigmaY ||
        oldDelegate.color != color ||
        oldDelegate.chromaticAberration != chromaticAberration ||
        oldDelegate.saturation != saturation ||
        oldDelegate.refractionMode != refractionMode ||
        oldDelegate.refractionType != refractionType ||
        oldDelegate.shader != shader ||
        oldDelegate.borderShader != borderShader ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.honorBackdropAlpha != honorBackdropAlpha;
  }

  bool _shapeEquals(LiquidGlassShape? a, LiquidGlassShape? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.runtimeType != b.runtimeType) return false;
    if (a.borderWidth != b.borderWidth) return false;
    if (a.borderSoftness != b.borderSoftness) return false;
    if (a.borderColor != b.borderColor) return false;
    if (a.lightIntensity != b.lightIntensity) return false;
    if (a.lightColor != b.lightColor) return false;
    if (a.shadowColor != b.shadowColor) return false;
    if (a.lightDirection != b.lightDirection) return false;
    if (a.oneSideLightIntensity != b.oneSideLightIntensity) return false;
    if (a.lightMode != b.lightMode) return false;
    // Optical-border fields (present on this build): compare them too so
    // a change in optical rim styling triggers a repaint.
    if (a.ambientIntensity != b.ambientIntensity) return false;
    if (a.doubleSideLightIntensity != b.doubleSideLightIntensity) return false;
    if (a.borderSaturation != b.borderSaturation) return false;
    if (a.borderSolidity != b.borderSolidity) return false;
    if (a.lightSpread != b.lightSpread) return false;
    if (a.borderMode != b.borderMode) return false;
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
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final bool enableInnerRadiusTransparent;
  final double chromaticAberration;
  final double saturation;
  final LiquidGlassRefractionMode refractionMode;
  final LiquidGlassRefractionType? refractionType;
  final LiquidGlassShape border;
  final double borderAlpha;
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
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.enableInnerRadiusTransparent,
    required this.chromaticAberration,
    required this.saturation,
    required this.refractionMode,
    required this.refractionType,
    required this.border,
    required this.borderAlpha,
    required this.image,
    this.imageFallback,
    this.shapeScale = const Offset(1, 1),
    this.imageOffset,
    this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? sampledImage = image ?? imageFallback?.call();
    if (sampledImage == null) return;

    final double selectedLightMode =
        (border.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
    final double selectedBorderMode =
        (border.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;
    final double selectedRefractionMode =
        (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;
    final double selectedRefractionType =
        (refractionType?.isOptical ?? false) ? 1 : 0;
    final double refractionIndex = switch (refractionType) {
      OpticalRefraction(:final refraction) => refraction,
      _ => 1.0,
    };

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
      ..setFloat(index++, magnification)
      ..setFloat(index++, distortion)
      ..setFloat(index++, distortionWidth)
      ..setFloat(index++, enableInnerRadiusTransparent ? 1.0 : 0.0)
      ..setFloat(index++, diagonalFlip)
      // Full border-band width: doubled (the shader no longer doubles
      // internally) plus the optical-mode extra, in logical px. Matches
      // the main pass and the Impeller path.
      ..setFloat(
          index++,
          border.borderWidth * 2.0 +
              (border.isOpticalBorder && border.borderWidth > 0 ? 2.0 : 0.0))
      ..setFloat(index++, border.borderSoftness)
      ..setFloat(index++, border.borderColor?.r ?? 0)
      ..setFloat(index++, border.borderColor?.g ?? 0)
      ..setFloat(index++, border.borderColor?.b ?? 0)
      ..setFloat(index++, border.borderColor?.a ?? 0)
      ..setFloat(index++, borderAlpha)
      ..setFloat(index++, border.lightIntensity)
      ..setFloat(index++, border.lightColor.r)
      ..setFloat(index++, border.lightColor.g)
      ..setFloat(index++, border.lightColor.b)
      ..setFloat(index++, border.lightColor.a)
      ..setFloat(index++, border.shadowColor.r)
      ..setFloat(index++, border.shadowColor.g)
      ..setFloat(index++, border.shadowColor.b)
      ..setFloat(index++, border.shadowColor.a)
      ..setFloat(index++, border.lightDirection)
      ..setFloat(
          index++, border.isOpticalBorder ? 0.0 : border.oneSideLightIntensity)
      ..setFloat(index++, chromaticAberration)
      ..setFloat(index++, saturation)
      ..setFloat(index++, selectedLightMode)
      ..setFloat(index++, selectedRefractionMode)
      ..setFloat(index++, selectedRefractionType)
      ..setFloat(index++, refractionIndex)
      ..setFloat(index++, border.ambientIntensity)
      ..setFloat(index++,
          border.isOpticalBorder ? 0.0 : border.doubleSideLightIntensity)
      ..setFloat(index++, border.borderSaturation)
      ..setFloat(index++, border.borderSolidity)
      ..setFloat(index++, selectedBorderMode)
      // u_lightSpread — optical-rim angular spread.
      ..setFloat(index++, border.lightSpread);

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

    // In optical mode, use additive blending
    // if (border.borderMode == LiquidGlassBorderMode.optical) {
    //   paint.blendMode = BlendMode.overlay;
    // }

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
        oldDelegate.distortion != distortion ||
        oldDelegate.distortionWidth != distortionWidth ||
        oldDelegate.diagonalFlip != diagonalFlip ||
        oldDelegate.enableInnerRadiusTransparent !=
            enableInnerRadiusTransparent ||
        oldDelegate.chromaticAberration != chromaticAberration ||
        oldDelegate.saturation != saturation ||
        oldDelegate.refractionMode != refractionMode ||
        oldDelegate.refractionType != refractionType ||
        oldDelegate.borderAlpha != borderAlpha ||
        oldDelegate.borderShader != borderShader ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageSize != imageSize ||
        !_shapeEquals(oldDelegate.border, border);
  }

  bool _shapeEquals(LiquidGlassShape a, LiquidGlassShape b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;
    if (a.borderWidth != b.borderWidth) return false;
    if (a.borderSoftness != b.borderSoftness) return false;
    if (a.borderColor != b.borderColor) return false;
    if (a.lightIntensity != b.lightIntensity) return false;
    if (a.lightColor != b.lightColor) return false;
    if (a.shadowColor != b.shadowColor) return false;
    if (a.lightDirection != b.lightDirection) return false;
    if (a.oneSideLightIntensity != b.oneSideLightIntensity) return false;
    if (a.lightMode != b.lightMode) return false;
    if (a.ambientIntensity != b.ambientIntensity) return false;
    if (a.doubleSideLightIntensity != b.doubleSideLightIntensity) return false;
    if (a.borderSaturation != b.borderSaturation) return false;
    if (a.borderSolidity != b.borderSolidity) return false;
    if (a.lightSpread != b.lightSpread) return false;
    if (a.borderMode != b.borderMode) return false;
    return a.cornerStyle == b.cornerStyle &&
        a.cornerRadius == b.cornerRadius &&
        a.clipQuality == b.clipQuality;
  }
}
