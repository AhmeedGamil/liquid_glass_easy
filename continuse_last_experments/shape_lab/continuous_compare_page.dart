// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — every continuous rounded rect / capsule model we have,
// stacked on the same box so they can be compared corner by corner.
//
//   • P-NORM       pnorm_continuous_shape.dart — a p-norm corner with the
//                  fitted reach and per-axis exponent.
//   • OURS         our_continuous_shape.dart — the equation the package's own
//                  shader draws today.
//   • CONTINUOUS   continuous_sdf/continuous_corner_path.dart, the G2 Bézier
//                  reference. This is what everything is measured against.
//   • PLAIN P-NORM the same corner with no reach at all: box r × r, one
//                  exponent. Its exponent has its own slider — worth parking
//                  it at 4 ("squircle") to see how far off that is.
//   • CIRCULAR     a plain RRect, for orientation.
//
// The readout is the worst distance from the reference outline to each shape,
// as a percentage of the corner radius.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../continuous_sdf/continuous_corner_path.dart';
import 'pnorm_continuous_shape.dart';
import 'our_continuous_shape.dart';

const Color _pnormColor = Color(0xFFFFB020);
const Color _referenceColor = Color(0xFF69F0AE);
const Color _stockColor = Color(0xFF4FC3F7);
const Color _oursColor = Color(0xFFE040FB);
const Color _circularColor = Color(0x88FF5252);
const Color _background = Color(0xFF15151A);

class ContinuousComparePage extends StatefulWidget {
  const ContinuousComparePage({super.key});

  @override
  State<ContinuousComparePage> createState() =>
      _ContinuousComparePageState();
}

