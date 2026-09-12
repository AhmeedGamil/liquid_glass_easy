import 'package:flutter/material.dart';

/// Defines the rendering style for the liquid glass border.
///
/// [OpticalBorder] is the default and the one to use: Apple-style SDF rim
/// lighting, derived from the glass shape, tinted by what is behind it.
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

/// Apple-style optical border.
///
/// The border emerges as an optical consequence of the glass shape,
/// using SDF-based rim lighting with rational falloff, background-tinted
/// highlights, dual-sided specular reflections, and a lens height profile.
///
/// The border automatically picks up background color through ambient
/// tinting (always active in optical mode).
///
/// Parameters specific to optical mode:
/// - [borderSaturation] — Saturation boost applied to the border color.
/// - [ambientIntensity] — Ambient lighting contribution to the rim.
/// - [borderSolidity] — How much `lightIntensity` can drive the rim toward
///   a fully opaque/solid look.
/// - [lightSpread] — How far the bright rim highlight wraps around the
///   perimeter (higher = broader).
class OpticalBorder extends LiquidGlassBorderType {
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

  /// Controls the ambient lighting contribution to the optical rim.
  ///
  /// The ambient term is added on top of the directional light strength,
  /// brightening the rim uniformly so it remains visible even on the
  /// shadow side of the shape.
  ///
  /// - `0.0` — No ambient contribution (rim only lit from the directional
  ///   light).
  /// - `1.0` — Default ambient gain.
  /// - `>1.0` — Stronger ambient glow that washes around the entire rim.
  ///
  /// Recommended range: `0.0` to `5.0`.
  final double ambientIntensity;

  /// Controls how much `lightIntensity` can push the optical rim toward a
  /// fully solid (opaque) appearance.
  ///
  /// By default the optical rim caps its internal light contribution to
  /// `1.0` so increasing `lightIntensity` only modulates visibility within
  /// a fixed extent — the rim never goes fully solid. With higher solidity
  /// the cap is gradually lifted, allowing high `lightIntensity` to drive
  /// the rim alpha to fully opaque (the older renderer-style behavior).
  ///
  /// - `0.0` — Translucent rim only (default; current behavior).
  /// - `0.5` — Halfway: rim brightens past the cap but stays partially
  ///   translucent.
  /// - `1.0` — Light-driven solid rim (legacy behavior — high
  ///   `lightIntensity` makes the rim opaque).
  ///
  /// Recommended range: `0.0` to `1.0`.
  final double borderSolidity;

  /// Controls how far the bright rim highlight spreads around the perimeter.
  ///
  /// The optical rim has two overlapping contributions: an angle-independent
  /// ambient ring (see [ambientIntensity]) and a directional highlight that is
  /// brightest where the surface faces the light. `lightSpread` widens or
  /// tightens the angular reach of that directional highlight — i.e. how much
  /// of the perimeter it wraps across before fading into the ambient ring.
  ///
  /// - `0.0` — Tight, concentrated highlight on the light-facing sides only.
  /// - `0.5` — Default (matches the legacy fixed falloff).
  /// - `1.0` — Broad highlight that wraps almost all the way around the rim.
  ///
  /// Recommended range: `0.0` to `1.0`.
  final double lightSpread;

  const OpticalBorder({
    this.borderSaturation = 1.0,
    this.ambientIntensity = 1.0,
    this.borderSolidity = 0.0,
    this.lightSpread = 0.5,
  });
}
