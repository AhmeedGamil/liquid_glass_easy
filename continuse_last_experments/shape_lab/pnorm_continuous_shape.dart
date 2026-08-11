// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — a continuous-curvature rounded rectangle and capsule built
// out of nothing but a p-norm corner.
//
// The plain corner is
//
//     (|u| / r)^n + (|v| / r)^n = 1
//
// laid in a corner box r × r. Two things are added on top:
//
//   1. REACH. The corner box is stretched along whichever edge has room, to
//      r * (1 + 0.2893 * t), where t is that edge's slack, `clamp((half - r)
//      / r, 0, 1)`. A plain corner leaves the edge at exactly r, far too
//      abruptly to read as continuous.
//   2. PER-AXIS EXPONENT. The exponent on each axis rises with that axis'
//      slack, 2 + 0.7198 * t. Which matters for capsules: an end cap has no
//      vertical slack, so its exponent stays at 2 (a circular end) while the
//      long edges keep the full smoothing.
//
// Both constants are fitted against continuous_sdf/continuous_corner_path.dart
// — the G2 Bézier reference. Worst deviation across squares, rects, capsules
// and pills: 0.41% of the corner radius. For scale, the same measurement gives
// 1.65% for the best plain corner (which turns out to be a circle, n = 2) and
// 25% for a fixed "squircle" exponent of 4.
//
// At t = 0 the model collapses to reach r and exponent 2 — a circle — which is
// exactly what the reference does when a shape is rounded as far as it goes.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

/// How far past the radius a corner reaches along an edge that has the room,
/// as a fraction of the radius.
const double kPnormReach = 0.2893;

/// How much the p-norm exponent climbs above 2 on an edge that has the room.
const double kPnormExponentRise = 0.7198;

double _pow(double base, double exponent) => math.pow(base, exponent).toDouble();

/// One corner axis, resolved: how far the curve runs along its edge and how
/// hard it leaves it.
class PnormAxis {
  const PnormAxis(this.reach, this.exponent);

  /// Distance from the corner to where the curve meets the edge, in points.
  final double reach;

  /// The p-norm exponent this axis contributes.
  final double exponent;
}

/// Resolves both axes of the shape's corners for a [size]-sized box with
/// corner radius [radius].
///
/// [slack] is what limits each axis: a square with a small radius has all the
/// room in the world (t = 1 both ways), a capsule has none across its short
/// side (t = 0), and the axis degrades to a plain circular end there.
({PnormAxis h, PnormAxis v, double radius})
    resolvePnormContinuous(
  Size size,
  double radius, {
  double reach = kPnormReach,
  double baseExponent = 2,
  double exponentRise = kPnormExponentRise,
}) {
  final halfW = size.width / 2;
  final halfH = size.height / 2;
  final double r = radius.clamp(0.0, math.min(halfW, halfH));
  if (r <= 0) {
    return (
      h: PnormAxis(0, baseExponent),
      v: PnormAxis(0, baseExponent),
      radius: 0.0
    );
  }
  final tH = ((halfW - r) / r).clamp(0.0, 1.0);
  final tV = ((halfH - r) / r).clamp(0.0, 1.0);
  return (
    h: PnormAxis(
        r * (1 + reach * tH), baseExponent + exponentRise * tH),
    v: PnormAxis(
        r * (1 + reach * tV), baseExponent + exponentRise * tV),
    radius: r,
  );
}

