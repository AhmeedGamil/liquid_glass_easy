class LiquidGlassBlur{
  /// The horizontal blur intensity (sigma value).
  ///
  /// Controls how much the background is blurred **horizontally** beneath the lens.
  /// - Higher values produce a stronger blur along the X-axis.
  final double sigmaX;

  /// The vertical blur intensity (sigma value).
  ///
  /// Controls how much the background is blurred **vertically** beneath the lens.
  /// - Higher values produce a stronger blur along the Y-axis.
  final double sigmaY;

  const LiquidGlassBlur({
    this.sigmaX=0,
    this.sigmaY=0,
  });
}