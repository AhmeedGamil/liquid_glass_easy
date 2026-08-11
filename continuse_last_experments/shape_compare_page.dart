// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — outline comparison of three shapes stacked in the SAME rect:
//
//   • OURS         the same equation shape, run with a CANDIDATE constant set
//                  that is NOT in the shader (see _fittedParams).
//   • SHADER-EXACT the equation exactly as shipped in
//                  lib/assets/shaders/liquid_glass_common.glsl, with the seam
//                  floor in PHYSICAL px — `max(rr*0.15, 1.0)` is one fragment
//                  pixel there, i.e. 1 / devicePixelRatio logical px here.
//   • CONTINUOUS   the reference Bézier construction from
//                  continuous_sdf/continuous_corner_path.dart (G2).
//
// Every shape is stroked at 2 px, has its own radius, and can be hidden.
//
// Run directly:  flutter run -t lib/shape_compare_page.dart
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'continuous_corner_path.dart';

/// The five tunable constants of the continuous-corner equation.
class _CrrParams {
  const _CrrParams({
    required this.extFrac,
    required this.t0,
    required this.aTail,
    required this.nTail,
    required this.seamFraction,
  });

  final double extFrac;
  final double t0;
  final double aTail;
  final double nTail;
  final double seamFraction;
}

/// Exactly what ships in lib/assets/shaders/liquid_glass_common.glsl.
const _shaderParams = _CrrParams(
  extFrac: 0.4425,
  t0: 0.728,
  aTail: 4.836,
  nTail: 3.869,
  seamFraction: 0.15,
);

/// Candidate set under evaluation — not in the shader.
const _fittedParams = _CrrParams(
  extFrac: 0.99997431,
  t0: 0.00000000,
  aTail: 19.93250275,
  nTail: 9.33909130,
  seamFraction: 0.10970203,
);

const Color _oursColor = Color(0xFFFFB020);
const Color _shaderColor = Color(0xFF4FC3F7);
const Color _continuousColor = Color(0xFF69F0AE);

void main() => runApp(const _ShapeCompareApp());

class _ShapeCompareApp extends StatelessWidget {
  const _ShapeCompareApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const ShapeComparePage(),
    );
  }
}

class ShapeComparePage extends StatefulWidget {
  const ShapeComparePage({super.key});

  @override
  State<ShapeComparePage> createState() => _ShapeComparePageState();
}

class _ShapeComparePageState extends State<ShapeComparePage> {
  static const Size _canvasSize = Size(320, 240);
  static const double _minSide = 24;
  static const double _maxWidth = 300;
  static const double _maxHeight = 220;
  static const double _maxZoom = 10;

  double _width = 280;
  double _height = 200;

  double _ourRadius = 60;
  double _shaderRadius = 60;
  double _continuousRadius = 60;

  bool _showOurs = true;
  bool _showShader = true;
  bool _showContinuous = true;

  double _zoom = 1;
  bool _linked = true;

  double _ourGap = 0;
  double _shaderGap = 0;

  Size get _shapeSize => Size(_width, _height);

  double get _maxRadius => math.min(_width, _height) / 2;

  /// Shrinking the box can leave a radius above `min(w, h) / 2`, which is both
  /// meaningless and an assertion failure on the slider — clamp on every size
  /// change.
  void _setSize({double? width, double? height}) => setState(() {
        _width = width ?? _width;
        _height = height ?? _height;
        final limit = _maxRadius;
        _ourRadius = math.min(_ourRadius, limit);
        _shaderRadius = math.min(_shaderRadius, limit);
        _continuousRadius = math.min(_continuousRadius, limit);
      });

