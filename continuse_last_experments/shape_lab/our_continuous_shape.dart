// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — the package's own continuous rounded rectangle on the CPU.
// `continuousRoundedRectShape()` from lib/assets/shaders/liquid_glass_common.glsl,
// evaluated in Dart so it can be drawn and measured beside the alternatives.
//
// A different model from the p-norm corner: each corner is an exact circle of
// radius rr across its 45° belly, and a tuned shoulder peels the curve off
// each flat edge early (extFrac · rr sooner) with zero tangent and curvature
// at the contact. The two halves are crossfaded across the diagonal seam.
//
// The seam-width floor is one PHYSICAL pixel in the shader, so a caller
// working in logical points should pass `seamFloor: 1 / devicePixelRatio` to
// reproduce what a device actually draws.
//
// shape_compare_page.dart has the same equation inline and private; this one
// exists so the compare page can draw it without reaching into that file.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

/// The five tunable constants of the continuous-corner equation.
class OurCrrParams {
  const OurCrrParams({
    required this.extFrac,
    required this.t0,
    required this.aTail,
    required this.nTail,
    required this.seamFraction,
  });

  /// How much earlier than rr the curve peels off the edge, as a fraction.
  final double extFrac;

  /// Where the exact-circle belly ends and the shoulder starts.
  final double t0;

  /// Shoulder ramp shape.
  final double aTail;
  final double nTail;

  /// Seam half-width across the 45° diagonal, as a fraction of rr.
  final double seamFraction;
}

/// Exactly what ships in liquid_glass_common.glsl.
const OurCrrParams kShippedCrr = OurCrrParams(
  extFrac: 0.4425,
  t0: 0.728,
  aTail: 4.836,
  nTail: 3.869,
  seamFraction: 0.15,
);

/// The candidate set from shape_compare_page.dart — not in the shader.
const OurCrrParams kFittedCrr = OurCrrParams(
  extFrac: 0.99997431,
  t0: 0.00000000,
  aTail: 19.93250275,
  nTail: 9.33909130,
  seamFraction: 0.10970203,
);

/// The shoulder: 1.0 across the belly, easing to 0 at the edge contact.
double ourCrrShoulder(double tt, OurCrrParams params) {
  if (tt <= params.t0) return 1;
  final u = ((tt - params.t0) / (1 - params.t0)).clamp(0.0, 1.0);
  final inner = math.max(1 - math.pow(u, params.aTail).toDouble(), 0.0);
  return math.pow(inner, 1 / params.nTail).toDouble();
}

/// Per-edge shoulder reach, clamped to the room each edge actually has.
Offset ourCrrReach(double rr, Size halfSize, OurCrrParams params) => Offset(
      math.max(math.min(params.extFrac * rr, halfSize.width - rr), 0.0),
      math.max(math.min(params.extFrac * rr, halfSize.height - rr), 0.0),
    );

/// The SDF itself.
double ourContinuousSdf(
  Offset point,
  Rect rect,
  double radius, {
  OurCrrParams params = kShippedCrr,
  double seamFloor = 1.0,
}) {
  final halfW = rect.width / 2;
  final halfH = rect.height / 2;
  final double rr = radius.clamp(0.0, math.min(halfW, halfH));
  final local = point - rect.center;
  final qx = local.dx.abs() - halfW + rr;
  final qy = local.dy.abs() - halfH + rr;
  if (rr <= 0) return math.max(qx, qy);

  final reach = ourCrrReach(rr, Size(halfW, halfH), params);
  final gV = reach.dy * (ourCrrShoulder((qx / rr).clamp(0.0, 1.0), params) - 1);
  final gH = reach.dx * (ourCrrShoulder((qy / rr).clamp(0.0, 1.0), params) - 1);

  final fLower =
      Offset(math.max(qx, 0.0), math.max(qy - gV, 0.0)).distance - rr;
  final fUpper =
      Offset(math.max(qx - gH, 0.0), math.max(qy, 0.0)).distance - rr;

  final seamW = math.max(rr * params.seamFraction, seamFloor);
  final blend = _smoothstep(-seamW, seamW, qx - qy);
  final corner = fUpper + (fLower - fUpper) * blend;
  return math.min(math.max(qx, qy), 0.0) + corner;
}

double _smoothstep(double edge0, double edge1, double v) {
  final t = ((v - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The outline as a [Path].
///
/// There is no closed form for this corner, so the zero level is found by
/// bisecting rays out of the centre. The shape is symmetric about both axes,
/// so only one quadrant is marched and the rest is mirrored.
Path ourContinuousPath(
  Size size,
  double radius, {
  OurCrrParams params = kShippedCrr,
  double seamFloor = 1.0,
  int samplesPerQuadrant = 180,
}) {
  final rect = Offset.zero & size;
  final centre = rect.center;
  final far = math.max(size.width, size.height);

  final distances = List<double>.filled(samplesPerQuadrant + 1, 0);
  final cosines = List<double>.filled(samplesPerQuadrant + 1, 0);
  final sines = List<double>.filled(samplesPerQuadrant + 1, 0);
  for (var i = 0; i <= samplesPerQuadrant; i++) {
    final angle = math.pi / 2 * i / samplesPerQuadrant;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    cosines[i] = dx;
    sines[i] = dy;
    var inside = 0.0;
    var outside = far;
    for (var step = 0; step < 24; step++) {
      final mid = (inside + outside) * 0.5;
      final d = ourContinuousSdf(
        centre + Offset(dx * mid, dy * mid),
        rect,
        radius,
        params: params,
        seamFloor: seamFloor,
      );
      if (d <= 0) {
        inside = mid;
      } else {
        outside = mid;
      }
    }
    distances[i] = (inside + outside) * 0.5;
  }

  Offset at(int i, double signX, double signY) => centre +
      Offset(signX * cosines[i] * distances[i], signY * sines[i] * distances[i]);

  final path = Path();
  final first = at(0, 1, 1);
  path.moveTo(first.dx, first.dy);
  void line(Offset p) => path.lineTo(p.dx, p.dy);
  for (var i = 1; i <= samplesPerQuadrant; i++) {
    line(at(i, 1, 1));
  }
  for (var i = samplesPerQuadrant - 1; i >= 0; i--) {
    line(at(i, -1, 1));
  }
  for (var i = 1; i <= samplesPerQuadrant; i++) {
    line(at(i, -1, -1));
  }
  for (var i = samplesPerQuadrant - 1; i > 0; i--) {
    line(at(i, 1, -1));
  }
  return path..close();
}
