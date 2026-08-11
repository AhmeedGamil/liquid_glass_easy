// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — the SDF primitives a glass shape can be built from, on the
// CPU, so the geometry can be eyeballed on any device instead of only through
// a running shader.
//
// Everything works in logical points unless a caller passes `contentsScale`,
// and distances come back in whatever unit went in.
//
// Two notes on the superellipse:
//   • its 24 boundary samples depend only on the exponent, so a CPU can hoist
//     them out of the per-pixel loop — a GPU has to redo them per fragment.
//   • one zero-length-segment guard keeps extreme exponents from dividing by
//     zero.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

// ── small helpers the shading language gives for free ────────────────────

double _pow(double base, double exponent) => math.pow(base, exponent).toDouble();

/// A shading-language `sign()`: -1 / 0 / +1 (Dart's `.sign` keeps zero's sign).
double _sign(double v) => v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

// =========================================================================
// Signed Distance Field primitives
// SDFs return signed distance: >0 outside, <0 inside, 0 on the surface.
// =========================================================================

/// Circle: distance from the centre minus the radius.
double circleSdf(Offset point, double radius) => point.distance - radius;

/// What a superellipse evaluation returns: the distance, plus the analytic
/// gradient of the implicit function.
class SuperellipseSample {
  const SuperellipseSample(this.distance, this.gradient);

  final double distance;

  /// Analytic gradient of the implicit function — NaN at the exact centre.
  final Offset gradient;
}

/// The 24 boundary samples the superellipse walk visits, in the first octant.
///
/// They depend only on [exponent], never on the fragment, so a CPU port can
/// build the table once per shape instead of once per pixel.
List<Offset> superellipseQuadrantTable(double exponent, {int segmentCount = 24}) {
  final e = 2.0 / exponent;
  final table = <Offset>[const Offset(1, 0)];
  for (var i = 1; i < segmentCount; i++) {
    final t = i / (segmentCount - 1);
    table.add(Offset(
      _pow(math.cos(t * math.pi / 4), e),
      _pow(math.sin(t * math.pi / 4), e),
    ));
  }
  return table;
}

/// Generalized superellipse — true distance, found by walking the boundary as
/// 23 segments. Pass [quadrant] to reuse a hoisted table.
SuperellipseSample superellipseSdf(
  Offset point,
  double scale,
  double exponent, {
  List<Offset>? quadrant,
}) {
  point = point / scale;
  final signedPoint = Offset(_sign(point.dx), _sign(point.dy));
  final absPoint = Offset(point.dx.abs(), point.dy.abs());
  final sumPowers = _pow(absPoint.dx, exponent) + _pow(absPoint.dy, exponent);
  final fall = _pow(sumPowers, 1.0 / exponent - 1.0);
  final gradient = Offset(
    signedPoint.dx * _pow(absPoint.dx, exponent - 1.0) * fall,
    signedPoint.dy * _pow(absPoint.dy, exponent - 1.0) * fall,
  );

  // Abs and swap for quadrant handling.
  var p = absPoint;
  if (p.dy > p.dx) p = Offset(p.dy, p.dx);

  final table = quadrant ?? superellipseQuadrantTable(exponent);
  var sideSign = 1.0;
  var minDistanceSquared = 1e20;
  for (var i = 1; i < table.length; i++) {
    final previous = table[i - 1];
    final pointA = p - previous;
    final pointB = table[i] - previous;
    final lengthB = _dot(pointB, pointB);
    // Two samples can collapse onto each other at extreme exponents, and a
    // 0/0 there would poison the whole octant.
    final h = lengthB > 1e-20 ? _clamp01(_dot(pointA, pointB) / lengthB) : 0.0;
    final perpendicular = pointA - pointB * h;
    final distanceSquared = _dot(perpendicular, perpendicular);
    if (distanceSquared < minDistanceSquared) {
      minDistanceSquared = distanceSquared;
      sideSign = pointA.dx * pointB.dy - pointA.dy * pointB.dx;
    }
  }
  return SuperellipseSample(
    math.sqrt(minDistanceSquared) * _sign(sideSign) * scale,
    gradient,
  );
}

/// Skipping the walk entirely: the same zero level set, but the value is a
/// p-norm rather than a distance.
double superellipseApproxSdf(Offset point, double scale, double exponent) {
  final p = point / scale;
  final sumPowers =
      _pow(p.dx.abs(), exponent) + _pow(p.dy.abs(), exponent);
  return (_pow(sumPowers, 1.0 / exponent) - 1.0) * scale;
}