class _ContinuousComparePageState
    extends State<ContinuousComparePage> {
  static const Size _canvas = Size(340, 260);

  double _width = 300;
  double _height = 200;
  double _radius = 60;
  double _zoom = 1;
  double _stockExponent = 4;

  bool _showPnorm = true;
  bool _showReference = true;
  bool _showStock = true;
  bool _showOurs = true;
  bool _showCircular = false;
  bool _filled = false;

  /// The package's own equation, run with the shipped constants or with the
  /// candidate set from shape_compare_page.
  bool _oursFitted = false;

  double _pnormGap = 0;
  double _stockGap = 0;
  double _oursGap = 0;

  Size get _shapeSize => Size(_width, _height);

  double get _maxRadius => math.min(_width, _height) / 2;

  void _setSize({double? width, double? height}) => setState(() {
        _width = width ?? _width;
        _height = height ?? _height;
        _radius = math.min(_radius, _maxRadius);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Continuous corners, compared'),
        backgroundColor: _background,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Center(
              child: ClipRect(
                child: CustomPaint(
                  size: _canvas,
                  painter: _ComparePainter(
                    shapeSize: _shapeSize,
                    radius: _radius,
                    zoom: _zoom,
                    stockExponent: _stockExponent,
                    showPnorm: _showPnorm,
                    showReference: _showReference,
                    showStock: _showStock,
                    showOurs: _showOurs,
                    showCircular: _showCircular,
                    oursParams: _oursFitted ? kFittedCrr : kShippedCrr,
                    // The shader's seam floor is one physical pixel.
                    oursSeamFloor: 1 / MediaQuery.devicePixelRatioOf(context),
                    filled: _filled,
                    onGaps: _receiveGaps,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'worst gap from the reference, as % of the radius\n'
              'p-norm ${(_pnormGap * 100).toStringAsFixed(2)}%  ·  '
              'ours ${(_oursGap * 100).toStringAsFixed(2)}%  ·  '
              'plain ${(_stockGap * 100).toStringAsFixed(2)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 4),
            _Legend(
              showPnorm: _showPnorm,
              onPnorm: (v) => setState(() => _showPnorm = v),
              showReference: _showReference,
              onReference: (v) => setState(() => _showReference = v),
              showStock: _showStock,
              onStock: (v) => setState(() => _showStock = v),
              showOurs: _showOurs,
              onOurs: (v) => setState(() => _showOurs = v),
              showCircular: _showCircular,
              onCircular: (v) => setState(() => _showCircular = v),
            ),
            _SliderRow(
              label: 'radius',
              value: _radius,
              max: _maxRadius,
              onChanged: (v) => setState(() => _radius = v),
            ),
            _SliderRow(
              label: 'width',
              value: _width,
              min: 24,
              max: 320,
              onChanged: (v) => _setSize(width: v),
            ),
            _SliderRow(
              label: 'height',
              value: _height,
              min: 24,
              max: 240,
              onChanged: (v) => _setSize(height: v),
            ),
            _SliderRow(
              label: 'zoom',
              value: _zoom,
              min: 1,
              max: 10,
              suffix: '×',
              onChanged: (v) => setState(() => _zoom = v),
            ),
            _SliderRow(
              label: 'stock ⁿ',
              value: _stockExponent,
              min: 2,
              max: 10,
              onChanged: (v) => setState(() => _stockExponent = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FilledButton.tonal(
                    onPressed: () => setState(() => _radius = _maxRadius),
                    child: const Text('capsule'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _width = 300;
                      _height = 200;
                      _radius = 60;
                    }),
                    child: const Text('reset'),
                  ),
                  const Spacer(),
                  Switch(
                    value: _filled,
                    onChanged: (v) => setState(() => _filled = v),
                  ),
                  const Text('fill',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  const Text('ours constants',
                      style: TextStyle(color: _oursColor, fontSize: 12)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SegmentedButton<bool>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: false, label: Text('shipped')),
                        ButtonSegment(value: true, label: Text('fitted')),
                      ],
                      selected: {_oursFitted},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _oursFitted = s.first),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'reach   r · (1 + $kPnormReach · t)\n'
                'exponent  2 + $kPnormExponentRise · t\n'
                't = clamp((half-extent − r) / r, 0, 1), per axis',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  height: 1.45,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _receiveGaps(double pnorm, double stock, double ours) {
    if ((pnorm - _pnormGap).abs() < 0.00005 &&
        (stock - _stockGap).abs() < 0.00005 &&
        (ours - _oursGap).abs() < 0.00005) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pnormGap = pnorm;
        _stockGap = stock;
        _oursGap = ours;
      });
    });
  }
}

class _ComparePainter extends CustomPainter {
  _ComparePainter({
    required this.shapeSize,
    required this.radius,
    required this.zoom,
    required this.stockExponent,
    required this.showPnorm,
    required this.showReference,
    required this.showStock,
    required this.showOurs,
    required this.showCircular,
    required this.oursParams,
    required this.oursSeamFloor,
    required this.filled,
    required this.onGaps,
  });

  final Size shapeSize;
  final double radius;
  final double zoom;
  final double stockExponent;
  final bool showPnorm;
  final bool showReference;
  final bool showStock;
  final bool showOurs;
  final bool showCircular;
  final OurCrrParams oursParams;
  final double oursSeamFloor;
  final bool filled;
  final void Function(double pnorm, double stock, double ours) onGaps;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(
      (size.width - shapeSize.width) / 2,
      (size.height - shapeSize.height) / 2,
    );

    // Zoom about the top-right corner, drifting it to the middle as the
    // magnification rises so it stays in frame.
    final pivot = origin + Offset(shapeSize.width, 0);
    final centre = Offset(size.width / 2, size.height / 2);
    final t = ((zoom - 1) / 9).clamp(0.0, 1.0);
    final target = Offset.lerp(pivot, centre, t)!;

    canvas.save();
    canvas.translate(target.dx, target.dy);
    canvas.scale(zoom);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.translate(origin.dx, origin.dy);

    final stroke = 1.8 / zoom;
    void draw(Path path, Color color, {bool thin = false}) {
      if (filled) {
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.16));
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thin ? stroke * 0.8 : stroke
          ..color = color,
      );
    }

    final pnormPath = pnormContinuousPath(shapeSize, radius,
        segmentsPerCorner: (24 * zoom).round().clamp(24, 160));
    // The plain line has no reach and one exponent, held however little room
    // the corner has.
    final stockPath = pnormContinuousPath(
      shapeSize,
      radius,
      reach: 0,
      baseExponent: stockExponent,
      exponentRise: 0,
      segmentsPerCorner: (24 * zoom).round().clamp(24, 160),
    );
    final referencePath = continuousRoundedRectanglePath(shapeSize, radius);
    final oursPath = ourContinuousPath(
      shapeSize,
      radius,
      params: oursParams,
      seamFloor: oursSeamFloor,
      samplesPerQuadrant: (120 * zoom).round().clamp(120, 720),
    );

    if (showCircular) {
      draw(
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              Offset.zero & shapeSize, Radius.circular(radius))),
        _circularColor,
        thin: true,
      );
    }
    if (showReference) draw(referencePath, _referenceColor);
    if (showStock) draw(stockPath, _stockColor);
    if (showOurs) draw(oursPath, _oursColor);
    if (showPnorm) draw(pnormPath, _pnormColor);

    canvas.restore();

    if (radius <= 0) {
      onGaps(0, 0, 0);
      return;
    }
    final samples = _sampleReference(referencePath);
    final rect = Offset.zero & shapeSize;
    var oursWorst = 0.0;
    for (final p in samples) {
      final d = ourContinuousSdf(p, rect, radius,
              params: oursParams, seamFloor: oursSeamFloor)
          .abs();
      if (d > oursWorst) oursWorst = d;
    }
    onGaps(
      _worstGap(samples, shapeSize, radius,
              reach: kPnormReach,
              baseExponent: 2,
              exponentRise: kPnormExponentRise) /
          radius,
      _worstGap(samples, shapeSize, radius,
              reach: 0, baseExponent: stockExponent, exponentRise: 0) /
          radius,
      oursWorst / radius,
    );
  }

  @override
  bool shouldRepaint(covariant _ComparePainter old) =>
      old.shapeSize != shapeSize ||
      old.radius != radius ||
      old.zoom != zoom ||
      old.stockExponent != stockExponent ||
      old.showPnorm != showPnorm ||
      old.showReference != showReference ||
      old.showStock != showStock ||
      old.showOurs != showOurs ||
      old.showCircular != showCircular ||
      !identical(old.oursParams, oursParams) ||
      old.oursSeamFloor != oursSeamFloor ||
      old.filled != filled;
}

