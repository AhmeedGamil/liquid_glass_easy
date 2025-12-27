/// Determines how light is refracted through the liquid glass surface.
///
/// This enum controls the visual distortion pattern applied to the
/// background behind the glass effect. It affects how the liquid glass
/// distorts whatever is behind it, giving different visual appearances.
enum LiquidGlassRefractionMode {
  /// Refracts light based on the underlying shape geometry.
  ///
  /// The distortion follows the contours of the glass, creating
  /// a more physically accurate refraction effect based on the shape.
  shapeRefraction,

  /// Refracts light radially from a central point.
  ///
  /// Creates a circular distortion pattern, useful for effects like
  /// magnifying or warping around a center point.
  radialRefraction,
}