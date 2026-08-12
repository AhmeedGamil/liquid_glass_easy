import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../theme/aurora_palette.dart';
import '../theme/aurora_theme.dart';

/// The living backdrop every Aurora page sits on: a base wash with a
/// handful of slow, overlapping light fields drifting across it.
///
/// The drift runs on one 26-second loop — long enough to breathe rather
/// than pulse, which is the difference between a background you can look
/// at for a minute and one you can't.
class AuroraBackground extends StatefulWidget {
  /// Scroll offset in logical pixels. The field lags the content, which
  /// is what sells the depth.
  final double parallax;

  /// Multiplies blob opacity. Drop it under content-dense pages.
  final double intensity;

  /// Overrides the palette's blob colors — the weather page repaints the
  /// sky with these as the hour scrubs.
  final List<Color>? blobs;

  /// Overrides the palette's base wash.
  final List<Color>? canvas;

  /// Extra light that blooms from a point, `null` for none. Used by the
  /// smart-home page so a lamp actually lights the room.
  final AuroraGlow? glow;

  final Widget? child;

  const AuroraBackground({
    super.key,
    this.parallax = 0,
    this.intensity = 1,
    this.blobs,
    this.canvas,
    this.glow,
    this.child,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

/// A point light bloomed over the aurora field.
@immutable
class AuroraGlow {
  /// Position in fractional page coordinates (0..1 on both axes).
  final Alignment alignment;
  final Color color;

  /// 0 = off, 1 = full bloom.
  final double strength;

  /// Radius as a fraction of the page's shortest side.
  final double radius;

  const AuroraGlow({
    required this.alignment,
    required this.color,
    this.strength = 1,
    this.radius = 0.9,
  });

  @override
  bool operator ==(Object other) =>
      other is AuroraGlow &&
      other.alignment == alignment &&
      other.color == color &&
      other.strength == strength &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(alignment, color, strength, radius);
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void initState() {
    super.initState();
    _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final still = context.auroraController.reduceMotion;
    if (still && _drift.isAnimating) {
      _drift.stop();
    } else if (!still && !_drift.isAnimating) {
      _drift.repeat();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(
              isComplex: true,
              willChange: !still,
              painter: _AuroraPainter(
                t: _drift.value,
                parallax: widget.parallax,
                intensity: widget.intensity,
                palette: palette,
                blobs: widget.blobs ?? palette.blobs,
                canvas: widget.canvas ?? palette.canvas,
                glow: widget.glow,
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final double parallax;
  final double intensity;
  final AuroraPalette palette;
  final List<Color> blobs;
  final List<Color> canvas;
  final AuroraGlow? glow;

  _AuroraPainter({
    required this.t,
    required this.parallax,
    required this.intensity,
    required this.palette,
    required this.blobs,
    required this.canvas,
    required this.glow,
  });

  // Each blob rides its own Lissajous path. Coprime-ish frequency pairs
  // keep the whole field from ever repeating a pose.
  static const List<List<double>> _paths = [
    // ax, ay, fx, fy, phase, radius
    [0.34, 0.22, 1.0, 0.7, 0.00, 0.72],
    [0.30, 0.26, 0.7, 1.3, 1.90, 0.64],
    [0.26, 0.30, 1.3, 0.9, 3.40, 0.58],
    [0.36, 0.18, 0.9, 1.1, 5.10, 0.68],
    [0.22, 0.24, 1.5, 0.6, 2.40, 0.50],
  ];

  static const List<Offset> _anchors = [
    Offset(0.20, 0.16),
    Offset(0.82, 0.24),
    Offset(0.30, 0.74),
    Offset(0.76, 0.80),
    Offset(0.50, 0.46),
  ];

  @override
  void paint(Canvas canvas_, Size size) {
    final rect = Offset.zero & size;
    final tau = t * 2 * math.pi;
    final shortest = size.shortestSide;

    // Base wash.
    canvas_.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: canvas,
        ).createShader(rect),
    );

    // The field lags the content by a third of the scroll distance.
    final lag = -parallax * 0.34;

    // Additive in the dark, multiplied-soft in the light: the same blobs
    // that glow on black would bleach a pale canvas.
    final blend = palette.isDark ? BlendMode.plus : BlendMode.multiply;

    canvas_.saveLayer(rect, Paint());
    for (var i = 0; i < blobs.length && i < _paths.length; i++) {
      final p = _paths[i];
      final anchor = _anchors[i];
      final cx = (anchor.dx + p[0] * math.sin(tau * p[2] + p[4])) * size.width;
      final cy =
          (anchor.dy + p[1] * math.cos(tau * p[3] + p[4])) * size.height +
              lag * (0.6 + i * 0.18);
      final radius = shortest * p[5];

      final color = _tone(blobs[i]);
      canvas_.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..blendMode = blend
          ..shader = RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.45),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: radius),
          ),
      );
    }
    canvas_.restore();

    // A point light on top of the field.
    final g = glow;
    if (g != null && g.strength > 0.01) {
      final center = g.alignment.withinRect(rect);
      final radius = shortest * g.radius;
      canvas_.drawCircle(
        center,
        radius,
        Paint()
          ..blendMode = palette.isDark ? BlendMode.plus : BlendMode.srcOver
          ..shader = RadialGradient(
            colors: [
              g.color.withValues(alpha: 0.55 * g.strength),
              g.color.withValues(alpha: 0.18 * g.strength),
              g.color.withValues(alpha: 0),
            ],
            stops: const [0, 0.4, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Vignette — pulls the eye back to the middle of the page.
    canvas_.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: palette.isDark
              ? const [Color(0x00000000), Color(0x00000000), Color(0x73000000)]
              : const [Color(0x00000000), Color(0x00000000), Color(0x14101430)],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  /// Blob colors are authored at full strength; this is where they get
  /// their working opacity.
  Color _tone(Color c) => c.withValues(
        alpha: (palette.blobOpacity * intensity).clamp(0.0, 1.0),
      );

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t ||
      old.parallax != parallax ||
      old.intensity != intensity ||
      old.palette != palette ||
      old.glow != glow ||
      !listEquals(old.blobs, blobs) ||
      !listEquals(old.canvas, canvas);
}
