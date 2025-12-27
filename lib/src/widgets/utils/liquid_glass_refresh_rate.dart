/// Defines the refresh rate options for the [LiquidGlass] widget.
///
/// This enum allows you to control how often the liquid glass effect
/// updates per second, which can help balance visual smoothness and
/// performance.
enum LiquidGlassRefreshRate {
  /// Low refresh rate.
  low,

  /// Medium refresh rate.
  medium,

  /// High refresh rate.
  high,

  /// Match the device's system refresh rate if possible.
  ///
  /// This option attempts to sync the liquid glass effect
  /// with the display’s native refresh rate for smoother animations.
  deviceRefreshRate,
}