/// Points along the reference outline, which is what everything is measured
/// against.
List<Offset> _sampleReference(Path path) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    const steps = 900;
    for (var i = 0; i <= steps; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / steps);
      if (tangent != null) points.add(tangent.position);
    }
  }
  return points;
}

/// Worst distance from the reference [samples] to a candidate's surface, read
/// straight off the candidate's own SDF.
double _worstGap(
  List<Offset> samples,
  Size size,
  double radius, {
  required double reach,
  required double baseExponent,
  required double exponentRise,
}) {
  final rect = Offset.zero & size;
  var worst = 0.0;
  for (final p in samples) {
    final d = pnormContinuousSdf(p, rect, radius,
            reach: reach,
            baseExponent: baseExponent,
            exponentRise: exponentRise)
        .abs();
    if (d > worst) worst = d;
  }
  return worst;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.showPnorm,
    required this.onPnorm,
    required this.showReference,
    required this.onReference,
    required this.showStock,
    required this.onStock,
    required this.showOurs,
    required this.onOurs,
    required this.showCircular,
    required this.onCircular,
  });

  final bool showPnorm;
  final ValueChanged<bool> onPnorm;
  final bool showReference;
  final ValueChanged<bool> onReference;
  final bool showStock;
  final ValueChanged<bool> onStock;
  final bool showOurs;
  final ValueChanged<bool> onOurs;
  final bool showCircular;
  final ValueChanged<bool> onCircular;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        _LegendChip(
            label: 'p-norm',
            color: _pnormColor,
            value: showPnorm,
            onChanged: onPnorm),
        _LegendChip(
            label: 'ours (glsl)',
            color: _oursColor,
            value: showOurs,
            onChanged: onOurs),
        _LegendChip(
            label: 'reference',
            color: _referenceColor,
            value: showReference,
            onChanged: onReference),
        _LegendChip(
            label: 'plain p-norm',
            color: _stockColor,
            value: showStock,
            onChanged: onStock),
        _LegendChip(
            label: 'circular',
            color: _circularColor,
            value: showCircular,
            onChanged: onCircular),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value ? color : Colors.transparent,
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: value ? Colors.white : Colors.white38,
                    fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.suffix = '',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 62,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: math.max(max, min + 0.001),
              activeColor: _pnormColor,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${value.toStringAsFixed(1)}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
