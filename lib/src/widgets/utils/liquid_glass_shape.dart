import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

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

  /// Controls the strength of the glass lighting and reflection effects on the border.
  ///
  /// This value adjusts how pronounced the Fresnel edge glow and specular highlights appear.
  ///
  /// - `0.0` → Disables all advanced lighting for a flat, simple border.
  /// - `1.0` → Default realistic glass lighting.
  /// - `>1.0` → Intensifies reflections for a more glossy or crystal-like effect.
  ///
  /// Recommended range: `0.0` to `2.0`.
  final double lightEffectIntensity;


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


  const LiquidGlassShape({
    this.borderWidth = 1.0,
    this.borderSoftness = 1.0,
    this.borderColor,
    this.lightIntensity = 1.0,
    this.lightEffectIntensity=0,
    this.lightColor = const Color(0xB2FFFFFF),
    this.shadowColor = const Color(0x1A000000),
    this.lightDirection = 0.0,
  });
}

class RoundedRectangleShape extends LiquidGlassShape {
  final double cornerRadius;
  final bool highDistortionOnCurves;
  const RoundedRectangleShape({
    this.cornerRadius = 50.0,
    this.highDistortionOnCurves=false,
    super.borderWidth,
    super.borderSoftness,
    super.borderColor,
    super.lightIntensity,
    super.lightEffectIntensity,
    super.lightColor,
    super.shadowColor,
    super.lightDirection,
  });

}

class SuperellipseShape extends LiquidGlassShape {
  final double curveExponent;

  const SuperellipseShape({
    this.curveExponent = 3.0,
    super.borderWidth,
    super.borderSoftness,
    super.borderColor,
    super.lightIntensity,
    super.lightEffectIntensity,
    super.lightColor,
    super.shadowColor,
    super.lightDirection,
  });
}