/// Signed distance to the continuous rounded rectangle filling [rect].
///
/// Zero on the surface, negative inside. A raw p-norm value is not a distance,
/// so this divides by the gradient — first-order exact, which is what a
/// refraction band needs.
double pnormContinuousSdf(
  Offset point,
  Rect rect,
  double radius, {
  double reach = kPnormReach,
  double baseExponent = 2,
  double exponentRise = kPnormExponentRise,
}) {
  final halfW = rect.width / 2;
  final halfH = rect.height / 2;
  final axes = resolvePnormContinuous(rect.size, radius,
      reach: reach, baseExponent: baseExponent, exponentRise: exponentRise);

  final local = point - rect.center;
  final ax = local.dx.abs();
  final ay = local.dy.abs();
  final edgeX = ax - halfW;
  final edgeY = ay - halfH;

  if (axes.radius > 0) {
    // Offsets into the corner box, positive once inside it.
    final u = ax - (halfW - axes.h.reach);
    final v = ay - (halfH - axes.v.reach);
    if (u > 0 && v > 0) {
      final nH = axes.h.exponent;
      final nV = axes.v.exponent;
      final su = u / axes.h.reach;
      final sv = v / axes.v.reach;
      final value = _pow(su, nH) + _pow(sv, nV);
      final gradU = nH * _pow(su, nH - 1) / axes.h.reach;
      final gradV = nV * _pow(sv, nV - 1) / axes.v.reach;
      final gradient = math.sqrt(gradU * gradU + gradV * gradV);
      if (gradient < 1e-12) return -math.min(axes.h.reach, axes.v.reach);
      return (value - 1) / gradient;
    }
  }

  // Straight edges and the interior: the shader's own box formula.
  return math.min(math.max(edgeX, edgeY), 0.0) +
      Offset(math.max(edgeX, 0.0), math.max(edgeY, 0.0)).distance;
}

/// The same shape as a [Path], for clipping and stroking.
///
/// The corner is walked with the p-norm's own parametrization — u = reach ·
/// cos^(2/nH)(φ), v = reach · sin^(2/nV)(φ) — so the path and
/// [pnormContinuousSdf]'s zero level are the same curve by construction.
/// [segmentsPerCorner] trades smoothness for point count.
Path pnormContinuousPath(
  Size size,
  double radius, {
  double reach = kPnormReach,
  double baseExponent = 2,
  double exponentRise = kPnormExponentRise,
  int segmentsPerCorner = 32,
}) {
  final path = Path();
  final axes = resolvePnormContinuous(size, radius,
      reach: reach, baseExponent: baseExponent, exponentRise: exponentRise);
  if (axes.radius <= 0) {
    path.addRect(Offset.zero & size);
    return path;
  }

  final halfW = size.width / 2;
  final halfH = size.height / 2;
  final centre = Offset(halfW, halfH);
  final flatX = halfW - axes.h.reach;
  final flatY = halfH - axes.v.reach;
  final expU = 2 / axes.h.exponent;
  final expV = 2 / axes.v.exponent;

  Offset corner(double signX, double signY, double phi) {
    final u = axes.h.reach * _pow(math.cos(phi), expU);
    final v = axes.v.reach * _pow(math.sin(phi), expV);
    return centre + Offset(signX * (flatX + u), signY * (flatY + v));
  }

  // Clockwise from the top edge: top-right, bottom-right, bottom-left,
  // top-left. Straight edges fall out of the joins.
  var started = false;
  void arc(double signX, double signY, bool fromEdgeToSide) {
    for (var i = 0; i <= segmentsPerCorner; i++) {
      final t = i / segmentsPerCorner;
      final phi = (fromEdgeToSide ? 1 - t : t) * math.pi / 2;
      final p = corner(signX, signY, phi);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
  }

  arc(1, -1, true);
  arc(1, 1, false);
  arc(-1, 1, true);
  arc(-1, -1, false);
  path.close();
  return path;
}

/// The capsule case: rounded as far as the short side allows.
Path pnormContinuousCapsulePath(
  Size size, {
  double reach = kPnormReach,
  double baseExponent = 2,
  double exponentRise = kPnormExponentRise,
  int segmentsPerCorner = 32,
}) =>
    pnormContinuousPath(
      size,
      math.min(size.width, size.height) / 2,
      reach: reach,
      baseExponent: baseExponent,
      exponentRise: exponentRise,
      segmentsPerCorner: segmentsPerCorner,
    );
