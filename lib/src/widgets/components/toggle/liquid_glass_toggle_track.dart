import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'liquid_glass_toggle_layout.dart';

/// Solid white pill — the at-rest toggle thumb.
class SolidWhiteToggleThumb extends StatelessWidget {
  final double width;
  final double height;

  const SolidWhiteToggleThumb({
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

/// Paints the toggle track body as ONE filled path: a full-height
/// capsule with a **smaller copy of itself** union'd into the slice the
/// glass thumb covers. The pinch is built by cutting a pill-shaped hole
/// at the glass position and unioning the shrunken capsule back in.
/// Doing it in a single fill — instead of stacking a capsule and a
/// separate "fake pill" — keeps a uniform alpha, so a translucent track
/// color never doubles up into a darker band.
///
/// The inner copy is scaled on **both axes** by [bodyScale] and placed
/// where a lens of that magnification would put it: scaled about the
/// glass's center, so its own center lands at
/// `bodyScale·trackCenter + (1 - bodyScale)·holeCenterX`. It therefore
/// drifts toward the handle at `(1 - bodyScale)` of the handle's travel
/// rather than being pinned to the track or carried along with the
/// glass. Its corner radius scales with it, so it stays a true capsule.
class ToggleBodyPainter extends CustomPainter {
  final Color color;
  final double radius;
  final bool animating;
  final double holeCenterX;
  final double holeWidth;
  final double holeHeight;

  /// Uniform scale of the body inside the hole. `1` is the untouched
  /// capsule; smaller shrinks it in width and height together.
  final double bodyScale;

  ToggleBodyPainter({
    required this.color,
    required this.radius,
    required this.animating,
    required this.holeCenterX,
    required this.holeWidth,
    required this.holeHeight,
    required this.bodyScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    final capsule = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    Path body = capsule;
    if (animating && holeWidth > 0.001 && holeHeight > 0.001) {
      final hole = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(holeCenterX, size.height / 2),
            width: holeWidth,
            height: holeHeight,
          ),
          Radius.circular(holeHeight / 2),
        ));
      // The track capsule scaled on both axes, placed where a LENS of
      // the same magnification would show it.
      //
      // A lens maps a fragment to `lensCenter + (frag - lensCenter) / m`,
      // so backdrop point `q` lands at `lensCenter + m·(q - lensCenter)`:
      // the whole track appears scaled by `m` about the LENS center, and
      // its center lands at `m·trackCenter + (1 - m)·lensCenter`. So it
      // is neither pinned to the track nor welded to the handle — it
      // drifts toward the handle at `(1 - m)` of the handle's travel,
      // which is what minifying glass actually does.
      //
      // Scaled about a point inside itself, a convex shape stays inside
      // itself, so this only ever removes area from the capsule and
      // never adds any: the body outside the glass is untouched.
      final bodyCenterX =
          bodyScale * (size.width / 2) + (1 - bodyScale) * holeCenterX;
      final shrunk = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(bodyCenterX, size.height / 2),
            width: size.width * bodyScale,
            height: size.height * bodyScale,
          ),
          Radius.circular(radius * bodyScale),
        ));
      body = Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.difference, capsule, hole),
        shrunk,
      );
    }

    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant ToggleBodyPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.animating != animating ||
      old.holeCenterX != holeCenterX ||
      old.holeWidth != holeWidth ||
      old.holeHeight != holeHeight ||
      old.bodyScale != bodyScale;
}

