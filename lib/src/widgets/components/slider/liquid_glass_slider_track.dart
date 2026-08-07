import 'package:flutter/material.dart';

import 'liquid_glass_slider_layout.dart';

/// Solid white pill — the at-rest slider thumb.
class SolidWhiteSliderThumb extends StatelessWidget {
  final double width;
  final double height;

  const SolidWhiteSliderThumb({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateless track + filled portion + tap/drag handling. Place this
/// inside the INNER `LiquidGlassView`'s `backgroundWidget` so the
/// glass thumb lens (built with [buildLiquidGlassSliderThumb]) can
/// refract the track during drags.
///
/// The thumb at rest is drawn here too as a static white pill. The
/// caller is responsible for hiding it (set [showRestThumb] to
/// false) while the glass lens is visible above.
class LiquidGlassSliderTrack extends StatelessWidget {
  /// Current value in 0..1.
  final double value;

  /// Where the thumb is being **drawn**, when that differs from [value] —
  /// motion models that tow the handle behind the finger pass it here so
  /// the fill (and the rest thumb) stay attached to the pill instead of
  /// leading it to the finger. Purely visual: every callback still speaks
  /// [value]. `null` means they coincide.
  final double? displayValue;

  /// Notified continuously while the user drags.
  final ValueChanged<double> onChanged;

  /// The unclamped position under the finger, in value units, reported on
  /// every drag update. Optional: only motion models that care about the
  /// overrun past an end need it.
  final ValueChanged<double>? onRawChanged;

  /// Notified when the user starts a drag (or taps).
  final ValueChanged<double>? onChangeStart;

  /// Notified when the user releases.
  final ValueChanged<double>? onChangeEnd;

  /// Show/hide the rest thumb (the white pill). Hide while the
  /// glass lens is taking its place.
  final bool showRestThumb;

  /// Color of the filled (left) portion of the track.
  final Color activeColor;

  /// Color of the unfilled track background.
  final Color inactiveColor;

  final LiquidGlassSliderLayout layout;

  /// Extra horizontal hit area added on EACH side of the visible track,
  /// in logical pixels. The track stays the same size visually, but the
  /// gesture area extends by this much left and right so the thumb's
  /// half-overhang at the two ends (which sits in the host's padding) is
  /// still tappable/draggable. Defaults to `0` (visible track only).
  final double hitSlopX;

  const LiquidGlassSliderTrack({
    super.key,
    required this.value,
    this.displayValue,
    required this.onChanged,
    this.onRawChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.showRestThumb = true,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x3CFFFFFF),
    this.layout = const LiquidGlassSliderLayout(),
    this.hitSlopX = 0,
  });

  void _handle(double localX) {
    final raw = localX / layout.width;
    // The raw, UNCLAMPED position under the finger, reported alongside the
    // clamped value. Past the ends of the track it keeps going, which is
    // the only record of how far the finger has overrun — the clamped
    // value simply sits at 0 or 1 and says nothing.
    onRawChanged?.call(raw);
    onChanged(raw.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final trackRadius = layout.trackHeight / 2;

    // Everything DRAWN follows the thumb's drawn position; [value] is
    // only what the gesture callbacks speak.
    final double shown = (displayValue ?? value).clamp(0.0, 1.0).toDouble();

    // Rest thumb position — center on the value.
    final thumbCenterX = shown * layout.travel;
    final thumbLeft = thumbCenterX - layout.thumbWidth / 2;

    // The gesture box is widened by hitSlopX on each side; the visible
    // track is re-centered inside it with symmetric padding, so taps in
    // the slop region map to track-local x = localX - hitSlopX.
    return SizedBox(
      width: layout.width + hitSlopX * 2,
      height: layout.thumbHeight, // reserve room for the thumb
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          onChangeStart?.call(value);
          _handle(d.localPosition.dx - hitSlopX);
        },
        onHorizontalDragUpdate: (d) => _handle(d.localPosition.dx - hitSlopX),
        onHorizontalDragEnd: (_) => onChangeEnd?.call(value),
        // Mirror *End* on a stolen gesture (e.g. a parent scrollable wins
        // the arena) so the host's grow/jelly state is never left latched.
        onHorizontalDragCancel: () => onChangeEnd?.call(value),
        onTapDown: (d) {
          onChangeStart?.call(value);
          _handle(d.localPosition.dx - hitSlopX);
        },
        onTapUp: (_) => onChangeEnd?.call(value),
        onTapCancel: () => onChangeEnd?.call(value),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hitSlopX),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Track at rest height, vertically centered.
              Positioned(
                left: 0,
                top: (layout.thumbHeight - layout.trackHeight) / 2,
                child: SizedBox(
                  width: layout.width,
                  height: layout.trackHeight,
                  child: Stack(
                    children: [
                      // Track background.
                      Container(
                        decoration: BoxDecoration(
                          color: inactiveColor,
                          borderRadius: BorderRadius.circular(trackRadius),
                        ),
                      ),
                      // Filled portion.
                      FractionallySizedBox(
                        widthFactor: shown,
                        heightFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(trackRadius),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Static white rest thumb. Hidden during the slide; the
              // glass thumb takes over above the track.
              if (showRestThumb)
                Positioned(
                  left: thumbLeft,
                  top: 0,
                  child: SolidWhiteSliderThumb(
                    width: layout.thumbWidth,
                    height: layout.thumbHeight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
