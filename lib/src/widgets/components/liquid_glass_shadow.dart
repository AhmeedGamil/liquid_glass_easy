import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The contact shadow of a glass pill: a soft dark band
/// that hugs the rim and pools underneath, so the glass reads as sitting
/// *in* the surface rather than floating flat on it.
///
/// ## Wrap the lens, don't go inside it
///
/// This is a **parent** of the glass, not its content:
///
/// ```dart
/// LiquidGlassShadow(
///   child: LiquidGlassLens(...),
/// )
/// ```
///
/// That placement is the whole point. A lens clips its own child to its
/// outline, so a shadow passed as content can only ever darken the inside
/// — the half that pools *below* the pill would be cut away, which is the
/// half that actually reads as contact. As a parent it is unclipped, and
/// free to spill past the edge.
///
/// It paints **behind** what it wraps ([CustomPaint.painter], before the
/// child), so the glass sits over its own shadow. That is also what keeps
/// a rest state honest: a solid pill drawn over the glass covers the
/// shadow with it, instead of wearing a dark band it should never have.
///
/// It never touches what it wraps, so it composes with any lens.
///
/// ## The shape
///
/// The shadow is cast by a **ring**, not by the pill itself: an outer
/// capsule pushed out by 1 px horizontally and [blur]/2 vertically, minus
/// an inner capsule pulled in by [blur]/2 vertically. Only a band
/// straddling the rim casts anything, so the middle of the glass stays
/// clear.
///
/// That ring is then displaced **downward** by [offset] (`blur + 2` by
/// default) and blurred. The upper arc lands just inside the top rim; the
/// lower arc lands entirely below the pill. One ring gives both the inner
/// rim contact and the drop beneath.
///
/// It composites with [BlendMode.multiply], so it darkens whatever is
/// under it — the glass on the inside, the page on the outside — instead
/// of laying flat grey over both.
///
/// ## Under a deformed lens
///
/// A squashed or stretched lens keeps its authored corner radius and
/// stretches the whole outline (the shader's `u_shapeScale`), so its caps
/// go elliptical rather than re-rounding. Pass the same [scale] the lens
/// is drawn with and the ring follows that ellipse; leave it at `(1, 1)`
/// and the ring is a plain capsule.
class LiquidGlassShadow extends StatelessWidget {
  /// Blur radius of the shadow, and the vertical thickness of the ring
  /// that casts it.
  final double blur;

  /// Shadow opacity.
  final double opacity;

  /// Shadow color before [opacity].
  final Color color;

  /// Downward displacement of the ring. `null` uses `blur + 2`, which is
  /// what puts the upper arc inside the rim and the lower arc below the
  /// pill.
  final Offset? offset;

  /// The pill's **rest** corner radius. `null` makes it a capsule (half
  /// the shorter side of the undeformed box).
  final double? cornerRadius;

  /// The lens's outline stretch — deformed size ÷ rest size. Pass the
  /// lens's own value so the ring tracks an elliptical cap; `(1, 1)` for
  /// an undeformed lens.
  final Offset scale;

  /// How far inside the glass the shadow's own pill sits, in logical
  /// pixels on every side.
  ///
  /// `0` (the default) casts from a pill the same size as the lens, so
  /// the blurred halo reaches a little past its rim. Raise it to tuck the
  /// shadow in — the glass then overhangs its own shadow, which reads as
  /// a thinner, tighter contact on a small control where a full-size
  /// halo looks like a glow.
  final double inset;

  /// Whether the shadow is drawn at all. `false` paints nothing and
  /// leaves [child] untouched, so it can be toggled without changing the
  /// widget tree's shape.
  final bool visible;

  /// The glass this shadow belongs to. Sized by the parent; the shadow
  /// takes whatever box the child gets.
  final Widget? child;

  const LiquidGlassShadow({
    super.key,
    this.blur = 3.5,
    this.opacity = 0.2,
    this.color = Colors.black,
    this.offset,
    this.cornerRadius,
    this.scale = const Offset(1, 1),
    this.inset = 0,
    this.visible = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = child ?? const SizedBox.expand();
    if (!visible || opacity <= 0) return content;
    return CustomPaint(
      // Background, so it paints BEFORE the child: the glass sits over
      // its own shadow, and a solid rest pill covering the glass covers
      // the shadow with it.
      painter: _RingShadowPainter(
        blur: blur,
        opacity: opacity,
        color: color,
        offset: offset ?? Offset(0, blur + 2),
        cornerRadius: cornerRadius,
        scale: scale,
        inset: inset,
      ),
      child: content,
    );
  }
}

class _RingShadowPainter extends CustomPainter {
  final double blur;
  final double opacity;
  final Color color;
  final Offset offset;
  final double? cornerRadius;
  final Offset scale;
  final double inset;

  const _RingShadowPainter({
    required this.blur,
    required this.opacity,
    required this.color,
    required this.offset,
    required this.cornerRadius,
    required this.scale,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0 || blur <= 0) return;

    // The pill that casts, which may sit inside the glass's own box.
    final double pad = math.max(
        0.0, math.min(inset, math.min(size.width, size.height) / 2 - 1));
    final Rect box =
        Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    if (box.isEmpty) return;

    // The corner is authored against the REST box and stretched with the
    // outline, matching how the lens draws it — so a squashed pill's ring
    // rides its elliptical cap instead of drifting off the rim.
    final double sx = scale.dx <= 0 ? 1.0 : scale.dx;
    final double sy = scale.dy <= 0 ? 1.0 : scale.dy;
    final double restW = box.width / sx;
    final double restH = box.height / sy;
    final double maxR = math.min(restW, restH) / 2;
    // Clamped like the outline itself: an authored radius larger than the
    // short side would round past the capsule and lift the ring off it.
    // Clamping against the INSET box is also what keeps a tucked-in
    // shadow a clean capsule rather than a rounded rectangle.
    final double r = math.min(cornerRadius ?? maxR, maxR);
    final Radius radius = Radius.elliptical(r * sx, r * sy);

    // Outer capsule pushed out, inner one pulled in; even-odd leaves the
    // band that straddles the rim. Floored so a pill shorter than the
    // blur cannot invert the inner rect.
    final double band = math.min(blur / 2, box.height / 2 - 0.5);
    final RRect outer = RRect.fromRectAndRadius(
      Rect.fromLTRB(
          box.left - 1, box.top - blur / 2, box.right + 1, box.bottom + blur / 2),
      radius,
    );
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(box.left, box.top + band, box.right, box.bottom - band),
      radius,
    );
    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);

    canvas.drawPath(
      ring.shift(offset),
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
        ..blendMode = BlendMode.multiply,
    );
  }

  @override
  bool shouldRepaint(_RingShadowPainter old) =>
      blur != old.blur ||
      opacity != old.opacity ||
      color != old.color ||
      offset != old.offset ||
      cornerRadius != old.cornerRadius ||
      scale != old.scale ||
      inset != old.inset;
}
