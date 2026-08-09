import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// A painted backdrop for the glass to bend — no network, no assets.
///
/// Two jobs, and the second is the one that matters. Colour comes from soft
/// radial blobs, but a smooth gradient barely reveals refraction: bending a
/// gradient produces another gradient. So the painter also lays down **hard
/// structure** — concentric rings and hairlines — because a straight line
/// passing under glass visibly bows, and that is what makes the lens legible.
///
/// Everything is derived from fixed constants and the canvas size, so the
/// result is identical on every frame and every reload. That is what lets the
/// demos capture it **once** instead of every frame: a static background needs
/// exactly one snapshot, and the lenses can move over it forever.
class GlassBackdrop extends StatelessWidget {
  /// Base colour behind the blobs.
  final Color base;

  /// Blob colours, painted in order, largest first.
  final List<Color> blobs;

  /// Colour of the rings and hairlines.
  final Color structure;

  const GlassBackdrop({
    super.key,
    required this.base,
    required this.blobs,
    this.structure = const Color(0x1AFFFFFF),
  });

  /// Deep violet → magenta → cyan. Reads well under clear glass.
  const GlassBackdrop.dusk({super.key})
      : base = const Color(0xFF120B24),
        blobs = const [
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
          Color(0xFF0EA5E9),
          Color(0xFF22D3EE),
        ],
        structure = const Color(0x1FFFFFFF);

  /// Warm amber → coral → teal, on near-black. Higher contrast than [dusk],
  /// so refraction is easier to see at small sizes.
  const GlassBackdrop.ember({super.key})
      : base = const Color(0xFF0D0B14),
        blobs = const [
          Color(0xFFF59E0B),
          Color(0xFFEF4444),
          Color(0xFF14B8A6),
          Color(0xFF8B5CF6),
        ],
        structure = const Color(0x24FFFFFF);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(
        base: base,
        blobs: blobs,
        structure: structure,
      ),
      // Cheap to rasterize once, and it never invalidates: same size in,
      // same pixels out.
      isComplex: true,
      willChange: false,
      child: const SizedBox.expand(),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final Color base;
  final List<Color> blobs;
  final Color structure;

  const _BackdropPainter({
    required this.base,
    required this.blobs,
    required this.structure,
  });

  /// Blob centres in normalized space, plus a radius factor of the diagonal.
  /// Hand-placed rather than random so the composition is the same every
  /// time and the corners never go dead.
  static const List<(double, double, double)> _spots = [
    (0.16, 0.18, 0.62),
    (0.86, 0.10, 0.50),
    (0.78, 0.74, 0.58),
    (0.22, 0.88, 0.46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);

    final double diagonal =
        math.sqrt(size.width * size.width + size.height * size.height);

    // ── colour: soft radial blobs, screened over each other ──────────
    for (int i = 0; i < _spots.length; i++) {
      final (fx, fy, fr) = _spots[i];
      final Offset c = Offset(fx * size.width, fy * size.height);
      final double r = fr * diagonal * 0.5;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              blobs[i % blobs.length].withValues(alpha: 0.55),
              blobs[i % blobs.length].withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // ── structure: what actually shows the bend ──────────────────────
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..color = structure
      ..strokeWidth = 1.0;

    // Concentric rings off-centre, so a lens crossing them distorts arcs
    // rather than a symmetric target.
    final Offset ringCentre = Offset(size.width * 0.62, size.height * 0.34);
    for (double r = diagonal * 0.06; r < diagonal * 0.78; r += diagonal * 0.055) {
      canvas.drawCircle(ringCentre, r, line);
    }

    // Diagonal hairlines: straight edges are the clearest possible tell —
    // under glass they visibly bow.
    final double step = size.shortestSide / 7;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        line..color = structure.withValues(alpha: structure.a * 0.5),
      );
    }

    // A soft vignette so content on top keeps its contrast.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            const Color(0x00000000),
            base.withValues(alpha: 0.65),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.base != base ||
      old.structure != structure ||
      !listEquals(old.blobs, blobs);
}
