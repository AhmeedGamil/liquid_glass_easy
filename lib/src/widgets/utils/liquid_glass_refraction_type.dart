/// Base type for a liquid-glass refraction calculation and its controls.
///
/// This is independent of `LiquidGlassRefractionMode`, which selects the
/// geometry that directs the refraction (shape or radial).
sealed class LiquidGlassRefractionType {
  const LiquidGlassRefractionType();

  /// Width of the affected edge band, in logical pixels.
  double get width;

  /// Scales the visible effect while preserving calculation semantics.
  LiquidGlassRefractionType withEffectFactor(double factor);

  /// Scales [width] only, leaving the strength dials alone.
  ///
  /// For a surface that grows into its final size, the band has to grow
  /// with it — a width authored for the full-size glass is a huge
  /// proportion of a small one, so it would swallow the whole surface at
  /// the start of the animation.
  LiquidGlassRefractionType withWidthFactor(double factor);

  /// Whether this selects the physical optical calculation.
  bool get isOptical => this is OpticalRefraction;
}

/// The package's original nonlinear distortion calculation.
class StandardRefraction extends LiquidGlassRefractionType {
  /// Strength of the anchor-based distortion (`0.0`-`1.0`).
  final double distortion;

  /// Width of the distortion band around the perimeter, in logical pixels.
  final double distortionWidth;

  const StandardRefraction({
    this.distortion = 0.1,
    this.distortionWidth = 30,
  });

  @override
  double get width => distortionWidth;

  @override
  StandardRefraction withEffectFactor(double factor) => StandardRefraction(
        distortion: distortion * factor,
        distortionWidth: distortionWidth,
      );

  @override
  StandardRefraction withWidthFactor(double factor) => StandardRefraction(
        distortion: distortion,
        distortionWidth: distortionWidth * factor,
      );
}

/// A physical refraction approximation based on Snell's law.
class OpticalRefraction extends LiquidGlassRefractionType {
  /// Refractive index used by Snell's law — the bending **angle**.
  ///
  /// `1.0` produces no bending; common glass is approximately `1.5`. The
  /// calculation saturates, so the useful range is roughly `1.0`–`2.0`;
  /// much higher values barely change the result (the ray is already
  /// fully bent). Use [depth] to control *how much* the content moves.
  final double refraction;

  /// Width of the affected edge band, in logical pixels — how far in from
  /// the rim the bevel ramps from flat to vertical.
  final double refractionWidth;

  /// Optical depth — the **strength** dial (`0.0`–`1.0`): how far the
  /// refracted ray travels, i.e. how much the content behind the glass is
  /// displaced. Decoupled from [refractionWidth] (the band size) and from
  /// [refraction] (the angle): turn this up to bend more, like the old
  /// `distortion` knob, without widening the band.
  final double depth;

  const OpticalRefraction({
    this.refraction = 1.5,
    this.refractionWidth = 30,
    this.depth = 0.1,
  });

  @override
  double get width => refractionWidth;

  @override
  OpticalRefraction withEffectFactor(double factor) => OpticalRefraction(
        refraction: 1.0 + (refraction - 1.0) * factor,
        refractionWidth: refractionWidth,
        depth: depth * factor,
      );

  @override
  OpticalRefraction withWidthFactor(double factor) => OpticalRefraction(
        refraction: refraction,
        refractionWidth: refractionWidth * factor,
        depth: depth,
      );
}