/// Stateless toggle track: capsule background that tints from a
/// gray (off) to a solid color (on), with a static white pill
/// thumb drawn inline. Place inside the INNER `LiquidGlassView`'s
/// `backgroundWidget` so the moving glass thumb (built with
/// [buildLiquidGlassToggleThumb]) can refract it.
///
/// While [pinchFraction] > 0, a pill-shaped hole is cut out of
/// the colored capsule at the glass's x position (driven by
/// [travelFraction]) and a **smaller copy of the whole capsule** —
/// scaled on both axes about the track's center — is drawn inside the
/// hole. The glass thumb hides the cut edges entirely, so the user
/// sees: full-height capsule on the sides, plus a shrunken capsule
/// behind the glass.
///
/// The shrunken copy holds one size for the whole slide; it only shifts
/// by the small amount a lens of that magnification would shift it (see
/// [ToggleBodyPainter]), so it never appears to scale under the glass.
class LiquidGlassToggleTrack extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final LiquidGlassToggleLayout layout;

  /// `0` at rest (no hole, plain capsule), `1` at the peak of the
  /// slide (max-size hole). It sizes the **hole** only — the shrunken
  /// body inside it holds one fixed size throughout.
  final double pinchFraction;

  /// `0` when off and `1` when on. Drives where the hole + fake
  /// pill sit along the track. Pass the same value used for the
  /// glass thumb's [buildLiquidGlassToggleThumb] `travelFraction`.
  final double travelFraction;

  /// Tint color of the track when [value] is true. Defaults to a
  /// system green.
  final Color tint;

  /// Background color of the track when [value] is false. Defaults
  /// to a translucent gray that reads well over a glass canvas.
  final Color offColor;

  /// Show/hide the rest thumb (the static white pill). Hide while
  /// the glass lens is taking its place during the slide.
  final bool showRestThumb;

  /// Footprint of the glass handle right now, which the hole is cut to
  /// match. Null falls back to the rest handle size.
  ///
  /// The handle swells and squashes on its own springs, so the host
  /// passes the size it actually rendered rather than having the track
  /// re-derive it — otherwise the cut edge drifts out from under the
  /// glass rim and shows a seam.
  final double? pillWidth;
  final double? pillHeight;

  /// How far along the travel the handle currently is, `0`..`1`. The
  /// body color is mixed from [offColor] to [tint] by it, so the track
  /// recolors *continuously under the finger* rather than snapping when
  /// [value] flips.
  ///
  /// When null it falls back to [value], which jumps.
  final double? fraction;

  const LiquidGlassToggleTrack({
    super.key,
    required this.value,
    required this.onChanged,
    this.tint = const Color(0xFF34C759),
    this.offColor = const Color(0x66808080),
    this.layout = const LiquidGlassToggleLayout(),
    this.showRestThumb = true,
    this.pinchFraction = 0,
    this.travelFraction = 0,
    this.pillWidth,
    this.pillHeight,
    this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final p = pinchFraction.clamp(0.0, 1.0);
    final isAnimating = p > 0.001;

    // Hole geometry — matched to the ACTUAL glass-pill footprint the
    // host rendered, so the track body behind the glass is removed
    // across the full pill, not just a narrow center. Inset by a 1.5px
    // hair on every side so the cut edge tucks just under the glass
    // overhang and never shows a seam.
    const edgeInset = 1.5;
    final pillW = pillWidth ?? layout.thumbWidth;
    final pillH = pillHeight ?? layout.thumbHeight;
    final holeWidth = math.max(0.0, pillW - edgeInset * 2);
    final holeHeight = math.max(0.0, pillH - edgeInset * 2);

    // Center of the hole at this travel fraction. Mirrors the math
    // used by buildLiquidGlassToggleThumb so the hole tracks the
    // glass.
    final holeCenterX = layout.padding +
        travelFraction * layout.travel +
        layout.thumbWidth / 2;

    // Uniform scale of the body behind the glass. [pinchedHeight] still
    // states it as a height, but it drives BOTH axes: the same ratio
    // shrinks the width, so the slice under the glass is a smaller copy
    // of the track instead of a squashed one.
    //
    // Deliberately NOT driven by [pinchFraction]. The slice is at its
    // shrunken size for the whole slide — only the hole grows with the
    // glass — so the body never appears to scale underneath it. What
    // the glass uncovers is already the final size.
    final bodyScale = layout.pinchedHeight / layout.height;

    // Rest thumb position (white pill at on/off endpoints). Always
    // computed against the rest layout so its on/off positions
    // don't shift while the track changes.
    final thumbLeft =
        layout.padding + (value ? layout.travel : 0.0);
    final thumbTop = (layout.height - layout.thumbHeight) / 2;

    // Recolor with the handle, not with `value`: the body mixes toward
    // the tint as it travels, so a slow drag recolors under the finger
    // and follows it back if the user changes their mind.
    final f = (fraction ?? (value ? 1.0 : 0.0)).clamp(0.0, 1.0);
    final bodyColor = Color.lerp(offColor, tint, f)!;

    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The whole track body — a full-height capsule with a
            // uniformly shrunken copy of itself under the glass —
            // painted as a SINGLE filled path. One layer means one alpha
            // everywhere, so a translucent track color can't double up
            // into a darker band the way a stacked fake pill did.
            Positioned.fill(
              child: CustomPaint(
                painter: ToggleBodyPainter(
                  color: bodyColor,
                  radius: layout.height / 2,
                  animating: isAnimating,
                  holeCenterX: holeCenterX,
                  holeWidth: holeWidth,
                  holeHeight: holeHeight,
                  bodyScale: bodyScale,
                ),
              ),
            ),
            // Static white pill thumb. Anchored to the REST rect.
            // Hidden during the slide; the glass takes over.
            if (showRestThumb)
              Positioned(
                left: thumbLeft,
                top: thumbTop,
                child: SolidWhiteToggleThumb(
                  width: layout.thumbWidth,
                  height: layout.thumbHeight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