  void _setRadius(int which, double v) => setState(() {
        if (_linked) {
          _ourRadius = v;
          _shaderRadius = v;
          _continuousRadius = v;
          return;
        }
        switch (which) {
          case 0:
            _ourRadius = v;
          case 1:
            _shaderRadius = v;
          case 2:
            _continuousRadius = v;
        }
      });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF15151A),
      appBar: AppBar(
        title: const Text('Shape compare'),
        backgroundColor: const Color(0xFF15151A),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Center(
              child: ClipRect(
                child: CustomPaint(
                  size: _canvasSize,
                  painter: _ComparePainter(
                    shapeSize: _shapeSize,
                    zoom: _zoom,
                    shapes: [
                      _ShapeSpec(
                        id: 'continuous',
                        radius: _continuousRadius,
                        color: _continuousColor,
                        visible: _showContinuous,
                        params: null,
                        seamFloor: null,
                      ),
                      _ShapeSpec(
                        id: 'shader',
                        radius: _shaderRadius,
                        color: _shaderColor,
                        visible: _showShader,
                        params: _shaderParams,
                        seamFloor: 1.0 / dpr,
                      ),
                      _ShapeSpec(
                        id: 'ours',
                        radius: _ourRadius,
                        color: _oursColor,
                        visible: _showOurs,
                        params: _fittedParams,
                        seamFloor: 1.0,
                      ),
                    ],
                    onGaps: _receiveGaps,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _GapReadout(
              ourGap: _ourGap,
              shaderGap: _shaderGap,
              showOurs: _showOurs,
              showShader: _showShader,
              showContinuous: _showContinuous,
            ),
            const SizedBox(height: 6),
            _ShapeRow(
              label: 'ours',
              hint: 'fitted constants',
              color: _oursColor,
              visible: _showOurs,
              onVisible: (v) => setState(() => _showOurs = v),
              radius: _ourRadius,
              maxRadius: _maxRadius,
              onRadius: (v) => _setRadius(0, v),
            ),
            _ShapeRow(
              label: 'shader-exact',
              hint: 'shipped constants',
              color: _shaderColor,
              visible: _showShader,
              onVisible: (v) => setState(() => _showShader = v),
              radius: _shaderRadius,
              maxRadius: _maxRadius,
              onRadius: (v) => _setRadius(1, v),
            ),
            _ShapeRow(
              label: 'continuous',
              hint: 'Bézier reference',
              color: _continuousColor,
              visible: _showContinuous,
              onVisible: (v) => setState(() => _showContinuous = v),
              radius: _continuousRadius,
              maxRadius: _maxRadius,
              onRadius: (v) => _setRadius(2, v),
            ),
            const Divider(height: 20, indent: 16, endIndent: 16),
            _SliderRow(
              label: 'width',
              color: Colors.white70,
              value: _width,
              min: _minSide,
              max: _maxWidth,
              onChanged: (v) => _setSize(width: v),
            ),
            _SliderRow(
              label: 'height',
              color: Colors.white70,
              value: _height,
              min: _minSide,
              max: _maxHeight,
              onChanged: (v) => _setSize(height: v),
            ),
            _SliderRow(
              label: 'zoom',
              color: Colors.white70,
              value: _zoom,
              min: 1,
              max: _maxZoom,
              suffix: '×',
              onChanged: (v) => setState(() => _zoom = v),
            ),
            SwitchListTile(
              dense: true,
              value: _linked,
              onChanged: (v) => setState(() {
                _linked = v;
                if (v) {
                  _shaderRadius = _ourRadius;
                  _continuousRadius = _ourRadius;
                }
              }),
              title: const Text('Link all radii',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            const _ConstantsTable(),
          ],
        ),
      ),
    );
  }

  void _receiveGaps(double ours, double shader) {
    if ((ours - _ourGap).abs() < 0.0005 &&
        (shader - _shaderGap).abs() < 0.0005) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _ourGap = ours;
        _shaderGap = shader;
      });
    });
  }
}

/// Both constant sets, side by side, so the numbers on screen are the numbers
/// being drawn.
class _ConstantsTable extends StatelessWidget {
  const _ConstantsTable();

