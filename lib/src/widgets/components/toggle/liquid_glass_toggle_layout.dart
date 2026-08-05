/// Layout for [LiquidGlassToggleTrack] /
/// [buildLiquidGlassToggleThumb].
///
/// At rest the handle is a solid **white** horizontal pill sitting
/// inside a tinted track (gray when off, green when on).
///
/// While it is held, the handle swells to [pressedScale] and the solid
/// pill hands over to a liquid-glass one. The slice of the colored track
/// *behind* the glass **shrinks** — scaled down in width and height
/// together, about the track's center — while the rest of the track
/// stays full size. The glass then refracts whatever sits around the
/// shrunken slice (typically the wallpaper).
class LiquidGlassToggleLayout {
  final double width;
  final double height;
  final double padding;

  /// Width of the handle at rest. Should be wider than [thumbHeight]
  /// for the pill look.
  final double thumbWidth;

  /// Height of the handle at rest.
  final double thumbHeight;

  /// How much the handle swells while it is held. The swell is sprung,
  /// so it briefly overshoots this on the way out.
  final double pressedScale;

  /// Height of the shrunken slice behind the glass. Make this
  /// noticeably less than [height] so the shrink is visible.
  ///
  /// Stated as a height, but it sets a **uniform** scale: the ratio
  /// `pinchedHeight / height` shrinks the width by the same amount, so
  /// the slice stays the same shape. It does not animate — the slice
  /// holds this size for the whole slide.
  final double pinchedHeight;

  /// Extra width the handle used to gain at the peak of the slide.
  ///
  /// No longer read: the handle now swells by [pressedScale] about its
  /// own center, so its peak size is a multiple of [thumbWidth] rather
  /// than a fixed addition to it.
  @Deprecated(
    'Superseded by pressedScale, which scales the whole handle. '
    'This field is ignored and will be removed in a future release.',
  )
  final double thumbExtraWidth;

  /// Extra height the handle used to gain at the peak of the slide.
  ///
  /// No longer read: handle height follows [pressedScale] (and the
  /// momentum squash) instead.
  @Deprecated(
    'Superseded by pressedScale, which scales the whole handle. '
    'This field is ignored and will be removed in a future release.',
  )
  final double thumbExtraHeight;

  const LiquidGlassToggleLayout({
    this.width = 64,
    this.height = 28,
    this.padding = 2,
    this.thumbWidth = 40,
    this.thumbHeight = 24,
    this.pressedScale = 1.5,
    this.pinchedHeight = 20,
    // ignore: deprecated_member_use_from_same_package
    this.thumbExtraWidth = 28,
    // ignore: deprecated_member_use_from_same_package
    this.thumbExtraHeight = 18,
  });

  /// Travel along the track between off and on positions.
  double get travel => width - thumbWidth - padding * 2;
}
