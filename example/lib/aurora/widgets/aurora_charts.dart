import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aurora_palette.dart';
import '../theme/aurora_theme.dart';

// ─────────────────────────────────────────────────────────────────
// Shared chart rules
//
// One axis, thin marks, recessive chrome, and text in text tokens —
// never in the series color. Series colors come from `palette.series`
// in fixed order and never track the user's accent: color follows the
// entity, not the theme. Anything with more than one series is also
// direct-labelled, so identity never rests on hue alone.
// ─────────────────────────────────────────────────────────────────

/// Draws a value ramp so bars animate up on first paint.
double _ease(double t) => Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

// ── Rings ────────────────────────────────────────────────────────

/// One arm of an [ActivityRings].
@immutable
class RingDatum {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final IconData icon;

  const RingDatum({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.icon,
  });

  double get progress => goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.4);
}

/// Concentric progress arcs — the "did I close them" form.
///
/// A ring is a bad chart for comparing magnitudes and a very good one
/// for reading progress toward a goal at a glance, which is the only job
/// it is given here. Each arm is direct-labelled underneath.
class ActivityRings extends StatelessWidget {
  final List<RingDatum> data;
  final double size;
  final double stroke;
  final bool showLegend;

  const ActivityRings({
    super.key,
    required this.data,
    this.size = 168,
    this.stroke = 17,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            size: Size.square(size),
            painter: _RingsPainter(
              data: data,
              palette: p,
              t: t,
              stroke: stroke,
            ),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 18),
          // Legend + direct labels: required for ≥2 series, and the
          // secondary encoding the light-mode palette needs.
          Wrap(
            spacing: 18,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < data.length; i++)
                _RingLegendEntry(
                  datum: data[i],
                  color: p.series[i % p.series.length],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RingLegendEntry extends StatelessWidget {
  final RingDatum datum;
  final Color color;

  const _RingLegendEntry({required this.datum, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(datum.label, style: AuroraText.caps(p)),
            const SizedBox(height: 2),
            Text(
              '${datum.value.round()}/${datum.goal.round()} ${datum.unit}',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<RingDatum> data;
  final AuroraPalette palette;
  final double t;
  final double stroke;

  _RingsPainter({
    required this.data,
    required this.palette,
    required this.t,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final gap = stroke * 0.42;

    for (var i = 0; i < data.length; i++) {
      final radius = size.width / 2 - stroke / 2 - i * (stroke + gap);
      if (radius <= 0) break;
      final color = palette.series[i % palette.series.length];
      final rect = Rect.fromCircle(center: center, radius: radius);

      // Track: the goal, held back so it reads as chrome.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withValues(alpha: palette.isDark ? 0.16 : 0.14),
      );

      final sweep = data[i].progress * _ease(t) * 2 * math.pi;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: [color.withValues(alpha: 0.65), color, color],
            stops: const [0, 0.55, 1],
            transform: GradientRotation(-math.pi / 2),
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.t != t || old.palette != palette || old.data != data;
}

// ── Bars ─────────────────────────────────────────────────────────

/// A single-series column chart — magnitude over an ordered category.
///
/// Bars grow from the baseline with a 4px rounded far end and a 2px gap
/// of surface between neighbours. The selected column is the only one
/// that carries a value label.
class AuroraBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final Color? color;
  final double height;
  final String unit;

  /// Drawn as a dashed hairline across the plot when set.
  final double? target;

  const AuroraBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.selected,
    this.onSelect,
    this.color,
    this.height = 150,
    this.unit = '',
    this.target,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.series.first;
    final max = values.isEmpty
        ? 1.0
        : math.max(values.reduce(math.max), target ?? 0) * 1.15;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / values.length;
        return SizedBox(
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onSelect == null
                ? null
                : (d) {
                    final i = (d.localPosition.dx / slot).floor();
                    if (i >= 0 && i < values.length) onSelect!(i);
                  },
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _BarPainter(
                  values: values,
                  labels: labels,
                  max: max,
                  t: t,
                  color: c,
                  palette: p,
                  selected: selected,
                  unit: unit,
                  target: target,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double max;
  final double t;
  final Color color;
  final AuroraPalette palette;
  final int? selected;
  final String unit;
  final double? target;

  _BarPainter({
    required this.values,
    required this.labels,
    required this.max,
    required this.t,
    required this.color,
    required this.palette,
    required this.selected,
    required this.unit,
    required this.target,
  });

  static const double _axisRoom = 26;
  static const double _labelRoom = 20;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plotTop = _labelRoom;
    final baseline = size.height - _axisRoom;
    final plotHeight = baseline - plotTop;
    final slot = size.width / values.length;
    // 2px of surface either side of every bar.
    final barWidth = math.min(slot - 12, 26.0);

    // Recessive baseline.
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = palette.stroke
        ..strokeWidth = 1,
    );

    // Target hairline, dashed so it never reads as data.
    if (target != null) {
      final y = baseline - (target! / max) * plotHeight;
      final paint = Paint()
        ..color = palette.textFaint
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
      }
    }

    for (var i = 0; i < values.length; i++) {
      final isSel = selected == i;
      final h = (values[i] / max) * plotHeight * _ease(t);
      final cx = slot * i + slot / 2;
      final rect = Rect.fromLTWH(
        cx - barWidth / 2,
        baseline - h,
        barWidth,
        h,
      );

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          // 4px rounded data-end; the baseline end stays square so the
          // bar is visibly anchored to zero.
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: isSel
                ? [color, color]
                : [
                    color.withValues(alpha: palette.isDark ? 0.42 : 0.34),
                    color.withValues(alpha: palette.isDark ? 0.72 : 0.62),
                  ],
          ).createShader(rect.inflate(1)),
      );

      // Category label, in ink — never in the series color.
      _text(
        canvas,
        labels[i],
        Offset(cx, baseline + 7),
        TextStyle(
          color: isSel ? palette.textPrimary : palette.textFaint,
          fontSize: 11,
          fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
        ),
      );

      // Selective direct label: only the selected column gets a number.
      if (isSel) {
        _text(
          canvas,
          '${values[i].round()}$unit',
          Offset(cx, math.max(0, baseline - h - 17)),
          TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      }
    }
  }

  void _text(Canvas canvas, String s, Offset topCenter, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(topCenter.dx - tp.width / 2, topCenter.dy));
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.t != t ||
      old.selected != selected ||
      old.palette != palette ||
      old.values != values;
}

// ── Line / sparkline ─────────────────────────────────────────────

/// A 2px line with a soft fill under it — change over time, one series.
///
/// No legend: with a single series the surrounding title names it.
class AuroraSparkline extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final double height;
  final bool fill;
  final bool showDot;

  /// Marks the newest sample with a pulsing dot — for live readings.
  final bool live;

  const AuroraSparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 70,
    this.fill = true,
    this.showDot = true,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparkPainter(
          values: values,
          color: color ?? p.series.first,
          palette: p,
          t: t,
          fill: fill,
          showDot: showDot,
          live: live,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final AuroraPalette palette;
  final double t;
  final bool fill;
  final bool showDot;
  final bool live;

  _SparkPainter({
    required this.values,
    required this.color,
    required this.palette,
    required this.t,
    required this.fill,
    required this.showDot,
    required this.live,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    final pad = 6.0;

    Offset at(int i) => Offset(
          size.width * i / (values.length - 1),
          pad + (1 - (values[i] - lo) / span) * (size.height - pad * 2),
        );

    // Catmull-Rom-ish smoothing keeps the line honest (it still passes
    // through every sample) while losing the polyline jaggedness.
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 0; i < values.length - 1; i++) {
      final p0 = at(i);
      final p1 = at(i + 1);
      final dx = (p1.dx - p0.dx) * 0.42;
      path.cubicTo(p0.dx + dx, p0.dy, p1.dx - dx, p1.dy, p1.dx, p1.dy);
    }

    final progress = _ease(t);
    final drawn = _trim(path, progress);

    if (fill) {
      final area = Path.from(drawn)
        ..lineTo(size.width * progress, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: palette.isDark ? 0.34 : 0.24),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (showDot && progress > 0.99) {
      final last = at(values.length - 1);
      if (live) {
        canvas.drawCircle(
          last,
          9,
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }
      // 2px surface ring so the marker reads over the fill.
      canvas.drawCircle(last, 5, Paint()..color = palette.canvas.first);
      canvas.drawCircle(last, 3.5, Paint()..color = color);
    }
  }

  /// Returns the leading [fraction] of [source] as a new path.
  Path _trim(Path source, double fraction) {
    if (fraction >= 1) return source;
    final out = Path();
    for (final metric in source.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.t != t || old.values != values || old.palette != palette;
}

// ── Heatmap ──────────────────────────────────────────────────────

/// A contribution grid — magnitude on a single-hue ramp, light → dark.
class AuroraHeatmap extends StatelessWidget {
  /// Row-major intensities in 0..1.
  final List<double> values;
  final int rows;
  final double cell;
  final double gap;

  const AuroraHeatmap({
    super.key,
    required this.values,
    this.rows = 7,
    this.cell = 13,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final columns = (values.length / rows).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: rows * cell + (rows - 1) * gap,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (context, t, _) => CustomPaint(
              size: Size(columns * (cell + gap), rows * (cell + gap)),
              painter: _HeatPainter(
                values: values,
                rows: rows,
                cell: cell,
                gap: gap,
                palette: p,
                t: t,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Less', style: AuroraText.caps(p)),
            const SizedBox(width: 8),
            for (final c in p.heat) ...[
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
            const SizedBox(width: 5),
            Text('More', style: AuroraText.caps(p)),
          ],
        ),
      ],
    );
  }
}

class _HeatPainter extends CustomPainter {
  final List<double> values;
  final int rows;
  final double cell;
  final double gap;
  final AuroraPalette palette;
  final double t;

  _HeatPainter({
    required this.values,
    required this.rows,
    required this.cell,
    required this.gap,
    required this.palette,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ramp = palette.heat;
    for (var i = 0; i < values.length; i++) {
      final col = i ~/ rows;
      final row = i % rows;
      final step = (values[i].clamp(0.0, 1.0) * (ramp.length - 1)).round();
      final appear =
          ((t * 1.6) - col / (values.length / rows) * 0.6).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      final rect = Rect.fromLTWH(
        col * (cell + gap),
        row * (cell + gap),
        cell,
        cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.lerp(rect.deflate(cell / 2), rect, _ease(appear))!,
          const Radius.circular(3.5),
        ),
        Paint()..color = ramp[step],
      );
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.t != t || old.palette != palette || old.values != values;
}

// ── Donut breakdown ──────────────────────────────────────────────

@immutable
class BreakdownSlice {
  final String label;
  final double value;
  const BreakdownSlice(this.label, this.value);
}

/// Part-to-whole for a handful of categories, with every slice
/// direct-labelled beside the ring.
class AuroraBreakdown extends StatelessWidget {
  final List<BreakdownSlice> slices;
  final String centerLabel;
  final String centerValue;
  final double size;

  const AuroraBreakdown({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _DonutPainter(
                    slices: slices,
                    total: total,
                    palette: p,
                    t: t,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerValue, style: AuroraText.numeric(p, size: 20)),
                    const SizedBox(height: 2),
                    Text(centerLabel, style: AuroraText.caps(p)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < slices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: p.series[i % p.series.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          slices[i].label,
                          style: AuroraText.label(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total == 0
                            ? '0%'
                            : '${(slices[i].value / total * 100).round()}%',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<BreakdownSlice> slices;
  final double total;
  final AuroraPalette palette;
  final double t;

  _DonutPainter({
    required this.slices,
    required this.total,
    required this.palette,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 9;
    var start = -math.pi / 2;
    final progress = _ease(t);

    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].value / total) * 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        // 2px of surface between segments.
        math.max(0, sweep - 0.04),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..color = palette.series[i % palette.series.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.t != t || old.palette != palette || old.slices != slices;
}