  @override
  Widget build(BuildContext context) {
    String column(_CrrParams p) => 'EXTFRAC ${p.extFrac.toStringAsFixed(8)}\n'
        'T0      ${p.t0.toStringAsFixed(8)}\n'
        'ATAIL   ${p.aTail.toStringAsFixed(8)}\n'
        'NTAIL   ${p.nTail.toStringAsFixed(8)}\n'
        'SEAM    ${p.seamFraction.toStringAsFixed(8)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ConstantsColumn(
              title: 'ours',
              color: _oursColor,
              body: column(_fittedParams),
            ),
          ),
          Expanded(
            child: _ConstantsColumn(
              title: 'shader-exact',
              color: _shaderColor,
              body: column(_shaderParams),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstantsColumn extends StatelessWidget {
  const _ConstantsColumn({
    required this.title,
    required this.color,
    required this.body,
  });

  final String title;
  final Color color;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          body,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            height: 1.35,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _GapReadout extends StatelessWidget {
  const _GapReadout({
    required this.ourGap,
    required this.shaderGap,
    required this.showOurs,
    required this.showShader,
    required this.showContinuous,
  });

  final double ourGap;
  final double shaderGap;
  final bool showOurs;
  final bool showShader;
  final bool showContinuous;

  @override
  Widget build(BuildContext context) {
    if (!showContinuous || (!showOurs && !showShader)) {
      return const SizedBox(height: 18);
    }
    final parts = <String>[
      if (showOurs) 'ours ${ourGap.toStringAsFixed(2)} px',
      if (showShader) 'shader-exact ${shaderGap.toStringAsFixed(2)} px',
    ];
    return Text(
      'max gap from continuous — ${parts.join(' · ')}',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 12.5),
    );
  }
}

/// One shape's controls: a coloured visibility checkbox + its radius slider.
class _ShapeRow extends StatelessWidget {
  const _ShapeRow({
    required this.label,
    required this.hint,
    required this.color,
    required this.visible,
    required this.onVisible,
    required this.radius,
    required this.maxRadius,
    required this.onRadius,
  });

  final String label;
  final String hint;
  final Color color;
  final bool visible;
  final ValueChanged<bool> onVisible;
  final double radius;
  final double maxRadius;
  final ValueChanged<double> onRadius;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: visible ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Checkbox(
              value: visible,
              activeColor: color,
              checkColor: Colors.black,
              onChanged: (v) => onVisible(v ?? false),
            ),
            SizedBox(
              width: 98,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(hint,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10.5)),
                ],
              ),
            ),
            Expanded(
              child: Slider(
                value: radius,
                max: maxRadius,
                activeColor: color,
                onChanged: onRadius,
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                radius.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.color,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.suffix = '',
  });

  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: TextStyle(color: color, fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${value.toStringAsFixed(1)}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// One outline to draw. [seamFloor] null means "the Bézier reference"; any
/// other value is the shader equation with that seam-width lower bound.
class _ShapeSpec {
  const _ShapeSpec({
    required this.id,
    required this.radius,
    required this.color,
    required this.visible,
    required this.params,
    required this.seamFloor,
  });

  final String id;
  final double radius;
  final Color color;
  final bool visible;
  final _CrrParams? params;
  final double? seamFloor;

  bool sameAs(_ShapeSpec other) =>
      id == other.id &&
      radius == other.radius &&
      color == other.color &&
      visible == other.visible &&
      identical(params, other.params) &&
      seamFloor == other.seamFloor;
}

class _ComparePainter extends CustomPainter {
  _ComparePainter({
    required this.shapeSize,
    required this.shapes,
    required this.zoom,
    required this.onGaps,
  });

  final Size shapeSize;

  /// Painted in order, so the last entry lands on top.
  final List<_ShapeSpec> shapes;
  final double zoom;
  final void Function(double ours, double shaderExact) onGaps;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(
      (size.width - shapeSize.width) / 2,
      (size.height - shapeSize.height) / 2,
    );

    // Zoom about the box's top-right corner, sliding it toward the middle of
    // the viewport as the magnification rises so the corner stays in frame.
    final pivot = origin + Offset(shapeSize.width, 0);
    final centre = Offset(size.width / 2, size.height / 2);
    final t = ((zoom - 1) / 9).clamp(0.0, 1.0);
    final target = Offset.lerp(pivot, centre, t)!;

    canvas.save();
    canvas.translate(target.dx, target.dy);
    canvas.scale(zoom);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.translate(origin.dx, origin.dy);

    final stroke = 2.0 / zoom;
    Path? reference;
    final marched = <String, _MarchedShape>{};

    for (final shape in shapes) {
      if (!shape.visible) continue;
      final Path path;
      final params = shape.params;
      if (params == null) {
        reference = continuousRoundedRectanglePath(shapeSize, shape.radius);
        path = reference;
      } else {
        final result = _marchOurShape(
          shapeSize,
          shape.radius,
          360,
          params: params,
          seamFloor: shape.seamFloor!,
        );
        marched[shape.id] = result;
        path = _polylinePath(result.outline);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = shape.color,
      );
    }

    canvas.restore();

    if (reference == null) {
      onGaps(0, 0);
      return;
    }
    final ours = marched['ours'];
    final shaderExact = marched['shader'];
    onGaps(
      ours == null ? 0 : _maxGap(ours.quadrant, reference),
      shaderExact == null ? 0 : _maxGap(shaderExact.quadrant, reference),
    );
  }

  @override
  bool shouldRepaint(covariant _ComparePainter old) {
    if (old.zoom != zoom ||
        old.shapeSize != shapeSize ||
        old.shapes.length != shapes.length) {
      return true;
    }
    for (var i = 0; i < shapes.length; i++) {
      if (!old.shapes[i].sameAs(shapes[i])) return true;
    }
    return false;
  }
}

// ── the production equation, ported ──────────────────────────────────────

double _shoulder(double tt, _CrrParams params) {
  if (tt <= params.t0) return 1;
  final u = ((tt - params.t0) / (1 - params.t0)).clamp(0.0, 1.0);
  final inner = math.max(1 - math.pow(u, params.aTail).toDouble(), 0.0);
  return math.pow(inner, 1 / params.nTail).toDouble();
}

