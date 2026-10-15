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

  /// The selection pill's width at rest. `null` makes it one cell,
  /// `(width - 2 * padding) / itemCount`, with every item centred in its
  /// cell.
  ///
  /// When set, the first and last items sit `padding + pillWidth / 2` in
  /// from the bar's ends and the items between share the rest of the row
  /// evenly, so the pill can be wider than an equal share.
  final double? restPillWidth;

  const LiquidGlassTabBarLayout({
    required this.itemCount,
    this.width = 280,
    this.height = 64,
    this.bottomMargin = 28,
    this.padding = 6,
    this.pillExtraHeight = 36,
    this.restPillWidth,
  });

  double get cellWidth => (width - padding * 2) / itemCount;
  double get cellHeight => height - padding * 2;

  /// The selection pill's width at rest, never wider than the row.
  double get pillWidth =>
      restPillWidth?.clamp(0.0, width - padding * 2) ?? cellWidth;
  double get pillHeight => cellHeight + pillExtraHeight;

  /// The distance between neighbouring items' centres. One cell when the
  /// pill is one cell wide.
  double get itemStep => itemCount > 1
      ? (width - padding * 2 - pillWidth) / (itemCount - 1)
      : 0;

  /// Where the pill's left edge sits at fractional index [frac], from the
  /// start of the row (inside [padding]).
  double pillOffset(double frac) => frac * itemStep;

  /// The fractional index whose pill is centred at [rowX], from the start
  /// of the row (inside [padding]), clamped to the items.
  double fracAt(double rowX) {
    if (itemCount < 2 || itemStep <= 0) return 0;
    return ((rowX - pillWidth / 2) / itemStep)
        .clamp(0.0, (itemCount - 1).toDouble());
  }

  /// The item nearest [rowX], from the start of the row.
  int indexAt(double rowX) => fracAt(rowX).round();

  LiquidGlassTabBarLayout copyWith({
    int? itemCount,
    double? width,
    double? height,
    double? bottomMargin,
    double? padding,
    double? pillExtraHeight,
    double? restPillWidth,
  }) {
    return LiquidGlassTabBarLayout(
      itemCount: itemCount ?? this.itemCount,
      width: width ?? this.width,
      height: height ?? this.height,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      padding: padding ?? this.padding,
      pillExtraHeight: pillExtraHeight ?? this.pillExtraHeight,
      restPillWidth: restPillWidth ?? this.restPillWidth,
    );
  }
}
