// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — Continuous-curvature (Apple-style G2) rounded-rectangle path.
//
// Faithful Dart port of Kyant0/Shapes:
//   ContinuousCurvatureRoundedRectangleCornerBuilder.kt
//   RoundedRectangleOutline.kt
//
// Each corner is 3 cubic Bézier segments (10 control points) tuned so the
// curvature ramps in/out smoothly (G2 continuity) instead of jumping from a
// straight edge to a circular arc. This is the same construction Apple uses
// for `RoundedRectangle(style: .continuous)`.
//
// This file is self-contained and has no dependency on the rest of the
// package. Deleting the `continuous_sdf/` folder removes the whole feature.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui';

const double _sqrt2 = 1.4142135623730951;
const double _fracPi4 = 0.7853981633974483;
const double _frac1Sqrt2 = 0.7071067811865476;

/// Builds the normalized Bézier control points for one corner of a
/// continuous-curvature rounded rectangle.
///
/// Points are expressed in a unit corner space (radius = 1). The path builder
/// scales them by the real corner radius. The heavy algebra (solving for the
/// control points that satisfy G2 continuity) is precomputed in the
/// constructor and cached, so per-frame use is cheap.
class ContinuousCornerBuilder {
  ContinuousCornerBuilder({
    this.extendedFraction = 2.0 / 3.0,
    this.arcFraction = 0.5,
  })  : _theta = (1.0 - arcFraction) * _fracPi4 {
    _cos = math.cos(_theta);
    _sin = math.sin(_theta);
    _cot = 1.0 / math.tan(_theta);
    _cos2 = _cos * _cos;
    _sin2 = _sin * _sin;
    _cos3 = _cos2 * _cos;
    _sin3 = _sin2 * _sin;

    _k0 = 27.0 * (_sqrt2 - 6.0 * _cos + 6.0 * _sqrt2 * _cos2 - 4.0 * _cos3) * _cot +
        2.0 *
            _sin *
            (-9.0 +
                2.0 * (_sqrt2 - 2.0 * _sin) * _sin3 +
                2.0 * _sqrt2 * _cos * (9.0 + _sin2) -
                2.0 * _cos2 * (9.0 + 2.0 * _sin2));
    _k1 = -81.0 *
            (-2.0 + _sqrt2 + 4.0 * (-1.0 + _sqrt2) * _cos + 2.0 * (-2.0 + _sqrt2) * _cos2) *
            _cot -
        4.0 *
            _sin *
            (-9.0 + 9.0 * _sqrt2 + _sqrt2 * _sin3 + (-2.0 + _sqrt2) * _cos * (9.0 + _sin2));
    _k2 = 9.0 *
        (9.0 * (-4.0 + 3.0 * _sqrt2 + (-6.0 + 4.0 * _sqrt2) * _cos) * _cot +
            (-6.0 + 4.0 * _sqrt2) * _sin);
    _k3 = 27.0 * (10.0 - 7.0 * _sqrt2) * _cot;

    _cache = [
      [
        _buildEvenCornerBezierPoints(0.0),
        _buildUnevenCornerBezierPoints(0.0, 1.0),
      ],
      [
        _buildUnevenCornerBezierPoints(1.0, 0.0),
        _buildEvenCornerBezierPoints(1.0),
      ],
    ];
  }

  final double extendedFraction;
  final double arcFraction;

  final double _theta;
  late final double _cos, _sin, _cot, _cos2, _sin2, _cos3, _sin3;
  late final double _k0, _k1, _k2, _k3;
  late final List<List<List<double>>> _cache;

  /// Returns 20 doubles = 10 (x,y) control points for a corner whose
  /// horizontal/vertical "fullness" factors are [tH] and [tV] (each 0..1,
  /// where 1 = the corner has room for full smoothing and 0 = it is squeezed
  /// to a capsule-like profile).
  List<double> getCornerBezierPoints({double tH = 1.0, double tV = 1.0}) {
    final int? i = tH == 0.0 ? 0 : (tH == 1.0 ? 1 : null);
    if (i == null) return _buildCornerBezierPoints(tH, tV);
    final int? j = tV == 0.0 ? 0 : (tV == 1.0 ? 1 : null);
    if (j == null) return _buildCornerBezierPoints(tH, tV);
    return _cache[i][j];
  }

  List<double> _buildCornerBezierPoints(double tH, double tV) {
    return tH == tV
        ? _buildEvenCornerBezierPoints(tH)
        : _buildUnevenCornerBezierPoints(tH, tV);
  }

