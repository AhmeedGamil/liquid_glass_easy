import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
/// ## Keeping it out of the glass
///
/// [insideGlass] decides whether the part of the ring that falls under
/// the outline is drawn at all. `true` (the default) is the contact look
/// above: the upper arc darkens the inside of the rim. `false` clips the
/// ring to the **outside** of the outline and paints it *over* the glass
/// instead of behind it — visually the same drop beneath, but a lens's
/// backdrop sample never contains it, so a refracting rim cannot pull it
/// into the interior as a dark inner band.
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

  /// Whether the shadow is drawn under the glass outline.
  ///
  /// `true` (the default) paints the whole ring behind the glass, so its
  /// upper arc darkens the inside of the rim as contact. `false` keeps
  /// only what falls **outside** the outline and paints it over the glass,
  /// so the lens's backdrop sample never carries the shadow and the
  /// refraction band has nothing dark to pull inward. The outline is a
  /// rounded rectangle at the lens's corner radius, so a continuous corner
  /// is matched to within its own curvature difference.
  final bool insideGlass;

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
    this.insideGlass = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = child ?? const SizedBox.expand();
    if (!visible || opacity <= 0) return content;
    final _RingShadowPainter painter = _RingShadowPainter(
      blur: blur,
      opacity: opacity,
      color: color,
      offset: offset ?? Offset(0, blur + 2),
      cornerRadius: cornerRadius,
      scale: scale,
      inset: inset,
      exteriorOnly: !insideGlass,
    );
    return CustomPaint(
      // Background, so it paints BEFORE the child: the glass sits over
      // its own shadow, and a solid rest pill covering the glass covers
      // the shadow with it.
      painter: insideGlass ? painter : null,
      // Exterior-only: painted AFTER the child, so a backdrop-sampling
      // lens has already read its backdrop before the shadow exists. It
      // is clipped to the outside of the outline, so it never covers the
      // glass it is painted over.
      foregroundPainter: insideGlass ? null : painter,
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
  final bool exteriorOnly;

  const _RingShadowPainter({
    required this.blur,
    required this.opacity,
    required this.color,
    required this.offset,
    required this.cornerRadius,
    required this.scale,
    required this.inset,
    required this.exteriorOnly,
  });

  /// Desktops draw the ring from two blurred rounded rects instead of one
  /// blurred path. A blurred path is rasterised on the pixel grid, so a
  /// moving ring steps a whole pixel at a time: invisible at a phone's pixel
  /// ratio, a visible jerk at a desktop's 1. A lone rounded rect is blurred
  /// at its exact sub-pixel position, so the ring slides.
  static bool get _fromRRects =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

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
      Rect.fromLTRB(box.left - 1, box.top - blur / 2, box.right + 1,
          box.bottom + blur / 2),
      radius,
    );
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(box.left, box.top + band, box.right, box.bottom - band),
      radius,
    );
    Path? cut;
    if (exteriorOnly) {
      // The glass outline itself — the FULL box, not the inset casting
      // pill — with the same clamped, stretched corner. Everything the
      // blurred ring lands under it is cut away.
      final Rect full = Offset.zero & size;
      final double fullR = math.min(
          cornerRadius ?? math.min(full.width / sx, full.height / sy) / 2,
          math.min(full.width / sx, full.height / sy) / 2);
      final RRect outline = RRect.fromRectAndRadius(
          full, Radius.elliptical(fullR * sx, fullR * sy));
      final double reach = blur * 3 + offset.distance + 2;
      cut = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(full.inflate(reach))
        ..addRRect(outline);
      canvas.clipPath(cut);
    }

    if (_fromRRects) {
      _paintFromRRects(canvas, outer.shift(offset), inner.shift(offset), cut);
      return;
    }

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

  /// The ring as the blurred [outer] capsule minus the blurred [inner] one
  /// (the inner sits wholly inside the outer, and a blur is linear). The two
  /// land in the red and green channels of an opaque layer, and the layer's
  /// colour filter turns red minus green into the shadow's alpha: the same
  /// coverage the even-odd path gives.
  void _paintFromRRects(Canvas canvas, RRect outer, RRect inner, Path? cut) {
    final Rect layer = outer.outerRect.inflate(blur * 3 + 1);
    canvas.saveLayer(
      layer,
      Paint()
        ..blendMode = BlendMode.multiply
        ..colorFilter = ColorFilter.matrix(<double>[
          0, 0, 0, 0, color.r * 255, //
          0, 0, 0, 0, color.g * 255, //
          0, 0, 0, 0, color.b * 255, //
          opacity, -opacity, 0, 0, 0,
        ]),
    );
    // Clipped again inside the layer: Impeller does not carry the clip
    // above into the layer's own draws.
    if (cut != null) canvas.clipPath(cut);
    canvas.drawRect(layer, Paint()..color = const Color(0xFF000000));
    final MaskFilter soft = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(
      outer,
      Paint()
        ..color = const Color(0xFFFF0000)
        ..maskFilter = soft
        ..blendMode = BlendMode.plus,
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..color = const Color(0xFF00FF00)
        ..maskFilter = soft
        ..blendMode = BlendMode.plus,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingShadowPainter old) =>
      blur != old.blur ||
      opacity != old.opacity ||
      color != old.color ||
      offset != old.offset ||
      cornerRadius != old.cornerRadius ||
      scale != old.scale ||
      inset != old.inset ||
      exteriorOnly != old.exteriorOnly;
}
