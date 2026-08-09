// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — the continuous rounded rect / capsule built from the Metal
// shader's corner equation, stacked on the Apple-style reference.
//
//   • METAL-CONT   metal_continuous_shape.dart — the p-norm corner with the
//                  fitted reach and per-axis exponent.
//   • CONTINUOUS   continuous_sdf/continuous_corner_path.dart, the G2 Bézier
//                  reference. This is what the other two are measured against.
//   • STOCK P-NORM the shader corner exactly as shipped: corner box r × r, one
//                  exponent, no reach. Its exponent has its own slider — worth
//                  parking it at 4 ("squircle") to see how far off that is.
//   • CIRCULAR     a plain RRect, for orientation.
//
// The readout is the worst distance from the reference outline to each shape,
// as a percentage of the corner radius.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../continuous_sdf/continuous_corner_path.dart';
import 'metal_continuous_shape.dart';

const Color _metalColor = Color(0xFFFFB020);
const Color _referenceColor = Color(0xFF69F0AE);
const Color _stockColor = Color(0xFF4FC3F7);
const Color _circularColor = Color(0x88FF5252);
const Color _background = Color(0xFF15151A);

class MetalContinuousComparePage extends StatefulWidget {
  const MetalContinuousComparePage({super.key});

  @override
  State<MetalContinuousComparePage> createState() =>
      _MetalContinuousComparePageState();
}

class _MetalContinuousComparePageState
    extends State<MetalContinuousComparePage> {
  static const Size _canvas = Size(340, 260);

  double _width = 300;
  double _height = 200;
  double _radius = 60;
  double _zoom = 1;
  double _stockExponent = 4;

  bool _showMetal = true;
  bool _showReference = true;
  bool _showStock = true;
  bool _showCircular = false;
  bool _filled = false;

  double _metalGap = 0;
  double _stockGap = 0;

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
        title: const Text('Continuous from the Metal corner'),
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
                    showMetal: _showMetal,
                    showReference: _showReference,
                    showStock: _showStock,
                    showCircular: _showCircular,
                    filled: _filled,
                    onGaps: _receiveGaps,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'worst gap from the reference — '
              'metal ${(_metalGap * 100).toStringAsFixed(2)}%  ·  '
              'stock ${(_stockGap * 100).toStringAsFixed(2)}%   (of the radius)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            _Legend(
              showMetal: _showMetal,
              onMetal: (v) => setState(() => _showMetal = v),
              showReference: _showReference,
              onReference: (v) => setState(() => _showReference = v),
              showStock: _showStock,
              onStock: (v) => setState(() => _showStock = v),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'reach   r · (1 + $kMetalContinuousReach · t)\n'
                'exponent  2 + $kMetalContinuousExponentRise · t\n'
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

  void _receiveGaps(double metal, double stock) {
    if ((metal - _metalGap).abs() < 0.00005 &&
        (stock - _stockGap).abs() < 0.00005) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _metalGap = metal;
        _stockGap = stock;
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
    required this.showMetal,
    required this.showReference,
    required this.showStock,
    required this.showCircular,
    required this.filled,
    required this.onGaps,
  });

  final Size shapeSize;
  final double radius;
  final double zoom;
  final double stockExponent;
  final bool showMetal;
  final bool showReference;
  final bool showStock;
  final bool showCircular;
  final bool filled;
  final void Function(double metal, double stock) onGaps;

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

    final metalPath = metalContinuousPath(shapeSize, radius,
        segmentsPerCorner: (24 * zoom).round().clamp(24, 160));
    // The shader has one cornerRoundnessExponent uniform and no reach, so the
    // stock line holds its exponent however little room the corner has.
    final stockPath = metalContinuousPath(
      shapeSize,
      radius,
      reach: 0,
      baseExponent: stockExponent,
      exponentRise: 0,
      segmentsPerCorner: (24 * zoom).round().clamp(24, 160),
    );
    final referencePath = continuousRoundedRectanglePath(shapeSize, radius);

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
    if (showMetal) draw(metalPath, _metalColor);

    canvas.restore();

    if (radius <= 0) {
      onGaps(0, 0);
      return;
    }
    final samples = _sampleReference(referencePath);
    onGaps(
      _worstGap(samples, shapeSize, radius,
              reach: kMetalContinuousReach,
              baseExponent: 2,
              exponentRise: kMetalContinuousExponentRise) /
          radius,
      _worstGap(samples, shapeSize, radius,
              reach: 0, baseExponent: stockExponent, exponentRise: 0) /
          radius,
    );
  }

  @override
  bool shouldRepaint(covariant _ComparePainter old) =>
      old.shapeSize != shapeSize ||
      old.radius != radius ||
      old.zoom != zoom ||
      old.stockExponent != stockExponent ||
      old.showMetal != showMetal ||
      old.showReference != showReference ||
      old.showStock != showStock ||
      old.showCircular != showCircular ||
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
    final d = metalContinuousSdf(p, rect, radius,
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
    required this.showMetal,
    required this.onMetal,
    required this.showReference,
    required this.onReference,
    required this.showStock,
    required this.onStock,
    required this.showCircular,
    required this.onCircular,
  });

  final bool showMetal;
  final ValueChanged<bool> onMetal;
  final bool showReference;
  final ValueChanged<bool> onReference;
  final bool showStock;
  final ValueChanged<bool> onStock;
  final bool showCircular;
  final ValueChanged<bool> onCircular;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        _LegendChip(
            label: 'metal-cont',
            color: _metalColor,
            value: showMetal,
            onChanged: onMetal),
        _LegendChip(
            label: 'reference',
            color: _referenceColor,
            value: showReference,
            onChanged: onReference),
        _LegendChip(
            label: 'stock p-norm',
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
              activeColor: _metalColor,
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
