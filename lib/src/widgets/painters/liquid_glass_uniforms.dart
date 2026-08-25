import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../utils/liquid_glass_light_mode.dart';
import '../utils/liquid_glass_refraction_mode.dart';
import '../utils/liquid_glass_refraction_type.dart';
import '../utils/liquid_glass_shape.dart';

/// Single source of truth for the liquid-glass fragment-shader uniform
/// block.
///
/// The same ~38-uniform layout is shared by **three** call sites that
/// previously each hand-copied the `setFloat(i++, ...)` sequence in the
/// exact order the `.frag` declares its uniforms:
///
///  1. `LiquidGlassPainter`        — Skia main pass        (scale `1.0`)
///  2. `LiquidGlassBorderPainter`  — Skia blur border pass (scale `1.0`)
///  3. `_setMainShaderUniformsForBackdrop` — Impeller path (scale `dpr`)
///
/// Keeping the order in one function makes Impeller↔Skia drift
/// structurally impossible: reorder/add a uniform here once and all
/// three paths stay in sync.
///
/// ## Scale
/// Spatial uniforms (resolution, touch, lens size, corner radius,
/// distortion thickness, border width) are multiplied by [scale].
/// The Skia paths bind the shader via `Paint.shader` and run in
/// **logical** pixels, so they pass `scale: 1.0`. The Impeller path
/// binds via `ImageFilter.shader`, where `FlutterFragCoord()` returns
/// **physical** pixels, so it passes `scale: devicePixelRatio`. Callers
/// always provide logical values; the physical conversion lives here.
///
/// ## Border shader variant
/// The border shader (`liquid_glass_border.frag`) is identical to the
/// main shader except it has **no `u_lensColor`**. Pass
/// [includeLensColor] `false` for that shader so the four lens-color
/// floats are skipped and the remaining indices stay aligned.
///
/// ## Sampler
/// This function only writes the `setFloat` uniforms. The image sampler
/// (`u_texture_input`) is intentionally **not** bound here: the Skia
/// paths bind a captured image (`setImageSampler`), while the Impeller
/// path lets `BackdropFilter` feed the live backdrop automatically. The
/// caller owns that decision.
void packLiquidGlassUniforms(
  ui.FragmentShader shader, {
  required LiquidGlassShape shape,
  required double scale,
  required Size resolution,
  required Offset lensPosition,
  required double lensWidth,
  required double lensHeight,
  required double magnification,
  required double distortion,

  /// Effective (anim-adjusted) distortion band thickness, in logical px.
  required double distortionWidth,
  required bool enableInnerRadiusTransparent,
  required double diagonalFlip,

  /// Border width in logical px. The caller decides the multiplier:
  /// the main pass uses `borderWidth * 2` (or `0` when the border is
  /// suppressed for the blur path), the border pass uses `borderWidth`.
  required double borderWidth,
  required double borderAlpha,
  required double chromaticAberration,
  required double saturation,
  required LiquidGlassRefractionMode? refractionMode,
  required LiquidGlassRefractionType? refractionType,

  /// Whether to emit the four `u_lensColor` floats. `true` for the main
  /// shader, `false` for the border shader (which lacks that uniform).
  required bool includeLensColor,
  Color lensColor = const Color(0x00000000),

  /// Whether the shader should fold the sampled backdrop's alpha into the
  /// lens coverage. `true` on the Skia capture path (the bound snapshot
  /// has meaningful authored transparency); `false` on the Impeller path
  /// (the live backdrop's alpha is not a transparency signal and reads 0
  /// over dark regions). Only emitted for the main shader — the border
  /// shader has no coverage step and no such uniform.
  bool honorBackdropAlpha = true,

  /// Deformed size ÷ rest size, when a touch deformation is running.
  ///
  /// [Offset.zero] and `(1, 1)` both mean "undeformed"; anything else makes
  /// the shader evaluate the shape at its REST size in a domain divided by
  /// this, so a stretched circle reads as an ellipse rather than growing
  /// flat runs. Never scaled by [scale] — it is a ratio, not a length.
  Offset shapeScale = const Offset(1, 1),

  /// Parent-space rectangle the bound texture covers, in logical px.
  /// Defaults (offset `(0,0)`, size == [resolution]) reproduce the old
  /// full-frame `refrPx / u_resolution` sampling. The Impeller path always
  /// samples the full live backdrop, so it leaves these at the defaults.
  Offset imageOffset = Offset.zero,
  Size? imageSize,

  /// Lens-space → shader-space affine map for a lens under an ancestor
  /// transform (scale / rotation): row-major linear part `[[a,b],[c,d]]`
  /// plus [xformOffset], its translation in logical px. Identity — the
  /// default — is every untransformed lens. "Shader space" is the screen on
  /// Impeller and the captured view on Skia; both shaders take the map.
  double xformA = 1,
  double xformB = 0,
  double xformC = 0,
  double xformD = 1,
  Offset xformOffset = Offset.zero,
}) {
  final double selectedLightMode =
      (shape.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
  final double selectedRefractionMode =
      (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;
  final double selectedRefractionType =
      (refractionType?.isOptical ?? false) ? 1 : 0;
  final double refractionIndex = switch (refractionType) {
    OpticalRefraction(:final refraction) => refraction,
    _ => 1.0,
  };
  final double selectedBorderMode =
      (shape.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;

  final double cornerRadius = shape.cornerRadius;
  // The shape type alone selects the corner SDF in the shader:
  // 2 = continuous (capsule), 1 = squircle (full smoothing), 0 = circular.
  final double cornerStyle = liquidGlassCornerStyle(shape);

  int i = 0;
  // u_resolution
  shader.setFloat(i++, resolution.width * scale);
  shader.setFloat(i++, resolution.height * scale);
  // u_touch (lens top-left)
  shader.setFloat(i++, lensPosition.dx * scale);
  shader.setFloat(i++, lensPosition.dy * scale);

  // u_lensWidth / u_lensHeight
  shader.setFloat(i++, lensWidth * scale);
  shader.setFloat(i++, lensHeight * scale);
  // u_cornerRadius
  shader.setFloat(i++, cornerRadius * scale);
  // u_cornerStyle (0 = circular, 1 = squircle, 2 = continuous — never scaled)
  shader.setFloat(i++, cornerStyle);

  shader.setFloat(i++, magnification);
  shader.setFloat(i++, distortion);
  // u_distortionThicknessPx
  shader.setFloat(i++, distortionWidth * scale);

  shader.setFloat(i++, enableInnerRadiusTransparent ? 1.0 : 0.0);
  shader.setFloat(i++, diagonalFlip);

  // u_borderWidth
  shader.setFloat(i++, borderWidth * scale);
  shader.setFloat(i++, shape.borderSoftness);

  shader.setFloat(i++, shape.borderColor?.r ?? 0);
  shader.setFloat(i++, shape.borderColor?.g ?? 0);
  shader.setFloat(i++, shape.borderColor?.b ?? 0);
  shader.setFloat(i++, shape.borderColor?.a ?? 0);
  shader.setFloat(i++, borderAlpha);

  shader.setFloat(i++, shape.lightIntensity);

  shader.setFloat(i++, shape.lightColor.r);
  shader.setFloat(i++, shape.lightColor.g);
  shader.setFloat(i++, shape.lightColor.b);
  shader.setFloat(i++, shape.lightColor.a);

  shader.setFloat(i++, shape.shadowColor.r);
  shader.setFloat(i++, shape.shadowColor.g);
  shader.setFloat(i++, shape.shadowColor.b);
  shader.setFloat(i++, shape.shadowColor.a);

  shader.setFloat(i++, shape.lightDirection);

  // u_lensColor — present only on the main shader.
  if (includeLensColor) {
    shader.setFloat(i++, lensColor.r);
    shader.setFloat(i++, lensColor.g);
    shader.setFloat(i++, lensColor.b);
    shader.setFloat(i++, lensColor.a);
  }

  // One-/double-side specular highlights are classic-only: in optical
  // mode the directional term saturates the brightness cap so these
  // contributions become invisible. Zero them on the wire to keep
  // behavior consistent with the UI.
  shader.setFloat(
      i++, shape.isOpticalBorder ? 0.0 : shape.oneSideLightIntensity);
  shader.setFloat(i++, chromaticAberration);
  shader.setFloat(i++, saturation);
  shader.setFloat(i++, selectedLightMode);
  shader.setFloat(i++, selectedRefractionMode);
  shader.setFloat(i++, selectedRefractionType);
  shader.setFloat(i++, refractionIndex);
  shader.setFloat(i++, shape.ambientIntensity);
  shader.setFloat(
      i++, shape.isOpticalBorder ? 0.0 : shape.doubleSideLightIntensity);
  shader.setFloat(i++, shape.borderSaturation);
  shader.setFloat(i++, shape.borderSolidity);
  shader.setFloat(i++, selectedBorderMode);

  // u_lightSpread — optical-rim angular spread. Present on both the main and
  // border shaders (a loose float right after u_packC, before the image rect).
  shader.setFloat(i++, shape.lightSpread);

  // u_imageOffset / u_imageSize — present on BOTH shaders, so always
  // written. Scaled like the other spatial uniforms.
  final Size imgSize = imageSize ?? resolution;
  shader.setFloat(i++, imageOffset.dx * scale);
  shader.setFloat(i++, imageOffset.dy * scale);
  shader.setFloat(i++, imgSize.width * scale);
  shader.setFloat(i++, imgSize.height * scale);

  // u_honorBackdropAlpha + u_shapeAaPx — main shader only (the last two
  // uniforms in liquid_glass.frag; the border shader declares neither, so
  // writing them there would overflow its uniform array).
  if (includeLensColor) {
    shader.setFloat(i++, honorBackdropAlpha ? 1.0 : 0.0);
    // u_shapeAaPx — edge-AA band width in fragment px = one logical pixel.
    // `scale` is 1.0 on Skia (logical-px shader) and dpr on Impeller
    // (physical-px shader), so the coverage ramp is the same physical width
    // on both backends.
    shader.setFloat(i++, scale);
  }

  // u_shapeScale — last uniform the BORDER shader declares. A ratio, so it
  // is deliberately not multiplied by `scale`.
  shader.setFloat(i++, shapeScale.dx == 0 ? 1.0 : shapeScale.dx);
  shader.setFloat(i++, shapeScale.dy == 0 ? 1.0 : shapeScale.dy);

  // u_xformRow / u_xformOff — the ancestor-transform map, LAST on both
  // shaders. The linear part is a ratio; the translation is a position,
  // so it scales like every other one.
  shader.setFloat(i++, xformA);
  shader.setFloat(i++, xformB);
  shader.setFloat(i++, xformC);
  shader.setFloat(i++, xformD);
  shader.setFloat(i++, xformOffset.dx * scale);
  shader.setFloat(i++, xformOffset.dy * scale);
}

/// One lens's contribution to the metaball field, in the SAME logical-pixel
/// coordinate space as [packMetaballGlassUniforms]'s `resolution` (global
/// screen space on Impeller, view space on Skia). [packMetaballGlassUniforms]
/// applies the per-path `scale` (dpr on Impeller, 1.0 on Skia).
class MetaballLensUniform {
  const MetaballLensUniform({
    required this.center,
    required this.halfSize,
    required this.cornerRadius,
    this.cornerStyle = 0,
    this.shapeScale = const Offset(1, 1),
    this.color = const Color(0x00000000),
  });

  /// Lens centre in logical px.
  final Offset center;

  /// Lens half-extents in logical px.
  final Size halfSize;

  /// Corner radius in logical px (the shader clamps it to the shorter
  /// half-side).
  final double cornerRadius;

  /// This lens's corner style as `LiquidGlassCornerStyle.index`
  /// (0 = circular rounded rect, 1 = squircle, 2 = continuous capsule).
  /// The shader picks the matching per-lens SDF before the metaball union,
  /// so members keep their own corners through the merge.
  final int cornerStyle;

  /// This lens's glass tint.
  ///
  /// Its own adaptive verdict where it has one, the group's colour where it
  /// does not — the caller resolves that, so the shader has a colour for
  /// every member and one rule for all of them. The merged surface blends
  /// them by the same influence weight that shapes the bridge, so two members
  /// on opposite verdicts cross over exactly where their shapes fuse.
  final Color color;

  /// The same lens with its centre moved by [delta].
  ///
  /// The engine-blur path packs lens rects in CLIP-local space rather than
  /// screen space, which is a change of origin and nothing else. Rebasing
  /// through here rather than by rebuilding the object is deliberate: a
  /// hand-written copy drops any field added later, silently — which is
  /// exactly how the per-member tint went missing the first time.
  MetaballLensUniform translated(Offset delta) => MetaballLensUniform(
        center: center + delta,
        halfSize: halfSize,
        cornerRadius: cornerRadius,
        cornerStyle: cornerStyle,
        shapeScale: shapeScale,
        color: color,
      );

  /// This lens's touch deformation as deformed ÷ rest, per axis.
  ///
  /// `(1, 1)` is undeformed. The shader evaluates the lens at its REST size in
  /// a domain divided by this, so the whole outline stretches — a squeezed
  /// circle stays an ellipse instead of growing flat runs. Packed into
  /// `meta.y`; see [_packMetaballScale].
  final Offset shapeScale;
}

/// Maximum lenses the metaball shader (`metaball_glass.frag`) unions.
///
/// Eight, carried as four `mat4` uniforms of two members each. The ceiling is
/// declaration count, not float count — iOS 26 Impeller binds every uniform to
/// its own Metal buffer — so raising it again means adding `u_lensPairN`
/// declarations in the shader, two members at a time, and matching this.
const int kMetaballMaxLenses = 8;

/// Floats one member occupies: a lens column (centre.xy, halfSize.xy) then a
/// meta column (cornerRadius, packedScale, cornerStyle, spare).
const int _kMetaballFloatsPerLens = 8;

/// Packs the `metaball_glass.frag` uniform block.
///
/// Mirrors [packLiquidGlassUniforms] for the shared glass block (border,
/// light, refraction, tint, capture region) so the merged blob looks exactly
/// like a production lens, but replaces the single-lens geometry with up to
/// [kMetaballMaxLenses] [lenses] plus the metaball [smoothness]. The
/// `setFloat` order below MUST match the uniform DECLARATION order in
/// `metaball_glass.frag`.
///
/// [shape] is the **group** style's shape: it drives the shared corner style,
/// border and light. Each lens carries only its own size + corner radius.
/// The image sampler (`u_texture_input`) is bound by the caller.
void packMetaballGlassUniforms(
  ui.FragmentShader shader, {
  required LiquidGlassShape shape,
  required double scale,
  required Size resolution,
  required List<MetaballLensUniform> lenses,
  required double smoothness,
  /// Whether the members are merged by the metaball smooth-union at all.
  ///
  /// `false` unions them HARD — nearest member wins each fragment outright —
  /// and the shader skips the smin, the per-member influence weights and the
  /// gradient blend entirely. [smoothness] is then unused.
  required bool merge,
  required double magnification,
  required double distortion,
  required double distortionWidth,
  required bool enableInnerRadiusTransparent,
  required double diagonalFlip,
  required double borderWidth,
  required double borderAlpha,
  required double chromaticAberration,
  required double saturation,
  required double blur,
  required LiquidGlassRefractionMode? refractionMode,
  required LiquidGlassRefractionType? refractionType,
  Color lensColor = const Color(0x00000000),
  bool honorBackdropAlpha = false,
  Offset imageOffset = Offset.zero,
  Size? imageSize,
}) {
  final double selectedLightMode =
      (shape.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
  final double selectedRefractionMode =
      (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;
  final double selectedRefractionType =
      (refractionType?.isOptical ?? false) ? 1 : 0;
  final double refractionIndex = switch (refractionType) {
    OpticalRefraction(:final refraction) => refraction,
    _ => 1.0,
  };
  final double selectedBorderMode =
      (shape.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;

  int i = 0;

  // u_resolution
  shader.setFloat(i++, resolution.width * scale);
  shader.setFloat(i++, resolution.height * scale);

  // u_lensPair0..3 — one mat4 per TWO members, column-major, so a member's
  // two columns are adjacent: (centre.xy, halfSize.xy) then (cornerRadius,
  // packedScale, cornerStyle, spare). A matrix is written as consecutive
  // floats exactly like the vec4s it replaced; only the interleaving is new.
  //
  // The meta's fourth slot is unused but must still be written — the column
  // after it starts eight floats along whether or not this one was filled.
  // An absent member is all-zero, which is also how the shader reads
  // "disabled": its half-width lands on 0.
  final int lensFloatStart = i;
  for (int n = 0; n < kMetaballMaxLenses; n++) {
    if (n < lenses.length) {
      final lens = lenses[n];
      shader.setFloat(i++, lens.center.dx * scale);
      shader.setFloat(i++, lens.center.dy * scale);
      shader.setFloat(i++, lens.halfSize.width * scale);
      shader.setFloat(i++, lens.halfSize.height * scale);
      shader.setFloat(i++, lens.cornerRadius * scale);
      shader.setFloat(i++, _packMetaballScale(lens.shapeScale));
      shader.setFloat(i++, lens.cornerStyle.toDouble());
      shader.setFloat(i++, 0);
    } else {
      for (int k = 0; k < _kMetaballFloatsPerLens; k++) {
        shader.setFloat(i++, 0);
      }
    }
  }
  // A miscount here is silent — wrong geometry, never an error — so it is
  // worth one assert rather than a debugging session on a device.
  assert(
      i - lensFloatStart == kMetaballMaxLenses * _kMetaballFloatsPerLens,
      'metaball lens block wrote ${i - lensFloatStart} floats, expected '
      '${kMetaballMaxLenses * _kMetaballFloatsPerLens} — the mat4 columns and '
      'the shader declarations are out of step');

  // u_lensTintA/B — one straight-alpha RGBA column per member, four per mat4.
  // A member with no colour of its own was already given the group's by the
  // caller, so an absent member is the only all-zero case and it is masked out
  // anyway (its half-width is zero, so it never reaches the union).
  for (int n = 0; n < kMetaballMaxLenses; n++) {
    final Color c =
        n < lenses.length ? lenses[n].color : const Color(0x00000000);
    shader.setFloat(i++, c.r);
    shader.setFloat(i++, c.g);
    shader.setFloat(i++, c.b);
    shader.setFloat(i++, c.a);
  }

  // ── Shared glass block (every loose scalar packed into a vec4) ───────────
  // u_warp = (magnification, distortion, distortionThicknessPx, enableBgTransp).
  shader.setFloat(i++, magnification);
  shader.setFloat(i++, distortion);
  shader.setFloat(i++, distortionWidth * scale);
  shader.setFloat(i++, enableInnerRadiusTransparent ? 1.0 : 0.0);
  // u_warpB = (smoothness, diagonalFlip, borderWidth, borderSoftness).
  shader.setFloat(i++, smoothness * scale);
  shader.setFloat(i++, diagonalFlip);
  shader.setFloat(i++, borderWidth * scale);
  shader.setFloat(i++, shape.borderSoftness);
  // u_warpC = (borderAlpha, lightIntensity, lightDirection, honorBackdropAlpha).
  shader.setFloat(i++, borderAlpha);
  shader.setFloat(i++, shape.lightIntensity);
  shader.setFloat(i++, shape.lightDirection);
  shader.setFloat(i++, honorBackdropAlpha ? 1.0 : 0.0);
  // u_warpD = (blur, shapeAaPx, lightSpread, mergeEnabled).
  shader.setFloat(i++, blur * scale);
  shader.setFloat(i++, scale);
  shader.setFloat(i++, shape.lightSpread);
  shader.setFloat(i++, merge ? 1.0 : 0.0);

  // u_borderColor
  shader.setFloat(i++, shape.borderColor?.r ?? 0);
  shader.setFloat(i++, shape.borderColor?.g ?? 0);
  shader.setFloat(i++, shape.borderColor?.b ?? 0);
  shader.setFloat(i++, shape.borderColor?.a ?? 0);

  // u_lightColor
  shader.setFloat(i++, shape.lightColor.r);
  shader.setFloat(i++, shape.lightColor.g);
  shader.setFloat(i++, shape.lightColor.b);
  shader.setFloat(i++, shape.lightColor.a);

  // u_shadowColor
  shader.setFloat(i++, shape.shadowColor.r);
  shader.setFloat(i++, shape.shadowColor.g);
  shader.setFloat(i++, shape.shadowColor.b);
  shader.setFloat(i++, shape.shadowColor.a);

  // u_lensColor
  shader.setFloat(i++, lensColor.r);
  shader.setFloat(i++, lensColor.g);
  shader.setFloat(i++, lensColor.b);
  shader.setFloat(i++, lensColor.a);

  // u_packA = (oneSideLightIntensity, chromaticAberration, saturation, lightMode)
  shader.setFloat(
      i++, shape.isOpticalBorder ? 0.0 : shape.oneSideLightIntensity);
  shader.setFloat(i++, chromaticAberration);
  shader.setFloat(i++, saturation);
  shader.setFloat(i++, selectedLightMode);
  // u_packB = (refractionMode, refractionType, refractionIndex, ambientIntensity)
  shader.setFloat(i++, selectedRefractionMode);
  shader.setFloat(i++, selectedRefractionType);
  shader.setFloat(i++, refractionIndex);
  shader.setFloat(i++, shape.ambientIntensity);
  // u_packC = (doubleSideLightIntensity, borderSaturation, borderSolidity, borderMode)
  shader.setFloat(
      i++, shape.isOpticalBorder ? 0.0 : shape.doubleSideLightIntensity);
  shader.setFloat(i++, shape.borderSaturation);
  shader.setFloat(i++, shape.borderSolidity);
  shader.setFloat(i++, selectedBorderMode);

  // u_imageRegion = (offset.xy, size.xy) — the captured/backdrop sub-rect.
  final Size imgSize = imageSize ?? resolution;
  shader.setFloat(i++, imageOffset.dx * scale);
  shader.setFloat(i++, imageOffset.dy * scale);
  shader.setFloat(i++, imgSize.width * scale);
  shader.setFloat(i++, imgSize.height * scale);
}

/// Packs a per-lens flex scale into one float for `meta.y`.
///
/// Two 11-bit values, radix 2048, over `0.5..2.0`. Peaks at 2^22-1, two bits
/// under float32's exact integer range, and the shader's `unpackScale`
/// mirrors it.
///
/// `0` is reserved as the UNDEFORMED sentinel. Without it `1.0` would quantise
/// to `0.99988`, giving every lens in the app a tiny domain scale and making
/// "no flex" no longer bit-identical to the previous output.
double _packMetaballScale(Offset s) {
  if (s.dx == 1.0 && s.dy == 1.0) return 0;
  int q(double v) =>
      1 + ((v.clamp(0.5, 2.0) - 0.5) / 1.5 * 2046).round();
  return (q(s.dx) + q(s.dy) * 2048).toDouble();
}