  List<double> _buildEvenCornerBezierPoints(double t) {
    final double k = extendedFraction * t;
    final double kappa = _solveCubicSingle(_k3, _k2, _k1 + 8.0 * (-k) * _sin3 * _sin, _k0);

    final double x3 = _frac1Sqrt2 + (-_frac1Sqrt2 + _sin) / kappa;
    final double y3 = 1.0 - _frac1Sqrt2 + (_frac1Sqrt2 - _cos) / kappa;
    final double x2 = x3 - y3 * _cot;
    final double x1 = x2 - 1.5 * kappa * y3 * y3 / _sin3;
    final double x0 = -k;

    final double x6 = 1.0 - y3;
    final double y6 = 1.0 - x3;
    final double y7 = 1.0 - x2;
    final double y8 = 1.0 - x1;
    final double y9 = 1.0 - x0;

    final double a = 1.5 * kappa;
    final double g = _cos2 - _sin2;
    final double x36 = x6 - x3;
    final double y36 = y6 - y3;
    final double c = -(_cos * y36 - _sin * x36);
    final double lambda = (-g + math.sqrt(g * g - 4.0 * a * c)) / (2.0 * a);
    final double x4 = x3 + lambda * _cos;
    final double y4 = y3 + lambda * _sin;
    final double x5 = x6 - lambda * _sin;
    final double y5 = y6 - lambda * _cos;

    return [x0, 0.0, x1, 0.0, x2, 0.0, x3, y3, x4, y4, x5, y5, x6, y6, 1.0, y7, 1.0, y8, 1.0, y9];
  }

  List<double> _buildUnevenCornerBezierPoints(double tH, double tV) {
    final double kH = extendedFraction * tH;
    final double kV = extendedFraction * tV;

    final double kappa3 = _solveCubicSingle(_k3, _k2, _k1 + 8.0 * (-kH) * _sin3 * _sin, _k0);
    final double kappa6 = _solveCubicSingle(_k3, _k2, _k1 + 8.0 * (-kV) * _sin3 * _sin, _k0);

    final double x3 = _frac1Sqrt2 + (-_frac1Sqrt2 + _sin) / kappa3;
    final double y3 = 1.0 - _frac1Sqrt2 + (_frac1Sqrt2 - _cos) / kappa3;
    final double x2 = x3 - y3 * _cot;
    final double x1 = x2 - 1.5 * kappa3 * y3 * y3 / _sin3;
    final double x0 = -kH;

    final double x3p = _frac1Sqrt2 + (-_frac1Sqrt2 + _sin) / kappa6;
    final double y3p = 1.0 - _frac1Sqrt2 + (_frac1Sqrt2 - _cos) / kappa6;
    final double x2p = x3p - y3p * _cot;
    final double x1p = x2p - 1.5 * kappa6 * y3p * y3p / _sin3;
    final double x0p = -kV;
    final double x6 = 1.0 - y3p;
    final double y6 = 1.0 - x3p;
    final double y7 = 1.0 - x2p;
    final double y8 = 1.0 - x1p;
    final double y9 = 1.0 - x0p;

    final double a = 1.5 * kappa3;
    final double b = 1.5 * kappa6;
    final double g = _cos2 - _sin2;
    final double x36 = x6 - x3;
    final double y36 = y6 - y3;
    final double c = -(_cos * y36 - _sin * x36);
    final double d = _sin * y36 - _cos * x36;
    final double p = 2.0 * (d / b);
    final double q = g * g * g / (a * b * b);
    final double r = (a * d * d + c * g * g) / (a * b * b);
    final double lambda6 = _solveDepressedQuarticSingle(p, q, r);
    final double lambda3 = (-d - b * lambda6 * lambda6) / g;
    final double x4 = x3 + lambda3 * _cos;
    final double y4 = y3 + lambda3 * _sin;
    final double x5 = x6 - lambda6 * _sin;
    final double y5 = y6 - lambda6 * _cos;

    return [x0, 0.0, x1, 0.0, x2, 0.0, x3, y3, x4, y4, x5, y5, x6, y6, 1.0, y7, 1.0, y8, 1.0, y9];
  }

  static final ContinuousCornerBuilder shared = ContinuousCornerBuilder();
}

double _solveCubicSingle(double a, double b, double c, double d) {
  final double f = ((3.0 * c / a) - (b * b) / (a * a)) / 3.0;
  final double g = ((2.0 * b * b * b) / (a * a * a) - (9.0 * b * c) / (a * a) + (27.0 * d) / a) / 27.0;
  final double h = g * g / 4.0 + f * f * f / 27.0;
  final double sqrtH = math.sqrt(h);
  return _cbrt(-g / 2.0 + sqrtH) + _cbrt(-g / 2.0 - sqrtH) - b / (3.0 * a);
}

