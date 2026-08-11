import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../continuous_sdf/continuous_corner_path.dart';
import 'pnorm_continuous_shape.dart';

/// Worst distance from a sampled outline to [candidate]'s surface.
double _worstGap(List<Offset> outline, double Function(Offset) candidate) {
  var worst = 0.0;
  for (final p in outline) {
    final d = candidate(p).abs();
    if (d > worst) worst = d;
  }
  return worst;
}

List<Offset> _sample(Path path, {int steps = 1200}) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    for (var i = 0; i <= steps; i++) {
      final t = metric.getTangentForOffset(metric.length * i / steps);
      if (t != null) points.add(t.position);
    }
  }
  return points;
}

const _cases = <(String, Size, double)>[
  ('square, all the room', Size(400, 400), 100),
  ('half the room', Size(300, 300), 100),
  ('no room — a circle', Size(200, 200), 100),
  ('capsule', Size(400, 120), 60),
  ('pill', Size(300, 100), 50),
  ('subtle radius', Size(360, 200), 24),
  ('tall', Size(160, 400), 70),
];

void main() {
  test('the path is the SDF zero level', () {
    for (final (name, size, radius) in _cases) {
      final rect = Offset.zero & size;
      final onPath = _sample(pnormContinuousPath(size, radius, segmentsPerCorner: 96));
      final worst = _worstGap(onPath, (p) => pnormContinuousSdf(p, rect, radius));
      // The path is a polyline through the curve, so it cuts the corner by the
      // sagitta of one segment — tiny, but not zero.
      expect(worst, lessThan(0.02), reason: name);
    }
  });

  test('within 0.41% of the continuous reference', () {
    for (final (name, size, radius) in _cases) {
      final rect = Offset.zero & size;
      final reference = _sample(continuousRoundedRectanglePath(size, radius));
      final gap = _worstGap(reference, (p) => pnormContinuousSdf(p, rect, radius));
      expect(gap / radius, lessThan(0.0042), reason: name);
    }
  });

  test('the stock shader corner is nowhere near it', () {
    const size = Size(360, 200);
    const radius = 24.0;
    const rect = Rect.fromLTWH(0, 0, 360, 200);
    final reference = _sample(continuousRoundedRectanglePath(size, radius));

    // n = 4, the "squircle" the Swift side documents.
    final squircle = _worstGap(
      reference,
      (p) => pnormContinuousSdf(p, rect, radius,
          reach: 0, baseExponent: 4, exponentRise: 0),
    );
    expect(squircle / radius, greaterThan(0.2));

    // The best a plain p-norm corner can do is n = 2, a plain circle.
    var best = double.infinity;
    var bestN = 0.0;
    for (var i = 0; i <= 300; i++) {
      final n = 2 + i * 0.01;
      final gap = _worstGap(
        reference,
        (p) => pnormContinuousSdf(p, rect, radius,
            reach: 0, baseExponent: n, exponentRise: 0),
      );
      if (gap < best) {
        best = gap;
        bestN = n;
      }
    }
    expect(bestN, closeTo(2, 0.05));
    expect(best / radius, greaterThan(0.015));
  });

  test('a corner never reaches past its own half-extent', () {
    for (var w = 40.0; w <= 400; w += 20) {
      for (var h = 40.0; h <= 400; h += 20) {
        final size = Size(w, h);
        for (var f = 0.05; f <= 1.0; f += 0.05) {
          final radius = math.min(w, h) / 2 * f;
          final axes = resolvePnormContinuous(size, radius);
          expect(axes.h.reach, lessThanOrEqualTo(w / 2 + 1e-9));
          expect(axes.v.reach, lessThanOrEqualTo(h / 2 + 1e-9));
        }
      }
    }
  });

  test('a capsule keeps a circular end and a smoothed flank', () {
    const size = Size(400, 120);
    final axes = resolvePnormContinuous(size, 60);
    // No vertical room: the end cap stays a circle.
    expect(axes.v.reach, closeTo(60, 1e-9));
    expect(axes.v.exponent, closeTo(2, 1e-9));
    // Plenty of horizontal room: full reach and exponent along the flank.
    expect(axes.h.reach, closeTo(60 * (1 + kPnormReach), 1e-9));
    expect(axes.h.exponent, closeTo(2 + kPnormExponentRise, 1e-9));

    // And the shape still fills its box.
    final bounds = pnormContinuousCapsulePath(size).getBounds();
    expect(bounds.left, closeTo(0, 0.01));
    expect(bounds.top, closeTo(0, 0.01));
    expect(bounds.right, closeTo(400, 0.01));
    expect(bounds.bottom, closeTo(120, 0.01));
  });

  test('degenerate radius falls back to the rectangle', () {
    const size = Size(200, 100);
    const rect = Rect.fromLTWH(0, 0, 200, 100);
    expect(pnormContinuousPath(size, 0).getBounds(), rect);
    expect(pnormContinuousSdf(const Offset(100, 50), rect, 0), closeTo(-50, 1e-9));
    expect(pnormContinuousSdf(const Offset(100, 0), rect, 0), closeTo(0, 1e-9));
    // Over-large radii clamp instead of inverting the corner.
    expect(pnormContinuousPath(size, 500).getBounds().width, closeTo(200, 0.01));
  });

  test('sdf sign and magnitude', () {
    const rect = Rect.fromLTWH(0, 0, 300, 200);
    expect(pnormContinuousSdf(rect.center, rect, 60), closeTo(-100, 1e-9));
    expect(pnormContinuousSdf(const Offset(150, 0), rect, 60), closeTo(0, 1e-9));
    expect(pnormContinuousSdf(const Offset(150, -20), rect, 60), closeTo(20, 1e-9));
    // A point off the true corner is outside; one on the flat edge is not.
    expect(pnormContinuousSdf(Offset.zero, rect, 60), greaterThan(0));
    expect(pnormContinuousSdf(const Offset(150, 100), rect, 60), lessThan(0));
  });
}
