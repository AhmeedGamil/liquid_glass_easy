/// Geometry shared between the bar shell, the bar lens, and the
/// moving selection pill of the liquid-glass bottom nav bar.
///
/// The animated bottom nav bar uses a dual liquid-glass pipeline: an
/// INNER view captures the wallpaper + bar capsule, and an OUTER
/// view composites the moving selection pill on top. The result is a
/// selection pill that refracts the bar capsule's own glass output
/// — the iOS-26 "morphing pill" feel.
///
/// The non-animated [LiquidGlassTabBarShell] only needs this
/// for sizing; the moving-pill fields are consumed by the
/// (not-yet-exported) animated variant.
class LiquidGlassTabBarLayout {
  final int itemCount;
  final double width;
  final double height;
  final double bottomMargin;
  final double padding;

  /// How much taller the moving selection pill is than the bar's
  /// inner cell height. A positive value makes the pill extend above
  /// and below the bar so it reads as a clear "raised" element.
  final double pillExtraHeight;

  const LiquidGlassTabBarLayout({
    required this.itemCount,
    this.width = 280,
    this.height = 64,
    this.bottomMargin = 28,
    this.padding = 6,
    this.pillExtraHeight = 36,
  });

  double get cellWidth => (width - padding * 2) / itemCount;
  double get cellHeight => height - padding * 2;
  double get pillWidth => cellWidth;
  double get pillHeight => cellHeight + pillExtraHeight;

  LiquidGlassTabBarLayout copyWith({
    int? itemCount,
    double? width,
    double? height,
    double? bottomMargin,
    double? padding,
    double? pillExtraHeight,
  }) {
    return LiquidGlassTabBarLayout(
      itemCount: itemCount ?? this.itemCount,
      width: width ?? this.width,
      height: height ?? this.height,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      padding: padding ?? this.padding,
      pillExtraHeight: pillExtraHeight ?? this.pillExtraHeight,
    );
  }
}