double _solveDepressedQuarticSingle(double p, double q, double r) {
  final double b = -p / 2.0;
  final double c = -r;
  final double d = r * p / 2.0 - q * q / 8.0;
  final double f = ((3.0 * c) - (b * b)) / 3.0;
  final double g = ((2.0 * b * b * b) - (9.0 * b * c) + (27.0 * d)) / 27.0;
  final double rr = math.sqrt(-f * f * f / 27.0);
  final double phi = math.acos(-g / (2.0 * rr));
  final double y = 2.0 * math.sqrt(-f / 3.0) * math.cos(phi / 3.0);
  final double z = y - b / 3.0;
  final double u = math.sqrt(2.0 * z - p);
  return (u - math.sqrt(u * u - 4.0 * (z + q / (2.0 * u)))) / 2.0;
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1.0 / 3.0).toDouble() : math.pow(x, 1.0 / 3.0).toDouble();

double _coerceIn(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Builds a closed [Path] for a continuous-curvature rounded rectangle of the
/// given [size] with a single uniform [radius] (in the same px units as
/// [size]). Falls back to a plain rectangle when radius <= 0.
Path continuousRoundedRectanglePath(Size size, double radius) {
  final double width = size.width;
  final double height = size.height;
  final path = Path();
  if (radius <= 0.0) {
    path.addRect(Rect.fromLTWH(0, 0, width, height));
    return path;
  }

  final builder = ContinuousCornerBuilder.shared;
  final double w = width;
  final double h = height;
  final double r = radius;
  final double tW = _coerceIn((width * 0.5 - r) / r, 0.0, 1.0);
  final double tH = _coerceIn((height * 0.5 - r) / r, 0.0, 1.0);
  final p = builder.getCornerBezierPoints(tH: tW, tV: tH);
  if (p.length < 20) {
    path.addRect(Rect.fromLTWH(0, 0, width, height));
    return path;
  }

  // top-right corner
  double x = w - r, y = 0.0;
  path.moveTo(x + p[0] * r, y + p[1] * r);
  path.cubicTo(x + p[2] * r, y + p[3] * r, x + p[4] * r, y + p[5] * r, x + p[6] * r, y + p[7] * r);
  path.cubicTo(x + p[8] * r, y + p[9] * r, x + p[10] * r, y + p[11] * r, x + p[12] * r, y + p[13] * r);
  path.cubicTo(x + p[14] * r, y + p[15] * r, x + p[16] * r, y + p[17] * r, x + p[18] * r, y + p[19] * r);

  // bottom-right corner
  x = w - r;
  y = h;
  path.lineTo(x + p[18] * r, y - p[19] * r);
  path.cubicTo(x + p[16] * r, y - p[17] * r, x + p[14] * r, y - p[15] * r, x + p[12] * r, y - p[13] * r);
  path.cubicTo(x + p[10] * r, y - p[11] * r, x + p[8] * r, y - p[9] * r, x + p[6] * r, y - p[7] * r);
  path.cubicTo(x + p[4] * r, y - p[5] * r, x + p[2] * r, y - p[3] * r, x + p[0] * r, y - p[1] * r);

  // bottom-left corner
  x = r;
  y = h;
  path.lineTo(x - p[0] * r, y - p[1] * r);
  path.cubicTo(x - p[2] * r, y - p[3] * r, x - p[4] * r, y - p[5] * r, x - p[6] * r, y - p[7] * r);
  path.cubicTo(x - p[8] * r, y - p[9] * r, x - p[10] * r, y - p[11] * r, x - p[12] * r, y - p[13] * r);
  path.cubicTo(x - p[14] * r, y - p[15] * r, x - p[16] * r, y - p[17] * r, x - p[18] * r, y - p[19] * r);

  // top-left corner
  x = r;
  y = 0.0;
  path.lineTo(x - p[18] * r, y + p[19] * r);
  path.cubicTo(x - p[16] * r, y + p[17] * r, x - p[14] * r, y + p[15] * r, x - p[12] * r, y + p[13] * r);
  path.cubicTo(x - p[10] * r, y + p[11] * r, x - p[8] * r, y + p[9] * r, x - p[6] * r, y + p[7] * r);
  path.cubicTo(x - p[4] * r, y + p[5] * r, x - p[2] * r, y + p[3] * r, x - p[0] * r, y + p[1] * r);

  path.close();
  return path;
}
