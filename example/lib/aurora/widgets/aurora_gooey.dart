import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';

/// Fuses whatever it wraps into a single gooey silhouette.
///
/// The trick is two filters, not a shader: blur the subtree so nearby
/// shapes bleed into each other, then push alpha through a steep
/// contrast curve so the bleed snaps back to a hard edge. Where two
/// shapes overlap, the summed alpha clears the threshold and they read
/// as one body — which is exactly what a metaball is.
///
/// It costs two save layers, so keep the wrapped subtree small.
class GooeyLayer extends StatelessWidget {
  final Widget child;

  /// How far shapes reach for each other, in logical pixels.
  final double spread;

  /// Where the alpha edge lands, 0..1. Lower = fatter, softer bodies.
  final double threshold;

  const GooeyLayer({
    super.key,
    required this.child,
    this.spread = 12,
    this.threshold = 0.42,
  });

  @override
  Widget build(BuildContext context) {
    final gain = 26.0;
    final bias = -gain * threshold * 255;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, gain, bias, //
      ]),
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: spread,
          sigmaY: spread,
          tileMode: TileMode.decal,
        ),
        child: child,
      ),
    );
  }
}

/// The "…" of a chat: three dots that swell, drift together, and pull
/// apart again through a [GooeyLayer], so the gap between them stretches
/// like liquid instead of just closing.
class TypingDots extends StatefulWidget {
  final Color color;
  final double size;

  const TypingDots({super.key, required this.color, this.size = 9});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    return SizedBox(
      width: d * 4.6,
      height: d * 2.4,
      child: GooeyLayer(
        spread: d * 0.75,
        threshold: 0.4,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            return Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Align(
                    alignment: Alignment(
                      (i - 1) * (0.62 + 0.22 * math.sin(t)),
                      0.30 * math.sin(t + i * 1.15),
                    ),
                    child: Container(
                      width: d * (1 + 0.22 * math.sin(t + i * 1.15)),
                      height: d * (1 + 0.22 * math.sin(t + i * 1.15)),
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A slowly morphing organic blob — the app's mark.
///
/// Its outline is a radius function with three harmonics beating against
/// each other at incommensurate speeds, so the silhouette never repeats.
class BlobMorph extends StatefulWidget {
  final double size;
  final List<Color> colors;

  /// How far the outline wanders from a circle, 0..1.
  final double wobble;
  final Widget? child;

  const BlobMorph({
    super.key,
    this.size = 120,
    required this.colors,
    this.wobble = 0.12,
    this.child,
  });

  @override
  State<BlobMorph> createState() => _BlobMorphState();
}

class _BlobMorphState extends State<BlobMorph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = context.auroraController.reduceMotion;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: _BlobPainter(
            t: still ? 0.2 : _c.value,
            colors: widget.colors,
            wobble: widget.wobble,
          ),
          child: child,
        ),
        child: widget.child == null ? null : Center(child: widget.child),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final double wobble;

  _BlobPainter({required this.t, required this.colors, required this.wobble});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2 * 0.92;
    final tau = t * 2 * math.pi;

    const steps = 90;
    final points = <Offset>[];
    for (var i = 0; i < steps; i++) {
      final a = i / steps * 2 * math.pi;
      final r = base *
          (1 +
              wobble * math.sin(3 * a + tau) +
              wobble * 0.62 * math.sin(5 * a - tau * 1.7) +
              wobble * 0.38 * math.sin(7 * a + tau * 0.6));
      points.add(center + Offset(math.cos(a) * r, math.sin(a) * r));
    }

    // Close the outline through segment midpoints so every joint is C1.
    final path = Path()
      ..moveTo(
        (points.first.dx + points.last.dx) / 2,
        (points.first.dy + points.last.dy) / 2,
      );
    for (var i = 0; i < points.length; i++) {
      final cur = points[i];
      final next = points[(i + 1) % points.length];
      path.quadraticBezierTo(
        cur.dx,
        cur.dy,
        (cur.dx + next.dx) / 2,
        (cur.dy + next.dy) / 2,
      );
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.colors != colors;
}

/// A field of drifting balls that merge on contact — the ink counterpart
/// to the package's glass metaballs.
class MetaballField extends StatefulWidget {
  final int count;
  final List<Color> colors;
  final double spread;

  /// Balls lean toward this point when it isn't null, so a finger drags
  /// the whole field with it.
  final Offset? attractor;

  const MetaballField({
    super.key,
    this.count = 6,
    required this.colors,
    this.spread = 16,
    this.attractor,
  });

  @override
  State<MetaballField> createState() => _MetaballFieldState();
}

class _MetaballFieldState extends State<MetaballField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  final math.Random _rng = math.Random(7);
  late final List<_Ball> _balls = List.generate(
    widget.count,
    (i) => _Ball(
      ax: 0.18 + _rng.nextDouble() * 0.26,
      ay: 0.16 + _rng.nextDouble() * 0.24,
      fx: 0.6 + _rng.nextDouble() * 1.3,
      fy: 0.6 + _rng.nextDouble() * 1.3,
      phase: _rng.nextDouble() * math.pi * 2,
      radius: 0.10 + _rng.nextDouble() * 0.10,
      home:
          Offset(0.2 + _rng.nextDouble() * 0.6, 0.2 + _rng.nextDouble() * 0.6),
    ),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = context.auroraController.reduceMotion;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final short = math.min(w, h);
        return GooeyLayer(
          spread: widget.spread,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final tau = (still ? 0.15 : _c.value) * 2 * math.pi;
              return Stack(
                children: [
                  for (var i = 0; i < _balls.length; i++)
                    _positioned(_balls[i], i, tau, w, h, short),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _positioned(
    _Ball b,
    int i,
    double tau,
    double w,
    double h,
    double short,
  ) {
    var x = (b.home.dx + b.ax * math.sin(tau * b.fx + b.phase)) * w;
    var y = (b.home.dy + b.ay * math.cos(tau * b.fy + b.phase)) * h;

    final pull = widget.attractor;
    if (pull != null) {
      // Inverse-square-ish attraction, capped so nothing snaps.
      final d = (pull - Offset(x, y));
      final dist = d.distance.clamp(1.0, 1e4);
      final k = (short * 0.9 / dist).clamp(0.0, 0.55);
      x += d.dx * k;
      y += d.dy * k;
    }

    final r = short * b.radius;
    return Positioned(
      left: x - r,
      top: y - r,
      width: r * 2,
      height: r * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.colors[i % widget.colors.length],
        ),
      ),
    );
  }
}

class _Ball {
  final double ax, ay, fx, fy, phase, radius;
  final Offset home;
  const _Ball({
    required this.ax,
    required this.ay,
    required this.fx,
    required this.fy,
    required this.phase,
    required this.radius,
    required this.home,
  });
}
