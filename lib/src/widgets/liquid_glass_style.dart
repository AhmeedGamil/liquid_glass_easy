import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import 'components/liquid_glass_shadow.dart';
import 'liquid_glass_config.dart';
import 'utils/liquid_glass_adaptivity.dart';
import 'utils/liquid_glass_light.dart';
import 'utils/liquid_glass_shape.dart';

/// The **look** of a liquid-glass surface, bundled into one reusable
/// descriptor: its [shape], the two lights of its border ([specular] and
/// [glow]), its fill ([color], [blur], [saturation], [shadow]) and how it
/// bends the content behind it ([refractionIndex], [refractionWidth],
/// [magnification], [dispersion]).
///
/// This is the single styling vocabulary shared across the library —
/// `LiquidGlassLens` and the components (buttons, bars, the nav pill, …) all
/// describe their glass with the same object. Change one facet with
/// [copyWith]:
///
/// ```dart
/// const LiquidGlassStyle(
///   shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
///   specular: LiquidGlassLight.specular(thickness: 5.4, angle: 39),
///   glow: LiquidGlassLight.glow(angle: 129),
///   refractionIndex: 1.02,
///   refractionWidth: 24,
///   color: Color(0x22FFFFFF),
///   blur: 3,
/// );
/// ```
///
/// Non-refracting consumers — e.g. the static (non-glass) selection pill
/// or the frosted fallback — read the subset they can render and simply
/// ignore the refraction fields.
@immutable
class LiquidGlassStyle {
  /// The outline of the surface. When `null`, the consumer picks a sensible
  /// default (e.g. the nav pill falls back to a height-tracking capsule), so
  /// a style can describe the material without pinning the shape.
  final LiquidGlassShape? shape;

  /// The border's highlight: the backdrop seen through the edge, brightened
  /// along the light's axis. When `null`, the consumer's own default is used
  /// (`LiquidGlassLight.specular()` on a plain lens).
  final LiquidGlassLight? specular;

  /// The border's soft side light: a wider, gentler band in the specular's
  /// picked-up colour. When `null`, the consumer's own default is
  /// used (no glow on a plain lens, which the shader then skips).
  final LiquidGlassLight? glow;

  /// A second highlight over [specular]. Not part of the public API: only
  /// the package's own styles carry one; `null` draws none.
  @internal
  final LiquidGlassLight? secondSpecular;

  /// How hard the edge bends the content behind it. `1.0` is no bending,
  /// `1.02` a clear lens edge and `1.5` a very strong one.
  final double refractionIndex;

  /// Width of the bending band along the edge, in logical pixels: how far
  /// in from the outline the bend reaches. How strong it is comes from
  /// [refractionIndex].
  final double refractionWidth;

  /// Magnification of the content seen through the glass (`1.0` = none).
  final double magnification;

  /// Colour fringe in the bending band: red and blue are read a little
  /// either side of green, by an offset that grows with the backdrop's
  /// brightness. Strongest on the outline, gone at the band's inner end.
  ///
  /// - `0.0` — Default: no fringe, and one backdrop read per pixel
  ///   where any other value costs extra reads in the bending band.
  /// The value is the widest split, in logical pixels, reached on the
  /// outline over the brightest backdrop. Below about `0.66` it reads
  /// as off.
  ///
  /// - `1.3` — A thin fringe.
  /// - `6.6` — Strong.
  ///
  /// Recommended range: `0.0` to `13.0`.
  final double dispersion;

  /// Color saturation of the output (`1.0` = unchanged, `0.0` = grayscale).
  final double saturation;

  /// Blur applied to the content beneath the glass, as a Gaussian sigma in
  /// logical pixels. `0` (the default) is no blur.
  final double blur;

  /// Base color tint of the glass (often semi-transparent).
  final Color color;

  /// Contact shadow around the glass — the soft dark band that hugs its
  /// rim and pools underneath, so the glass reads as sitting in the page
  /// rather than floating on it. `null` (the default) draws none.
  ///
  /// Honored by `LiquidGlassLens`: the lens wraps itself in the
  /// [LiquidGlassShadow] this describes (its `child` is ignored), with
  /// the ring's corner defaulting to the lens shape's own radius. The
  /// wrap lives *inside* the flex deformation's box, so on a lens given a
  /// `touch` the ring swells, leans and springs back with the body
  /// instead of staying frozen on the rest silhouette.
  /// Its `visible` flag composes with the lens's own `visibility`.
  ///
  /// Not supported inside a `LiquidGlassBlender`: a merged metaball
  /// silhouette has no single ring to cast.
  final LiquidGlassShadow? shadow;

  /// iOS-style adaptivity: glass tint + content color flip between two
  /// palettes based on the background behind the lens. `null` (default)
  /// disables the feature entirely. Honored by `LiquidGlassLens`; while
  /// active, its glass color overrides [color].
  final LiquidGlassAdaptivity? adaptivity;

  /// Draw this surface as `LiquidGlassLite` — frost, tint and a painted
  /// rim, no shader and no refraction — whatever engine the
  /// app is on.
  ///
  /// `false` (the default) leaves the choice to the engine switches on
  /// `LiquidGlassEngine`.
  final bool liteGlass;

  const LiquidGlassStyle({
    this.shape,
    this.specular,
    this.glow,
    this.refractionIndex = 1.1,
    this.refractionWidth = 12.0,
    this.magnification = 1.0,
    this.dispersion = 0,
    this.saturation = 1.0,
    this.blur = 0.0,
    this.color = const Color(0x00000000),
    this.shadow,
    this.adaptivity,
    this.liteGlass = false,
  }) : secondSpecular = null;

