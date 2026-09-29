import 'package:flutter/material.dart';

/// Defines the rendering style for the liquid glass border.
///
/// [OpticalBorder] is the default and the one to use: a rim that falls out
/// of the glass optics — a directional highlight on the backdrop seen through
/// the edge, with a side light under it.
/// [ClassicBorder] is the older sweep-gradient rim and is **deprecated**.
///
/// Example:
/// ```dart
/// // Optical border with saturation boost
/// LiquidGlassShape.roundedRectangle(
///   borderType: OpticalBorder(
///     borderSaturation: 1.5,
///   ),
/// )
/// ```
sealed class LiquidGlassBorderType {
  const LiquidGlassBorderType();

  /// Whether this is an optical border.
  bool get isOptical => this is OpticalBorder;

  /// Whether this is a classic border.
  bool get isClassic => this is ClassicBorder;
}

/// Classic sweep gradient border.
///
/// Light and shadow colors sweep around the shape based on the angle
/// between the surface normal and light direction. This produces a
/// clean, stylized border with direct control over light/shadow colors.
///
/// Parameters specific to classic mode:
/// - [borderSoftness] — Controls the feathered edge transition.
/// - [shadowColor] — The shadow color on the opposite side.
/// - [oneSideLightIntensity] — One-sided specular highlight strength.
/// - [doubleSideLightIntensity] — Double-sided specular highlight strength.
///
/// ## Deprecated
///
/// The rim is drawn rather than derived: a sweep painted from a light angle,
/// with its own colours and its own specular terms, sitting on glass whose
/// every other facet comes out of the shape. [OpticalBorder] — the default —
/// takes the rim from the shape's own field, picks its colour up from the
/// background, and is what the material means by an edge.
///
/// It is not a parameter-for-parameter swap, and it is not meant to be:
/// [shadowColor], [oneSideLightIntensity] and [doubleSideLightIntensity] have
/// no optical counterpart because the optical rim has no separate light to
/// aim. Reach for [OpticalBorder.borderSaturation],
/// [OpticalBorder.ambientIntensity], [OpticalBorder.borderSolidity] and
/// [OpticalBorder.lightSpread] instead, and `borderWidth`, `lightIntensity`,
/// `lightColor` and `lightDirection` carry over unchanged — they live on the
/// shape, not on the border type.
@Deprecated(
  'Use OpticalBorder instead — the rim it derives from the glass shape is '
  'what the material means by an edge. This feature was deprecated after '
  'v4.2.0.',
)
class ClassicBorder extends LiquidGlassBorderType {
  /// The smoothness or falloff softness of the border edge.
  ///
  /// A higher value results in a softer, feathered border transition,
  /// while a lower value keeps it crisp and sharp.
  final double borderSoftness;

  /// The shadow color used on the opposite side of the lens border
  /// to enhance depth and contrast.
  ///
  /// Typically a darker or cooler tone to complement the shared `lightColor`.
  final Color shadowColor;

  /// Controls the intensity of the one-sided specular highlight
  /// applied to the glass border.
  ///
  /// This affects only the specular reflection component and is
  /// applied from a single light direction, creating a focused
  /// glass-like shine on one side of the border.
  ///
  /// - `0.0` → Disables the specular highlight entirely.
  /// - `1.0` → Default subtle specular reflection.
  /// - `>1.0` → Produces a stronger, sharper highlight for a more
  ///   glossy or crystal-like appearance.
  ///
  /// Recommended range: `0.0` to `2.0`.
  ///
  /// This parameter is classic-only — the optical border derives its rim
  /// from the glass shape and does not use these specular terms.
  final double oneSideLightIntensity;

  /// Controls the intensity of the double-sided specular highlight.
  ///
  /// Adds focused specular reflections on both sides of the light axis,
  /// simulating light hitting a glass surface from both directions.
  ///
  /// - `0.0` → Disabled (default).
  /// - `1.0` → Subtle double specular.
  /// - `>1.0` → Stronger highlights on both sides.
  ///
  /// Recommended range: `0.0` to `2.0`.
  ///
  /// This parameter is classic-only — the optical border derives its rim
  /// from the glass shape and does not use these specular terms.
  final double doubleSideLightIntensity;

