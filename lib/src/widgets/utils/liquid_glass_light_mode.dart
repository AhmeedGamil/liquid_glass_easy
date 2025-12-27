/// Defines how lighting is calculated along the liquid glass border.
///
/// This enum controls how the light interacts with the edges of the
/// liquid glass effect, influencing the highlights and shading
/// along the border.
enum LiquidGlassLightMode {
  /// Uses the shape’s edge gradient as the surface normal.
  ///
  /// Produces lighting that follows the contour of the glass border,
  /// allowing the light to expand along straight edges.
  /// This results in more physically accurate edge highlights.
  edge,

  /// Uses a radial direction from the center of the glass to each fragment.
  ///
  /// Causes the light to expand naturally along curved edges,
  /// creating a uniform, lens-like lighting sweep around the border.
  radial,
}