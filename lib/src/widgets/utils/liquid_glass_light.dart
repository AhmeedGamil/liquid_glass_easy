import 'dart:ui' show Color, lerpDouble;

import 'package:flutter/foundation.dart';

/// One light on a glass border: a band along the outline, lit as a pair of
/// opposing arcs.
///
/// A [LiquidGlassStyle] carries two of them: `specular`, the bright
/// highlight, and `glow`, the softer band that fills the sides the specular
/// leaves dark.
///
/// ```dart
/// LiquidGlassStyle(
///   specular: LiquidGlassLight.specular(
///       thickness: 5, sharpness: 0.5, angle: 39, spread: 0.9, intensity: 1),
///   glow: LiquidGlassLight.glow(
///       thickness: 10, angle: 90, spread: 0.5, intensity: 1),
/// )
/// ```
@immutable
class LiquidGlassLight {
  /// How deep the light's band reaches in from the outline, in logical
  /// pixels: the value is the band's depth as given, with no scaling.
  /// `0` draws nothing.
  ///
  /// Defaults: `5` for a specular, `10` for a glow.
  final double thickness;

  /// How solid the specular reads across its depth. Not used by a glow.
  ///
  /// The band is a ramp that is strongest on the outline and falls away
  /// inward. Sharpness slides that ramp: higher values hold the band at full
  /// for longer before it falls, so it reads as a solid line with a soft
  /// tail; lower values pull it tight against the outline.
  ///
  /// - `0.0` — Barely there: a faint hairline.
  /// - `0.5` — Default: a crisp, thin band.
  /// - `0.6` — The plain ramp, full exactly on the outline.
  /// - `1.0` — Solid over the first 40% of the depth, then falls.
  ///
  /// Recommended range: `0.0` to `1.0`.
  final double sharpness;

  /// The axis the light sits on, in degrees.
  ///
  /// The light draws two arcs, one on each end of this axis:
  /// - `0` — the left and right of the outline.
  /// - `39` — Default for a specular: a diagonal between the two.
  /// - `90` — Default for a glow: the top and bottom.
  final double angle;

  /// How far the arcs wrap around the outline.
  ///
  /// - `0.0` — Tight arcs on the light axis only.
  /// - `0.5` — Moderate wrap.
  /// - `1.0` — Broad arcs that wrap almost all the way around.
  ///
  /// Recommended range: `0.0` to `1.0`.
  final double spread;

  /// How strong the light is. `0.0` turns it off.
  ///
  /// Recommended range: `0.0` to `3.0`.
  final double intensity;

  /// How strong the arc on the far end of the light's axis is, as a
  /// multiple of the near arc.
  ///
  /// - `0.0` — One arc only: the far side stays dark.
  /// - `1.0` — Default: both arcs equally strong.
  /// - Above `1.0` — The far arc outshines the near one.
  ///
  /// Recommended range: `0.0` to `2.0`.
  final double oppositeIntensity;

  /// The light's own colour, or `null` for the colour the glass picks up.
  ///
  /// When `null` (the default) the light takes the colour of the backdrop
  /// seen through the edge, brightened — a specular and a glow alike. Give
  /// it white for a white light. When set, the light is drawn in this colour as given; its alpha
  /// is how much of it replaces the picked-up colour.
  final Color? color;

  /// The highlight: a thin, crisp band on the `39°` axis, wrapping wide.
  const LiquidGlassLight.specular({
    this.thickness = 5.0,
    this.sharpness = 0.5,
    this.angle = 39.0,
    this.spread = 0.9,
    this.intensity = 1.0,
    this.oppositeIntensity = 1.0,
    this.color,
  });

  /// The soft side light: a wider, gentler band on the `90°` axis.
  const LiquidGlassLight.glow({
    this.thickness = 10.0,
    this.angle = 90.0,
    this.spread = 0.5,
    this.intensity = 1.0,
    this.oppositeIntensity = 1.0,
    this.color,
  }) : sharpness = 0.5;

  const LiquidGlassLight._({
    required this.thickness,
    required this.sharpness,
    required this.angle,
    required this.spread,
    required this.intensity,
    required this.oppositeIntensity,
    required this.color,
  });

  /// A copy with the given fields replaced. [color] cannot be cleared here;
  /// build a new light for that.
  LiquidGlassLight copyWith({
    double? thickness,
    double? sharpness,
    double? angle,
    double? spread,
    double? intensity,
    double? oppositeIntensity,
    Color? color,
  }) =>
      LiquidGlassLight._(
        thickness: thickness ?? this.thickness,
        sharpness: sharpness ?? this.sharpness,
        angle: angle ?? this.angle,
        spread: spread ?? this.spread,
        intensity: intensity ?? this.intensity,
        oppositeIntensity: oppositeIntensity ?? this.oppositeIntensity,
        color: color ?? this.color,
      );

  /// Linearly interpolates between two lights.
  ///
  /// A `null` colour fades in from, or out to, the other light's colour at
  /// zero alpha, which draws the same as `null`.
  static LiquidGlassLight lerp(
      LiquidGlassLight a, LiquidGlassLight b, double t) {
    final Color? ca = a.color;
    final Color? cb = b.color;
    final Color? color = (ca == null && cb == null)
        ? null
        : Color.lerp(
            ca ?? cb!.withValues(alpha: 0),
            cb ?? ca!.withValues(alpha: 0),
            t,
          );
    return LiquidGlassLight._(
      thickness: lerpDouble(a.thickness, b.thickness, t)!,
      sharpness: lerpDouble(a.sharpness, b.sharpness, t)!,
      angle: lerpDouble(a.angle, b.angle, t)!,
      spread: lerpDouble(a.spread, b.spread, t)!,
      intensity: lerpDouble(a.intensity, b.intensity, t)!,
      oppositeIntensity:
          lerpDouble(a.oppositeIntensity, b.oppositeIntensity, t)!,
      color: color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassLight &&
          other.thickness == thickness &&
          other.sharpness == sharpness &&
          other.angle == angle &&
          other.spread == spread &&
          other.intensity == intensity &&
          other.oppositeIntensity == oppositeIntensity &&
          other.color == color;

  @override
  int get hashCode => Object.hash(
      thickness, sharpness, angle, spread, intensity, oppositeIntensity, color);

  @override
  String toString() =>
      'LiquidGlassLight(thickness: $thickness, sharpness: $sharpness, '
      'angle: $angle, spread: $spread, intensity: $intensity, '
      'oppositeIntensity: $oppositeIntensity, color: $color)';
}
