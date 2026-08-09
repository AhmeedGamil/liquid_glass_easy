import 'dart:math' as math;

/// Geometry of a [LiquidGlassSlider]: the track, the two thumb sizes it
/// morphs between, and the end icons.
///
/// The thumb has **two** sizes, not one. At rest it is a small solid pill
/// lying in the track ([thumbWidth] × [thumbHeight]); the moment a finger
/// lands it morphs into a larger glass pill ([liftedThumbWidth] ×
/// [liftedThumbHeight]) that is carried until the touch ends. The
/// defaults are the tuned pair; scale both together if you resize one, or
/// the morph changes proportion mid-flight.
class LiquidGlassSliderLayout {
  /// Total width of the control, end to end.
  final double width;

  /// Thickness of the track the thumb rides.
  final double trackHeight;

  /// The resting thumb — a solid pill sitting in the track.
  final double thumbWidth;
  final double thumbHeight;

  /// The lifted thumb — the glass pill the rest thumb morphs into while a
  /// finger is on the control.
  final double liftedThumbWidth;
  final double liftedThumbHeight;

  /// Size of the optional end icons, and the gap between an icon and the
  /// track. Ignored when the slider has no icons.
  final double iconSize;
  final double iconGap;

  /// Horizontal breathing room reserved at each end, and the control's
  /// total height.
  ///
  /// Both default to `null`, which **derives them** from the thumb sizes
  /// and the slider's squash/stretch ceiling — the lifted thumb overhangs
  /// the track's ends, the end rubber-band overshoots, and the
  /// deformation grows the pill on both axes, and all of that has to fit
  /// inside the glass capture or it is clipped mid-gesture.
  ///
  /// Set them only to override that reasoning; see
  /// [derivedHorizontalInset] and [derivedHeight] for what the numbers
  /// would otherwise be.
  final double? horizontalInset;
  final double? height;

  const LiquidGlassSliderLayout({
    this.width = 280,
    this.trackHeight = 6,
    this.thumbWidth = 37,
    this.thumbHeight = 24,
    this.liftedThumbWidth = 58,
    this.liftedThumbHeight = 38.333,
    this.iconSize = 20,
    this.iconGap = 8,
    this.horizontalInset,
    this.height,
  });

  /// The inset [horizontalInset] falls back to, for a squash/stretch
  /// ceiling of [maxDeviation] (`0` for a slider that does not deform).
  ///
  /// Three things have to fit: half the lifted thumb's overhang past the
  /// track ends, the width the deformation can add, and the rubber-band
  /// overshoot past a bound.
  double derivedHorizontalInset(double maxDeviation) =>
      (liftedThumbWidth - thumbWidth) / 2 +
      liftedThumbWidth * maxDeviation / 2 +
      8;

  /// The height [height] falls back to: the lifted thumb at full squash,
  /// plus a little for the expand spring's overshoot.
  double derivedHeight(double maxDeviation) =>
      liftedThumbHeight * (1 + maxDeviation) + 2;

  /// The inset actually used — [horizontalInset] when set, else derived.
  double resolveHorizontalInset(double maxDeviation) =>
      horizontalInset ?? derivedHorizontalInset(maxDeviation);

  /// The height actually used — [height] when set, else derived.
  double resolveHeight(double maxDeviation) =>
      math.max(liftedThumbHeight, height ?? derivedHeight(maxDeviation));

  LiquidGlassSliderLayout copyWith({
    double? width,
    double? trackHeight,
    double? thumbWidth,
    double? thumbHeight,
    double? liftedThumbWidth,
    double? liftedThumbHeight,
    double? iconSize,
    double? iconGap,
    double? horizontalInset,
    double? height,
  }) {
    return LiquidGlassSliderLayout(
      width: width ?? this.width,
      trackHeight: trackHeight ?? this.trackHeight,
      thumbWidth: thumbWidth ?? this.thumbWidth,
      thumbHeight: thumbHeight ?? this.thumbHeight,
      liftedThumbWidth: liftedThumbWidth ?? this.liftedThumbWidth,
      liftedThumbHeight: liftedThumbHeight ?? this.liftedThumbHeight,
      iconSize: iconSize ?? this.iconSize,
      iconGap: iconGap ?? this.iconGap,
      horizontalInset: horizontalInset ?? this.horizontalInset,
      height: height ?? this.height,
    );
  }
}