  const ClassicBorder({
    this.borderSoftness = 1.0,
    this.shadowColor = const Color(0x1A000000),
    this.oneSideLightIntensity = 0.0,
    this.doubleSideLightIntensity = 0.0,
  });
}

/// Optical border.
///
/// The border is not stroked — it is what the glass edge does to the
/// backdrop behind it: a **highlight**, the refracted backdrop itself blown out
/// along the light axis, anchored on the shape outline and falling off
/// inward. `lightIntensity` drives the two arcs, `borderWidth` their depth.
///
/// The highlight brightens in CIE Lab, so a colored backdrop keeps its hue as
/// the rim goes hot instead of washing out to grey — which is how the border
/// picks up the background color (always active in optical mode).
///
/// Parameters specific to optical mode:
/// - [borderSaturation] — Currently has no effect on the optical rim.
/// - [ambientIntensity] — Strength of the side rim: a second pair of arcs
///   at 90° to the light, so the sides the highlight leaves dark keep a rim.
/// - [borderSolidity] — How solid the rim reads: higher holds the band at
///   full for longer, lower pulls it tight against the outline.
/// - [lightSpread] — How far the highlight wraps around the perimeter
///   (higher = broader).
class OpticalBorder extends LiquidGlassBorderType {
  /// **Currently has no effect:** the optical rim takes its colour from the
  /// backdrop alone. Kept so existing code keeps compiling.
  ///
  /// Controls the saturation boost applied to the final border color.
  ///
  /// Values above `1.0` increase color vividness, while values below `1.0`
  /// desaturate toward grayscale.
  ///
  /// - `0.0` — Fully desaturated (grayscale border).
  /// - `1.0` — No change (default).
  /// - `1.5` — Moderately more vivid.
  /// - `2.0` — Strongly saturated.
  ///
  /// Recommended range: `0.0` to `3.0`.
  final double borderSaturation;

  /// The optical rim's side light.
  ///
  /// Lights a second pair of arcs on the axis at 90° to [lightDirection],
  /// where the highlight's own arcs fall to nothing, so those sides keep a
  /// rim. It is a softer band than the highlight: white pulled toward the
  /// glass colour, a gentler lift, a wider and softer ramp, and a fixed
  /// moderate spread. It reads on the same scale as
  /// [LiquidGlassShape.lightIntensity].
  ///
  /// - `0.0` — The highlight's two arcs only; the sides are bare glass.
  /// - `1.0` — Default: a soft rim on the sides.
  /// - `3.0` — The sides read as strongly as the highlight.
  ///
  /// Recommended range: `0.0` to `3.0`.
  final double ambientIntensity;

  /// How solid the optical rim reads across its depth.
  ///
  /// The rim is a ramp that is strongest on the outline and falls away
  /// inward. Solidity slides that ramp: higher values hold the band at full
  /// for longer before it falls, so the rim reads as a solid line with a soft
  /// tail; lower values pull it tight against the outline.
  ///
  /// - `0.0` — Barely there: a faint hairline.
  /// - `0.5` — Default: a crisp, thin rim.
  /// - `0.6` — The plain ramp, full exactly on the outline.
  /// - `1.0` — Solid over the first 40% of the depth, then falls.
  ///
  /// Recommended range: `0.0` to `1.0`.
  final double borderSolidity;

  /// Controls how far the highlight spreads around the perimeter.
  ///
  /// The highlight lights two opposing arcs on the light axis and falls to nothing
  /// at 90° to it, where only the fill light (see [ambientIntensity]) is
  /// left. `lightSpread` widens or tightens those arcs — i.e. how much of the
  /// perimeter the highlight wraps across before the fill takes over.
  ///
  /// - `0.0` — Tight, concentrated highlight on the light-facing sides only.
  /// - `0.5` — Moderate wrap.
  /// - `0.9` — Default.
  /// - `1.0` — Broad highlight that wraps almost all the way around the rim.
  ///
  /// Recommended range: `0.0` to `1.0`.
  final double lightSpread;

  const OpticalBorder({
    this.borderSaturation = 1.0,
    this.ambientIntensity = 1.0,
    this.borderSolidity = 0.5,
    this.lightSpread = 0.9,
  });
}