/// The p-norm ball that rounds a rectangle corner.
double superellipseCornerSdf(Offset point, double radius, double exponent) {
  final x = point.dx.abs();
  final y = point.dy.abs();
  final value = _pow(_pow(x, exponent) + _pow(y, exponent), 1.0 / exponent);
  return value - radius;
}

/// Box with superellipse corners.
///
/// [rect] is in points, [fragmentCoord] in pixels; with [contentsScale] left
/// at 1 both are just logical points.
double roundedRectangleSdf(
  Offset fragmentCoord,
  Rect rect,
  double cornerRadius,
  double roundnessExponent, {
  double contentsScale = 1.0,
}) {
  final rectOriginPx = Offset(rect.left, rect.top) * contentsScale;
  final rectSizePx = Offset(rect.width, rect.height) * contentsScale;
  final scaledCornerRadius = cornerRadius * contentsScale;

  final rectCenterPx = rectOriginPx + rectSizePx * 0.5;
  final point = fragmentCoord - rectCenterPx;

  final halfExtents = rectSizePx * 0.5;
  final edgeDistance = Offset(
    point.dx.abs() - halfExtents.dx,
    point.dy.abs() - halfExtents.dy,
  );

  if (edgeDistance.dx > -scaledCornerRadius &&
      edgeDistance.dy > -scaledCornerRadius) {
    // Corner region: superellipse rounding.
    final cornerCenter = Offset(
      _sign(point.dx) * (halfExtents.dx - scaledCornerRadius),
      _sign(point.dy) * (halfExtents.dy - scaledCornerRadius),
    );
    return superellipseCornerSdf(
      point - cornerCenter,
      scaledCornerRadius,
      roundnessExponent,
    );
  }
  // Straight edges or interior: standard rounded-box formula.
  return math.min(math.max(edgeDistance.dx, edgeDistance.dy), 0.0) +
      Offset(math.max(edgeDistance.dx, 0.0), math.max(edgeDistance.dy, 0.0))
          .distance;
}

/// Polynomial smooth-min — the merge that morphs two shapes together.
double smoothUnion(double distanceA, double distanceB, double smoothness) {
  final hermite =
      _clamp01(0.5 + 0.5 * (distanceB - distanceA) / smoothness);
  final mixed = distanceB + (distanceA - distanceB) * hermite;
  return mixed - smoothness * hermite * (1.0 - hermite);
}

/// Every rectangle smooth-unioned into one field.
///
/// Careful with the return value: each rectangle's distance is normalized by
/// [resolutionY] before merging, so this is unitless — multiply by
/// [resolutionY] to get points back. [shapeMergeSmoothness] lives in that same
/// normalized space (the app ships 0.2).
double primaryShapeSdf(
  Offset fragmentCoord,
  List<Rect> rectangles, {
  required double cornerRadius,
  required double cornerRoundnessExponent,
  required double shapeMergeSmoothness,
  required double resolutionY,
  double contentsScale = 1.0,
}) {
  var combinedDistance = 1e10;
  var first = true;

  for (final rect in rectangles) {
    if (rect.width <= 0 || rect.height <= 0) continue;

    final rectDistance = roundedRectangleSdf(
      fragmentCoord,
      rect,
      cornerRadius,
      cornerRoundnessExponent,
      contentsScale: contentsScale,
    );

    final normalizedRectDist = rectDistance / resolutionY;

    if (first) {
      combinedDistance = normalizedRectDist;
      first = false;
    } else {
      combinedDistance = smoothUnion(
        combinedDistance,
        normalizedRectDist,
        shapeMergeSmoothness,
      );
    }
  }

  return combinedDistance;
}

// =========================================================================
// Normal / debug-colour helpers, used by the gallery's viz modes
// =========================================================================

/// atan2 lifted into [0, 2π].
double vectorToAngle(Offset vector) {
  final angle = math.atan2(vector.dy, vector.dx);
  return angle < 0 ? angle + 2 * math.pi : angle;
}

/// HSV to RGB, all channels 0..1.
({double r, double g, double b}) hsvToRgb(double h, double s, double v) {
  double channel(double kn) {
    final p = ((h + kn) % 1.0 * 6.0 - 3.0).abs();
    return v * (1.0 + (_clamp01(p - 1.0) - 1.0) * s);
  }

  return (r: channel(1.0), g: channel(2.0 / 3.0), b: channel(1.0 / 3.0));
}

/// Direction as hue — the normal debug view.
({double r, double g, double b}) vectorToRainbowColor(Offset vector) =>
    hsvToRgb(vectorToAngle(vector) / (2 * math.pi), 1.0, 1.0);
