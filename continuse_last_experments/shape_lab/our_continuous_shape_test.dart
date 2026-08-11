import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../continuous_sdf/continuous_corner_path.dart';
import 'pnorm_continuous_shape.dart';
import 'our_continuous_shape.dart';

// ── the shipped equation, written out here as an independent check ───────
double _shoulder(double tt) {
  const t0 = 0.728, aTail = 4.836, nTail = 3.869;
  if (tt <= t0) return 1;
  final u = ((tt - t0) / (1 - t0)).clamp(0.0, 1.0);
  final inner = math.max(1 - math.pow(u, aTail).toDouble(), 0.0);
  return math.pow(inner, 1 / nTail).toDouble();
}

double _smoothstep(double e0, double e1, double v) {
  final t = ((v - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _theirs(double x, double y, Size size, double r, double seamFloor) {
  const extFrac = 0.4425, seamFraction = 0.15;
  final hw = size.width / 2;
  final hh = size.height / 2;
  final qx = (x - hw).abs() - hw + r;
  final qy = (y - hh).abs() - hh + r;
  if (r <= 0) return math.max(qx, qy);

  final reachH = math.max(math.min(extFrac * r, hw - r), 0.0);
  final reachV = math.max(math.min(extFrac * r, hh - r), 0.0);
  final gV = reachV * (_shoulder((qx / r).clamp(0.0, 1.0)) - 1);
  final gH = reachH * (_shoulder((qy / r).clamp(0.0, 1.0)) - 1);

  final lowerX = math.max(qx, 0.0);
  final lowerY = math.max(qy - gV, 0.0);
  final upperX = math.max(qx - gH, 0.0);
  final upperY = math.max(qy, 0.0);
  final fLower = math.sqrt(lowerX * lowerX + lowerY * lowerY) - r;
  final fUpper = math.sqrt(upperX * upperX + upperY * upperY) - r;

  final seamW = math.max(r * seamFraction, seamFloor);
  final blend = _smoothstep(-seamW, seamW, qx - qy);
  final corner = fUpper + (fLower - fUpper) * blend;
  return math.min(math.max(qx, qy), 0.0) + corner;
}

void main() {
  test('matches the shipped equation exactly', () {
    for (final size in const [Size(300, 200), Size(400, 120), Size(200, 200)]) {
      final rect = Offset.zero & size;
      for (final r in [0.0, 8.0, 24.0, 60.0]) {
        for (var y = -20.0; y < size.height + 20; y += 3.7) {
          for (var x = -20.0; x < size.width + 20; x += 3.7) {
            expect(
              ourContinuousSdf(Offset(x, y), rect, r, seamFloor: 1 / 2.75),
              _theirs(x, y, size, r, 1 / 2.75),
              reason: '$size r=$r at ($x, $y)',
            );
          }
        }
      }
    }
  });

  test('where each model is worst across a height sweep', () {
    var oursWorst = 0.0, oursAt = '';
    var metalWorst = 0.0, metalAt = '';
    for (var h = 60.0; h <= 400; h += 10) {
      const w = 300.0;
      final size = Size(w, h);
      const r = 60.0;
      if (r > math.min(w, h) / 2) continue;
      final rect = Offset.zero & size;
      final reference = <Offset>[];
      for (final metric in continuousRoundedRectanglePath(size, r).computeMetrics()) {
        for (var i = 0; i <= 1500; i++) {
          final t = metric.getTangentForOffset(metric.length * i / 1500);
          if (t != null) reference.add(t.position);
        }
      }
      var ours = 0.0, metal = 0.0;
      for (final p in reference) {
        final a = ourContinuousSdf(p, rect, r, seamFloor: 1 / 2.75).abs();
        final b = pnormContinuousSdf(p, rect, r).abs();
        if (a > ours) ours = a;
        if (b > metal) metal = b;
      }
      if (ours / r > oursWorst) {
        oursWorst = ours / r;
        oursAt = '300x${h.toStringAsFixed(0)}';
      }
      if (metal / r > metalWorst) {
        metalWorst = metal / r;
        metalAt = '300x${h.toStringAsFixed(0)}';
      }
    }
    // Ours tracks the reference closely when a corner has all the room it
    // wants, but its reach is hard-clamped to `min(extFrac*r, half - r)`
    // rather than ramped, so it drifts in the partial-room band. The metal
    // model ramps, so it holds its accuracy across the sweep.
    expect(oursWorst, greaterThan(0.01), reason: 'ours peaks at $oursAt');
    expect(oursWorst, lessThan(0.016));
    expect(metalWorst, lessThan(0.0042), reason: 'metal peaks at $metalAt');
  });

  test('the marched path is the SDF zero level', () {
    for (final (size, r) in const <(Size, double)>[
      (Size(300, 200), 60),
      (Size(400, 120), 60),
      (Size(360, 200), 24),
    ]) {
      final rect = Offset.zero & size;
      final path = ourContinuousPath(size, r, samplesPerQuadrant: 600);
      var worst = 0.0;
      for (final metric in path.computeMetrics()) {
        for (var i = 0; i <= 900; i++) {
          final t = metric.getTangentForOffset(metric.length * i / 900);
          if (t == null) continue;
          final d = ourContinuousSdf(t.position, rect, r).abs();
          if (d > worst) worst = d;
        }
      }
      expect(worst, lessThan(0.05), reason: '$size r=$r');
    }
  });

  test('sign, capsule and degenerate radius', () {
    const size = Size(300, 200);
    const rect = Rect.fromLTWH(0, 0, 300, 200);
    expect(ourContinuousSdf(rect.center, rect, 60), closeTo(-100, 1e-9));
    expect(ourContinuousSdf(const Offset(150, 0), rect, 60), closeTo(0, 1e-9));
    expect(ourContinuousSdf(Offset.zero, rect, 60), greaterThan(0));
    // No room on the short side: the shoulder there collapses to nothing.
    expect(ourCrrReach(60, const Size(200, 60), kShippedCrr).dy, 0);
    expect(ourCrrReach(60, const Size(200, 60), kShippedCrr).dx,
        closeTo(0.4425 * 60, 1e-9));
    // Radius 0 is a plain box; an over-large radius clamps.
    expect(ourContinuousSdf(const Offset(150, 100), rect, 0), closeTo(-100, 1e-9));
    expect(ourContinuousPath(size, 500).getBounds().width, closeTo(300, 0.1));
  });
}
