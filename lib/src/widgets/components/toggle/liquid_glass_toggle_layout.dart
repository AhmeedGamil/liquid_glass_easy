import 'dart:math' as math;

/// Sizing for [LiquidGlassToggle] — the track behind the thumb and the
/// two sizes the thumb itself morphs between.
///
/// Everything the control positions is derived from these numbers: the
/// two resting positions, the travel between them, the rubber band's
/// limits, and the capture view painted around the whole thing. Change
/// [width] and [height] and the rest follows.
///
/// The defaults are the iOS-26 sliding switch: a 63×28 track carrying a
/// 37×24 handle that swells to 58×38.33 while it is held — wider AND
/// taller than the track it sits in, which is why the thumb overhangs.
class LiquidGlassToggleLayout {
  /// Width of the track — the capsule the thumb rides along. This is
  /// also the control's layout footprint.
  final double width;

  /// Height of the track. The track is always a capsule, so its corner
  /// radius is half of this.
  final double height;

  /// Inset of the resting thumb inside the track, on every side. With
  /// the defaults this is the 2 px gap you see around the white pill.
  final double padding;

  /// Width of the thumb at rest. Should exceed [thumbHeight] for the
  /// pill look.
  final double thumbWidth;

  /// Height of the thumb at rest. `height - padding * 2` keeps the
  /// classic snug fit; anything smaller floats it in the track.
  final double thumbHeight;

  /// Width of the thumb while it is held, once it has become glass.
  final double expandedThumbWidth;

  /// Height of the thumb while it is held. Larger than [height] is the
  /// intended look — the glass pill is meant to overhang the track.
  final double expandedThumbHeight;

  /// Height of the shrunken slice of track drawn **behind the glass**.
  ///
  /// This is the separate track — not the one you see at the ends. While
  /// the thumb is lifted, a pill-shaped hole is cut where the glass sits
  /// and a *smaller copy of the whole capsule* is dropped into it, so the
  /// track reads full size on either side of the thumb and shrunken
  /// underneath it. Leave it equal to [height] and there is no pinch at
  /// all; the further below [height] you take it, the more the slice
  /// pulls away from the glass rim.
  ///
  /// Stated as a height, but it sets a **uniform** scale: the ratio
  /// [bodyScale] shrinks the width by the same amount, so the slice stays
  /// the same shape rather than becoming a squashed one. It does not
  /// animate — the slice holds this size for the whole gesture, and only
  /// the hole grows with the thumb, so nothing appears to scale as the
  /// glass uncovers it.
  final double pinchedHeight;

  /// How far past a resting position the rubber band is allowed to
  /// carry the thumb before the capture view runs out of room.
  ///
  /// The band advances by `sqrt(overrun)`, so this is generous: 20 px of
  /// room absorbs roughly 400 px of finger travel past the end. Drag
  /// further than that and the thumb's overhang clips.
  final double overshootRoom;

  /// How much the handle used to swell while it was held.
  ///
  /// No longer read: the held size is stated outright by
  /// [expandedThumbWidth] / [expandedThumbHeight], so the thumb can grow
  /// by different amounts on the two axes instead of one uniform scale.
  @Deprecated(
    'Superseded by expandedThumbWidth / expandedThumbHeight, which state '
    'the held size directly. This field is ignored and will be removed in '
    'a future release.',
  )
  final double pressedScale;

  /// Extra width the handle used to gain at the peak of the slide.
  ///
  /// No longer read: the held size is stated outright by
  /// [expandedThumbWidth].
  @Deprecated(
    'Superseded by expandedThumbWidth. This field is ignored and will be '
    'removed in a future release.',
  )
  final double thumbExtraWidth;

  /// Extra height the handle used to gain at the peak of the slide.
  ///
  /// No longer read: the held size is stated outright by
  /// [expandedThumbHeight].
  @Deprecated(
    'Superseded by expandedThumbHeight. This field is ignored and will be '
    'removed in a future release.',
  )
  final double thumbExtraHeight;

  const LiquidGlassToggleLayout({
    this.width = 63,
    this.height = 28,
    this.padding = 2,
    this.thumbWidth = 37,
    this.thumbHeight = 24,
    this.expandedThumbWidth = 58,
    this.expandedThumbHeight = 38.333,
    this.pinchedHeight = 20,
    this.overshootRoom = 20,
    // ignore: deprecated_member_use_from_same_package
    this.pressedScale = 1.5,
    // ignore: deprecated_member_use_from_same_package
    this.thumbExtraWidth = 28,
    // ignore: deprecated_member_use_from_same_package
    this.thumbExtraHeight = 18,
  });

  /// Uniform scale of the slice behind the glass, `pinchedHeight /
  /// height`. `1` leaves the track untouched under the thumb.
  double get bodyScale => height <= 0 ? 1.0 : pinchedHeight / height;

  /// Thumb centre when off — the left resting position, in track
  /// coordinates.
  double get minThumbCenterX => padding + thumbWidth / 2;

  /// Thumb centre when on — the right resting position.
  double get maxThumbCenterX => width - minThumbCenterX;

  /// Distance the thumb covers between the two resting positions.
  double get travel => maxThumbCenterX - minThumbCenterX;

  /// Horizontal room the capture view needs on each side of the track:
  /// how far the expanded thumb reaches past the track at a resting
  /// position, plus the rubber band's allowance.
  double get padX =>
      math.max(0.0, maxThumbCenterX + expandedThumbWidth / 2 - width) +
      overshootRoom;

  /// Vertical room the capture view needs above and below the track.
  double get padY => math.max(0.0, (expandedThumbHeight - height) / 2) + 4.0;

  /// Full size of the capture view painted around the track.
  double get viewWidth => width + padX * 2;
  double get viewHeight => height + padY * 2;

  LiquidGlassToggleLayout copyWith({
    double? width,
    double? height,
    double? padding,
    double? thumbWidth,
    double? thumbHeight,
    double? expandedThumbWidth,
    double? expandedThumbHeight,
    double? pinchedHeight,
    double? overshootRoom,
  }) {
    return LiquidGlassToggleLayout(
      width: width ?? this.width,
      height: height ?? this.height,
      padding: padding ?? this.padding,
      thumbWidth: thumbWidth ?? this.thumbWidth,
      thumbHeight: thumbHeight ?? this.thumbHeight,
      expandedThumbWidth: expandedThumbWidth ?? this.expandedThumbWidth,
      expandedThumbHeight: expandedThumbHeight ?? this.expandedThumbHeight,
      pinchedHeight: pinchedHeight ?? this.pinchedHeight,
      overshootRoom: overshootRoom ?? this.overshootRoom,
    );
  }

  /// A layout scaled uniformly by [factor] — the quickest way to make
  /// the whole switch bigger without re-picking seven numbers.
  LiquidGlassToggleLayout scaled(double factor) => LiquidGlassToggleLayout(
        width: width * factor,
        height: height * factor,
        padding: padding * factor,
        thumbWidth: thumbWidth * factor,
        thumbHeight: thumbHeight * factor,
        expandedThumbWidth: expandedThumbWidth * factor,
        expandedThumbHeight: expandedThumbHeight * factor,
        pinchedHeight: pinchedHeight * factor,
        overshootRoom: overshootRoom * factor,
      );
}
