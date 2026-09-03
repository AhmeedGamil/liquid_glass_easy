import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// =============================================================
// What the glass looks at.
//
// Everything on these pages is painted rather than downloaded: the
// backdrops are coloured lamps over a near-black base, and the artwork
// is generated from the record's seed. That keeps the app offline, but
// it is also the reason it reads as glass — a lens over a smooth
// gradient has nothing to bend, so both painters deliberately lay
// STRUCTURE over the colour (contour rings, a scatter of stars, a hard
// motif on every cover). Those are the lines that visibly bow when a
// pill slides over them.
// =============================================================

/// The page's light: [AuroraPalette] painted full-bleed.
///
/// This is what a page hands its scaffold as the `body` — the layer the
/// glass captures and refracts. Nothing interactive lives here.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop(
      {super.key, required this.palette, this.seed = 'aurora'});

  final AuroraPalette palette;

  /// Seeds the star field, so two pages lit the same way still differ.
  final String seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _BackdropPainter(palette, seed)),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.palette, this.seed);

  final AuroraPalette palette;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double s = size.shortestSide;

    canvas.drawRect(rect, Paint()..color = palette.base);

    // The lamps, added rather than blended: over a near-black base
    // additive light is what makes two overlapping colours produce a
    // third bright one instead of a muddy average.
    for (final AuroraBlob b in palette.blobs) {
      final Offset c = b.center.alongSize(size);
      final double r = b.radius * s;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              b.color.withValues(alpha: 0.55 * b.intensity),
              b.color.withValues(alpha: 0.20 * b.intensity),
              b.color.withValues(alpha: 0.0),
            ],
            stops: const <double>[0.0, 0.42, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    paintAuroraStructure(canvas, size, seed);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.palette != palette || old.seed != seed;
}

/// The lines the glass bends: a set of wide contour rings and a star
/// field, both faint enough to read as texture and both hard-edged
/// enough to show a lens moving over them. Shared by every backdrop.
void paintAuroraStructure(Canvas canvas, Size size, String seed) {
  final double s = size.shortestSide;
  final Rect rect = Offset.zero & size;

  final Offset ringCentre = const Alignment(-0.2, -0.6).alongSize(size);
  final Paint ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  for (int i = 0; i < 10; i++) {
    ring.color = Colors.white.withValues(alpha: 0.055 - i * 0.0042);
    canvas.drawCircle(ringCentre, s * (0.20 + i * 0.125), ring);
  }

  final math.Random rnd = math.Random(seed.hashCode);
  for (int i = 0; i < 110; i++) {
    final Offset p =
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
    canvas.drawCircle(
      p,
      0.5 + rnd.nextDouble() * 1.2,
      Paint()
        ..color =
            Colors.white.withValues(alpha: 0.05 + rnd.nextDouble() * 0.32),
    );
  }

  // Corners pulled down, so the middle of the page is where the light is.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const <double>[0.5, 1.0],
      ).createShader(rect),
  );
}

// ── Artwork ──────────────────────────────────────────────────

/// A record's cover, generated from its seed: two hues, two lamps and
/// one hard motif, so every album in the app has its own artwork and
/// none of it has to ship.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.seed,
    this.size,
    this.radius = 18,
    this.scrim = false,
    this.child,
  });

  final String seed;

  /// Side length. Null lets the parent decide (a grid cell, a hero box).
  final double? size;

  final double radius;

  /// Darkens the lower half, for artwork that has type over it.
  final bool scrim;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CoverPainter(seed, scrim),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.seed, this.scrim);

  final String seed;
  final bool scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double w = size.width;
    final double h = size.height;
    final math.Random rnd = math.Random(seed.hashCode);

    final double h1 = rnd.nextDouble() * 360;
    final double h2 = (h1 + 35 + rnd.nextDouble() * 95) % 360;
    Color hsl(double hue, double sat, double light) =>
        HSLColor.fromAHSL(1, hue, sat, light).toColor();

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[hsl(h1, 0.72, 0.52), hsl(h2, 0.68, 0.24)],
        ).createShader(rect),
    );

    // Two lamps inside the frame, same additive trick as the backdrop.
    for (int i = 0; i < 2; i++) {
      final Offset c = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final double r = w * (0.45 + rnd.nextDouble() * 0.4);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              hsl((h2 + i * 60) % 360, 0.8, 0.55).withValues(alpha: 0.45),
              hsl((h2 + i * 60) % 360, 0.8, 0.55).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    _motif(canvas, size, seed.hashCode.abs() % 4, rnd);

    // A sheen off the top-left corner — the thing that stops a flat
    // gradient reading as a swatch.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.center,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    if (scrim) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.55),
            ],
          ).createShader(rect),
      );
    }
  }

  /// One of four hard-edged figures. They are what a lens has to bend:
  /// the gradients underneath could be anything, but a bowed ring is
  /// unmistakable.
  void _motif(Canvas canvas, Size size, int kind, math.Random rnd) {
    final double w = size.width;
    final double h = size.height;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.012);

    switch (kind) {
      case 0: // Rings, off-centre.
        final Offset c = Offset(w * 0.72, h * 0.28);
        for (int i = 0; i < 6; i++) {
          stroke.color = Colors.white.withValues(alpha: 0.20 - i * 0.026);
          canvas.drawCircle(c, w * (0.10 + i * 0.115), stroke);
        }
      case 1: // Slanted bars.
        canvas.save();
        canvas.translate(w * 0.5, h * 0.5);
        canvas.rotate(-0.42);
        for (int i = -4; i <= 4; i++) {
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset(i * w * 0.19, 0),
                width: w * 0.055,
                height: h * 2),
            Paint()..color = Colors.white.withValues(alpha: 0.09),
          );
        }
        canvas.restore();
      case 2: // A disc rising past the edge, with its own halo.
        final Offset c = Offset(w * 0.32, h * 0.74);
        canvas.drawCircle(
          c,
          w * 0.34,
          Paint()..color = Colors.white.withValues(alpha: 0.13),
        );
        stroke.color = Colors.white.withValues(alpha: 0.22);
        canvas.drawCircle(c, w * 0.46, stroke);
      case 3: // Standing waves.
        stroke.color = Colors.white.withValues(alpha: 0.18);
        for (int line = 0; line < 5; line++) {
          final Path p = Path();
          final double y = h * (0.24 + line * 0.14);
          final double amp = h * 0.055 * (1 + line * 0.12);
          for (double x = 0; x <= w; x += w / 28) {
            final double yy =
                y + math.sin((x / w) * math.pi * 2.2 + line) * amp;
            x == 0 ? p.moveTo(x, yy) : p.lineTo(x, yy);
          }
          canvas.drawPath(p, stroke);
        }
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.seed != seed || old.scrim != scrim;
}