  /// Every field, [secondSpecular] included.
  const LiquidGlassStyle._full({
    this.shape,
    this.specular,
    this.glow,
    this.secondSpecular,
    required this.refractionIndex,
    required this.refractionWidth,
    required this.magnification,
    required this.dispersion,
    required this.saturation,
    required this.blur,
    required this.color,
    this.shadow,
    this.adaptivity,
    required this.liteGlass,
  });

  /// Builds a style from the renderers' own groups: a shape that may carry
  /// its lights, and a material group. [specular] and [glow], when given,
  /// win over the shape's own.
  @internal
  factory LiquidGlassStyle.groups({
    LiquidGlassShape? shape,
    LiquidGlassLight? specular,
    LiquidGlassLight? glow,
    LiquidGlassLight? secondSpecular,
    LiquidGlassAppearance appearance = const LiquidGlassAppearance(),
    LiquidGlassRefraction refraction = const LiquidGlassRefraction(),
    LiquidGlassAdaptivity? adaptivity,
    bool liteGlass = false,
  }) {
    // A lit shape stays whole in `shape`, so it keeps its lights wherever
    // the style's shape is handed on; [litShape] resolves the two.
    return LiquidGlassStyle._full(
      shape: shape,
      specular: specular,
      glow: glow,
      secondSpecular: secondSpecular,
      refractionIndex: refraction.refractionIndex,
      refractionWidth: refraction.refractionWidth,
      magnification: refraction.magnification,
      dispersion: refraction.dispersion,
      saturation: appearance.saturation,
      blur: appearance.blur,
      color: appearance.color,
      shadow: appearance.shadow,
      adaptivity: adaptivity,
      liteGlass: liteGlass,
    );
  }

  /// The material group the renderers read: tint, blur, saturation, shadow.
  @internal
  LiquidGlassAppearance get appearance => LiquidGlassAppearance(
        saturation: saturation,
        blur: blur,
        color: color,
        shadow: shadow,
      );

  /// The refraction group the renderers read.
  @internal
  LiquidGlassRefraction get refraction => LiquidGlassRefraction(
        refractionIndex: refractionIndex,
        refractionWidth: refractionWidth,
        magnification: magnification,
        dispersion: dispersion,
      );

  /// The outline with this style's lights, as the renderers draw it.
  /// [fallback] is the outline used when [shape] is `null`; a `null`
  /// [specular] or [glow] takes [fallbackSpecular] / [fallbackGlow], or the
  /// light's own defaults.
  @internal
  LiquidGlassLitShape litShape({
    LiquidGlassShape fallback =
        const LiquidGlassShape.continuousRoundedRectangle(),
    LiquidGlassLight? fallbackSpecular,
    LiquidGlassLight? fallbackGlow,
  }) =>
      LiquidGlassLitShape.of(
        shape ?? fallback,
        specular: specular ?? fallbackSpecular,
        glow: glow ?? fallbackGlow,
        secondSpecular: secondSpecular,
      );

  /// Returns a copy with the given fields replaced. A `null` argument keeps
  /// the current value, so [shape], [specular], [glow], [shadow] and
  /// [adaptivity] cannot be cleared here.
  LiquidGlassStyle copyWith({
    LiquidGlassShape? shape,
    LiquidGlassLight? specular,
    LiquidGlassLight? glow,
    double? refractionIndex,
    double? refractionWidth,
    double? magnification,
    double? dispersion,
    double? saturation,
    double? blur,
    Color? color,
    LiquidGlassShadow? shadow,
    LiquidGlassAdaptivity? adaptivity,
    bool? liteGlass,
  }) {
    return LiquidGlassStyle._full(
      shape: shape ?? this.shape,
      specular: specular ?? this.specular,
      glow: glow ?? this.glow,
      secondSpecular: secondSpecular,
      refractionIndex: refractionIndex ?? this.refractionIndex,
      refractionWidth: refractionWidth ?? this.refractionWidth,
      magnification: magnification ?? this.magnification,
      dispersion: dispersion ?? this.dispersion,
      saturation: saturation ?? this.saturation,
      blur: blur ?? this.blur,
      color: color ?? this.color,
      shadow: shadow ?? this.shadow,
      adaptivity: adaptivity ?? this.adaptivity,
      liteGlass: liteGlass ?? this.liteGlass,
    );
  }

  /// Overlays [other] on top of this style: [other]'s material ([color],
  /// [blur], [saturation], [shadow]) and refraction fields replace this one's,
  /// and its [shape], [specular], [glow] and [adaptivity]
  /// win when set (falling back to this style's when `null`); [liteGlass] is
  /// on when either style has it on. Returns this style
  /// unchanged when [other] is `null`. Useful for a base/theme style with
  /// per-surface overrides.
  LiquidGlassStyle merge(LiquidGlassStyle? other) {
    if (other == null) return this;
    return LiquidGlassStyle._full(
      shape: other.shape ?? shape,
      specular: other.specular ?? specular,
      glow: other.glow ?? glow,
      secondSpecular: other.secondSpecular ?? secondSpecular,
      refractionIndex: other.refractionIndex,
      refractionWidth: other.refractionWidth,
      magnification: other.magnification,
      dispersion: other.dispersion,
      saturation: other.saturation,
      blur: other.blur,
      color: other.color,
      shadow: other.shadow,
      adaptivity: other.adaptivity ?? adaptivity,
      liteGlass: other.liteGlass || liteGlass,
    );
  }
}
