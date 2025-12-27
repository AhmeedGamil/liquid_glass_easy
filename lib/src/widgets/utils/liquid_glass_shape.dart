import 'package:flutter/material.dart';

import 'liquid_glass_light_mode.dart';

/// Abstract base border configuration
abstract class LiquidGlassShape {
  /// The thickness of the lens border in logical pixels.
  ///
  /// Increasing this value makes the border appear thicker
  /// around the lens perimeter.
  final double borderWidth;

  /// The smoothness or falloff softness of the border edge.
  ///
  /// A higher value results in a softer, feathered border transition,
  /// while a lower value keeps it crisp and sharp.
  final double borderSoftness;

  /// The base color of the lens border.
  ///
  /// If not`null`, This will replace the light and shadow color. Its a solid color.
  final Color? borderColor;

  /// The brightness multiplier for lens lighting and reflections.
  ///
  /// Controls how strongly highlights and shadows appear on the border.
  /// - Typical range: `0.0` (no lighting) → `1.0` (normal brightness) → `>1.0` (strong glow).
  final double lightIntensity;

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
  final double oneSideLightIntensity;

  /// The primary highlight color applied to illuminated areas of the lens border.
  ///
  /// Usually a lighter tint such as white or pale yellow.
  final Color lightColor;

  /// The shadow color used on the opposite side of the lens border
  /// to enhance depth and contrast.
  ///
  /// Typically a darker or cooler tone to complement `lightColor`.
  final Color shadowColor;

  /// The directional angle (in degrees) from which the simulated light hits the lens.
  ///
  /// - `0°` means light comes from the right.
  /// - `90°` means light comes from the top.
  /// - `180°` from the left, and `270°` from the bottom.
  ///
  /// Used to compute where highlights and shadows fall on the border.
  final double lightDirection;

  /// Defines how lighting is calculated along the liquid glass border.
  ///
  /// • [LiquidGlassLightMode.edge] — Uses the shape’s edge gradient
  ///   as the surface normal, producing lighting that follows the
  ///   contour of the glass border and the light to expand along
  ///   straight edges  This results in more physically
  ///   accurate edge highlights.
  ///
  /// • [LiquidGlassLightMode.radial] — Uses a radial direction from
  ///   the center of the glass to each fragment, causing the light to expand naturally
  ///   along curved edges creating a uniform,
  ///   lens-like lighting sweep around the border.
  final LiquidGlassLightMode lightMode;

  const LiquidGlassShape({
    this.borderWidth = 1.0,
    this.borderSoftness = 1.0,
    this.borderColor,
    this.lightIntensity = 1.0,
    this.oneSideLightIntensity = 0,
    this.lightColor = const Color(0xB2FFFFFF),
    this.shadowColor = const Color(0x1A000000),
    this.lightDirection = 0.0,
    this.lightMode = LiquidGlassLightMode.edge,
  });
}

class RoundedRectangleShape extends LiquidGlassShape {
  final double cornerRadius;
  const RoundedRectangleShape(
      {this.cornerRadius = 50.0,
      super.borderWidth,
      super.borderSoftness,
      super.borderColor,
      super.lightIntensity,
      super.oneSideLightIntensity,
      super.lightColor,
      super.shadowColor,
      super.lightDirection,
      super.lightMode});
}

class SuperellipseShape extends LiquidGlassShape {
  final double curveExponent;

  const SuperellipseShape(
      {this.curveExponent = 3.0,
      super.borderWidth,
      super.borderSoftness,
      super.borderColor,
      super.lightIntensity,
      super.oneSideLightIntensity,
      super.lightColor,
      super.shadowColor,
      super.lightDirection,
      super.lightMode});
}