/// Literal Dart port of `continuousRoundedRectShape()` for a rect of [size]
/// placed at the origin, with uniform corner radius [r].
///
/// [seamFloor] is the shader's `max(rr * 0.15, 1.0)` lower bound. The shader
/// runs in physical px, so its 1.0 is `1 / devicePixelRatio` logical px here;
/// pass 1.0 to reproduce the page's own logical-px reading instead.
double _ourShape(
  double x,
  double y,
  Size size,
  double r,
  _CrrParams params,
  double seamFloor,
) {
  final hw = size.width / 2;
  final hh = size.height / 2;
  final qx = (x - hw).abs() - hw + r;
  final qy = (y - hh).abs() - hh + r;
  if (r <= 0) return math.max(qx, qy);

  final reachH = math.max(math.min(params.extFrac * r, hw - r), 0.0);
  final reachV = math.max(math.min(params.extFrac * r, hh - r), 0.0);
  final gV = reachV * (_shoulder((qx / r).clamp(0.0, 1.0), params) - 1);
  final gH = reachH * (_shoulder((qy / r).clamp(0.0, 1.0), params) - 1);

  final lowerX = math.max(qx, 0.0);
  final lowerY = math.max(qy - gV, 0.0);
  final upperX = math.max(qx - gH, 0.0);
  final upperY = math.max(qy, 0.0);
  final fLower = math.sqrt(lowerX * lowerX + lowerY * lowerY) - r;
  final fUpper = math.sqrt(upperX * upperX + upperY * upperY) - r;

  final seamW = math.max(r * params.seamFraction, seamFloor);
  final blend = _smoothstep(-seamW, seamW, qx - qy);
  final corner = fUpper + (fLower - fUpper) * blend;
  return math.min(math.max(qx, qy), 0.0) + corner;
}

double _smoothstep(double e0, double e1, double v) {
  final t = ((v - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class _MarchedShape {
  const _MarchedShape(this.outline, this.quadrant);

  /// The full closed contour.
  final List<Offset> outline;

  /// Just the bottom-right quadrant — the only unique geometry, used for the
  /// gap measurement so it stays cheap.
  final List<Offset> quadrant;
}

/// Ray-marches the SDF zero level set from the rect centre. The shape is
/// symmetric about both axes, so only one quadrant is marched ([samples] + 1
/// rays) and the other three are mirrored.
_MarchedShape _marchOurShape(
  Size size,
  double r,
  int samples, {
  required _CrrParams params,
  required double seamFloor,
}) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final far = math.max(size.width, size.height);

  final distances = List<double>.filled(samples + 1, 0);
  final cosines = List<double>.filled(samples + 1, 0);
  final sines = List<double>.filled(samples + 1, 0);
  for (var i = 0; i <= samples; i++) {
    final angle = math.pi / 2 * i / samples;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    cosines[i] = dx;
    sines[i] = dy;
    var inside = 0.0;
    var outside = far;
    for (var step = 0; step < 22; step++) {
      final mid = (inside + outside) * 0.5;
      if (_ourShape(cx + dx * mid, cy + dy * mid, size, r, params, seamFloor) <=
          0) {
        inside = mid;
      } else {
        outside = mid;
      }
    }
    distances[i] = (inside + outside) * 0.5;
  }

  Offset at(int i, double sx, double sy) => Offset(
        cx + sx * cosines[i] * distances[i],
        cy + sy * sines[i] * distances[i],
      );

  final quadrant = [for (var i = 0; i <= samples; i++) at(i, 1, 1)];
  final outline = <Offset>[
    ...quadrant,
    for (var i = samples - 1; i >= 0; i--) at(i, -1, 1),
    for (var i = 1; i <= samples; i++) at(i, -1, -1),
    for (var i = samples - 1; i > 0; i--) at(i, 1, -1),
  ];
  return _MarchedShape(outline, quadrant);
}

Path _polylinePath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Largest distance from any point of [ours] to the [reference] outline.
double _maxGap(List<Offset> ours, Path reference) {
  final referencePoints = <Offset>[];
  for (final metric in reference.computeMetrics()) {
    const steps = 900;
    for (var i = 0; i <= steps; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / steps);
      if (tangent != null) referencePoints.add(tangent.position);
    }
  }
  if (referencePoints.length < 2) return 0;

  var worst = 0.0;
  for (var i = 0; i < ours.length; i += 4) {
    final p = ours[i];
    var nearest = double.infinity;
    for (var j = 0; j < referencePoints.length - 1; j++) {
      final d =
          _distanceToSegment(p, referencePoints[j], referencePoints[j + 1]);
      if (d < nearest) nearest = d;
    }
    if (nearest > worst) worst = nearest;
  }
  return worst;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final abx = b.dx - a.dx;
  final aby = b.dy - a.dy;
  final lengthSquared = abx * abx + aby * aby;
  if (lengthSquared < 1e-12) return (p - a).distance;
  final t = (((p.dx - a.dx) * abx + (p.dy - a.dy) * aby) / lengthSquared)
      .clamp(0.0, 1.0);
  return (p - Offset(a.dx + abx * t, a.dy + aby * t)).distance;
}
