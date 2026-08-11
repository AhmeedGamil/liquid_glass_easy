import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'shape_sdf.dart';

void main() {
  test('circle', () {
    expect(circleSdf(const Offset(10, 0), 10), closeTo(0, 1e-9));
    expect(circleSdf(Offset.zero, 10), closeTo(-10, 1e-9));
    expect(circleSdf(const Offset(0, 25), 10), closeTo(15, 1e-9));
  });

  test('hoisted quadrant table matches the inline loop exactly', () {
    for (final n in [1.0, 2.0, 4.0, 7.5, 12.0]) {
      final table = superellipseQuadrantTable(n);
      for (var i = 0; i < 40; i++) {
        final p = Offset(-70 + i * 3.5, 40 - i * 2.1);
        final inline = superellipseSdf(p, 50, n).distance;
        final hoisted = superellipseSdf(p, 50, n, quadrant: table).distance;
        expect(hoisted, inline, reason: 'n=$n p=$p');
      }
    }
  });

  test('superellipse zero level and sign', () {
    // n = 2 is a circle of radius `scale`.
    expect(superellipseSdf(const Offset(50, 0), 50, 2).distance, closeTo(0, 0.6));
    expect(superellipseSdf(const Offset(0, -50), 50, 2).distance, closeTo(0, 0.6));
    expect(superellipseSdf(Offset.zero, 50, 2).distance, lessThan(-48));
    expect(superellipseSdf(const Offset(80, 80), 50, 2).distance, greaterThan(0));
    // n = 1 is a diamond: (scale, 0) on the surface, (scale, scale) well out.
    expect(superellipseSdf(const Offset(50, 0), 50, 1).distance, closeTo(0, 0.6));
    expect(superellipseSdf(const Offset(30, 30), 50, 1).distance, greaterThan(0));
    // Rising n pushes the 45° corner outward: diamond < circle < squircle.
    double diag(double n) =>
        superellipseSdf(const Offset(35, 35), 50, n).distance;
    expect(diag(1), greaterThan(diag(2)));
    expect(diag(2), greaterThan(diag(4)));
  });

  test('fast path shares the zero level with the marched distance', () {
    for (final n in [1.0, 2.0, 4.0, 8.0]) {
      for (final angle in [0.0, 0.3, math.pi / 4, 1.1, math.pi]) {
        final dir = Offset(math.cos(angle), math.sin(angle));
        double crossing(double Function(Offset) f) {
          var inside = 0.0, outside = 200.0;
          for (var i = 0; i < 40; i++) {
            final mid = (inside + outside) / 2;
            if (f(dir * mid) <= 0) {
              inside = mid;
            } else {
              outside = mid;
            }
          }
          return (inside + outside) / 2;
        }

        final marched =
            crossing((p) => superellipseSdf(p, 50, n).distance);
        final approx = crossing((p) => superellipseApproxSdf(p, 50, n));
        expect(marched, closeTo(approx, 0.7), reason: 'n=$n angle=$angle');
      }
    }
  });

  test('superellipse corner is a p-norm ball', () {
    expect(superellipseCornerSdf(const Offset(20, 0), 20, 2), closeTo(0, 1e-9));
    expect(superellipseCornerSdf(const Offset(0, -20), 20, 4), closeTo(0, 1e-9));
    // At 45°, n = 1 lands short of the ball, n = 4 past it.
    final d = 20 / math.sqrt2;
    expect(superellipseCornerSdf(Offset(d, d), 20, 1), greaterThan(0));
    expect(superellipseCornerSdf(Offset(d, d), 20, 4), lessThan(0));
  });

  test('rounded rectangle', () {
    final rect = const Rect.fromLTWH(20, 30, 200, 100);
    // Centre is half the short side deep.
    expect(roundedRectangleSdf(rect.center, rect, 24, 2), closeTo(-50, 1e-9));
    // Edge midpoints sit on the surface.
    expect(roundedRectangleSdf(Offset(rect.center.dx, rect.top), rect, 24, 2),
        closeTo(0, 1e-9));
    expect(roundedRectangleSdf(Offset(rect.right, rect.center.dy), rect, 24, 2),
        closeTo(0, 1e-9));
    // The bare corner is cut away by the rounding; the arc point is on it.
    expect(roundedRectangleSdf(rect.topLeft, rect, 24, 2),
        closeTo(24 * (math.sqrt2 - 1), 1e-9));
    final arc = rect.topLeft + Offset(24 - 24 / math.sqrt2, 24 - 24 / math.sqrt2);
    expect(roundedRectangleSdf(arc, rect, 24, 2), closeTo(0, 1e-9));
    // A squircle keeps more of the corner than a circle does.
    expect(roundedRectangleSdf(arc, rect, 24, 4), lessThan(0));
    // contentsScale just scales the whole thing.
    expect(
      roundedRectangleSdf(rect.center * 2, rect, 24, 2, contentsScale: 2),
      closeTo(-100, 1e-9),
    );
  });

  test('smooth union relaxes to min as smoothness vanishes', () {
    expect(smoothUnion(3, 8, 1e-6), closeTo(3, 1e-3));
    expect(smoothUnion(8, 3, 1e-6), closeTo(3, 1e-3));
    // Blending only ever pulls the surface outward (more negative).
    expect(smoothUnion(0, 0, 0.5), closeTo(-0.125, 1e-9));
    expect(smoothUnion(2, 2, 0.5), lessThan(2));
  });

  test('primaryShapeSDF merges the rects it is given', () {
    List<Rect> pair(double gap) => [
          Rect.fromCenter(
              center: Offset(150 - gap / 2 - 25, 75), width: 50, height: 50),
          Rect.fromCenter(
              center: Offset(150 + gap / 2 + 25, 75), width: 50, height: 50),
        ];
    double at(double gap, double smoothness) => primaryShapeSdf(
          const Offset(150, 75),
          pair(gap),
          cornerRadius: 12,
          cornerRoundnessExponent: 2,
          shapeMergeSmoothness: smoothness,
          resolutionY: 150,
        );

    // The gap's midpoint: closed while the shapes merge, open once far apart.
    expect(at(10, 0.2), lessThan(0));
    expect(at(120, 0.2), greaterThan(0));
    // More smoothness bridges a wider gap.
    expect(at(60, 0.4), lessThan(at(60, 0.05)));
    // A single rect comes back untouched, just normalized by resolution.y.
    final one = [const Rect.fromLTWH(50, 25, 200, 100)];
    expect(
      primaryShapeSdf(const Offset(150, 75), one,
              cornerRadius: 20,
              cornerRoundnessExponent: 2,
              shapeMergeSmoothness: 0.2,
              resolutionY: 150) *
          150,
      closeTo(-50, 1e-9),
    );
  });

  test('hsv debug colours', () {
    final red = hsvToRgb(0, 1, 1);
    expect(red.r, closeTo(1, 1e-6));
    expect(red.g, closeTo(0, 1e-6));
    expect(red.b, closeTo(0, 1e-6));
    final green = hsvToRgb(1 / 3, 1, 1);
    expect(green.g, closeTo(1, 1e-6));
    expect(green.r, closeTo(0, 1e-6));
    final right = vectorToRainbowColor(const Offset(1, 0));
    expect(right.r, closeTo(1, 1e-6));
    expect(vectorToAngle(const Offset(0, -1)), closeTo(3 * math.pi / 2, 1e-9));
  });
}
