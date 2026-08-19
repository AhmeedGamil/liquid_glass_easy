import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The page the glass sits on.
///
/// Whatever the source, the backdrop is **one `ui.Image` blitted once per
/// frame**. A live widget tree here would re-rasterise on every frame the glass
/// asks for the backdrop, which is what made the first version expensive; the
/// generated design is therefore drawn once into an offscreen image and reused.
class KitchenLabBackdrop extends StatefulWidget {
  const KitchenLabBackdrop({super.key, this.photo});

  /// A picture chosen from the device. When null the generated design is used.
  final ui.Image? photo;

  @override
  State<KitchenLabBackdrop> createState() => _KitchenLabBackdropState();
}

class _KitchenLabBackdropState extends State<KitchenLabBackdrop> {
  ui.Image? _baked;
  Size _bakedFor = Size.zero;
  double _bakedDpr = 0;
  int _bakeToken = 0;

  @override
  void dispose() {
    _baked?.dispose();
    super.dispose();
  }

  /// Renders the generated design once, at the current size, off the main draw
  /// path. Re-runs only when the size or pixel ratio actually changes.
  Future<void> _bake(Size size, double dpr) async {
    if (size.isEmpty) return;
    if (_baked != null && size == _bakedFor && dpr == _bakedDpr) return;

    final int token = ++_bakeToken;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(dpr);
    paintGeneratedBackdrop(canvas, size);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      (size.width * dpr).round(),
      (size.height * dpr).round(),
    );
    picture.dispose();

    if (!mounted || token != _bakeToken) {
      image.dispose();
      return;
    }
    setState(() {
      _baked?.dispose();
      _baked = image;
      _bakedFor = size;
      _bakedDpr = dpr;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? photo = widget.photo;
    if (photo != null) {
      return CustomPaint(painter: _BlitPainter(photo), size: Size.infinite);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        // Off the build pass: toImage is async and must not run inside build.
        WidgetsBinding.instance.addPostFrameCallback((_) => _bake(size, dpr));

        final ui.Image? baked = _baked;
        if (baked == null || _bakedFor != size) {
          return const ColoredBox(color: Color(0xFF080A10));
        }
        return CustomPaint(painter: _BlitPainter(baked), size: size);
      },
    );
  }
}

/// Draws one image over the whole area, cover-fitted. This is the only paint
/// work the backdrop does per frame.
class _BlitPainter extends CustomPainter {
  const _BlitPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _BlitPainter oldDelegate) =>
      !identical(oldDelegate.image, image);
}

// =============================================================================
// The generated design — drawn once, so it can afford to be detailed.
// =============================================================================

const List<(Alignment, Color, double)> _blooms = <(Alignment, Color, double)>[
  (Alignment(-0.8, -0.9), Color(0xFF3B6BFF), 0.95),
  (Alignment(0.9, -0.55), Color(0xFFB93BFF), 0.8),
  (Alignment(-0.6, 0.35), Color(0xFF00D0A8), 0.7),
  (Alignment(0.75, 0.85), Color(0xFFFF7A3D), 0.9),
  (Alignment(0.05, 0.05), Color(0xFF1E2A6B), 1.2),
];

// Curated pairs — vivid enough that the refracted edge shows real colour.
const List<(Color, Color)> _palette = <(Color, Color)>[
  (Color(0xFFFF6A88), Color(0xFFFF9A8B)),
  (Color(0xFF4FACFE), Color(0xFF00F2FE)),
  (Color(0xFF43E97B), Color(0xFF38F9D7)),
  (Color(0xFFFA709A), Color(0xFFFEE140)),
  (Color(0xFF30CFD0), Color(0xFF5B247A)),
  (Color(0xFFA18CD1), Color(0xFFFBC2EB)),
  (Color(0xFFF6D365), Color(0xFFFDA085)),
  (Color(0xFF5EE7DF), Color(0xFFB490CA)),
  (Color(0xFF3A7BD5), Color(0xFF00D2FF)),
];

const List<String> _titles = <String>[
  'Aurora', 'Meridian', 'Halide', 'Prism', 'Cobalt',
  'Lumen', 'Ember', 'Vapour', 'Drift', 'Solstice', 'Onyx', 'Cirrus',
];

/// Paints the generated page: colour blooms for the smooth gradients that show
/// magnification, a tile grid for the hard edges that show dispersion, and real
/// type for fine detail.
void paintGeneratedBackdrop(Canvas canvas, Size size) {
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF080A10));
  _paintBlooms(canvas, size);

  const double pad = 20;
  double y = 64;

  _text(canvas, 'Collection', Offset(pad, y), const TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  ));
  y += 42;

  _text(canvas, '9 albums · updated moments ago', Offset(pad, y), const TextStyle(
    color: Color(0xB3FFFFFF),
    fontSize: 13,
  ));
  y += 30;

  y += _paintChips(canvas, Offset(pad, y));
  y += 18;

  _paintGrid(canvas, size, top: y, pad: pad);
}

void _paintBlooms(Canvas canvas, Size size) {
  final Rect bounds = Offset.zero & size;
  final double unit = size.shortestSide;
  for (final (Alignment at, Color color, double scale) in _blooms) {
    final Offset centre = at.withinRect(bounds);
    final double radius = unit * scale;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }
}

/// Filter pills. Returns the height consumed.
double _paintChips(Canvas canvas, Offset origin) {
  const List<String> chips = <String>['All', 'Recent', 'Shared', 'Hidden'];
  const double height = 28;
  double x = origin.dx;

  for (final String chip in chips) {
    final bool active = chip == 'All';
    final TextPainter tp = _layout(chip, TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: active ? const Color(0xFF0B0E13) : const Color(0xCCFFFFFF),
    ));
    final double width = tp.width + 28;
    final RRect rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, origin.dy, width, height),
      const Radius.circular(20),
    );
    canvas.drawRRect(rr, Paint()
      ..color = active ? const Color(0xFFFFFFFF) : const Color(0x1FFFFFFF));
    canvas.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x22FFFFFF));
    tp.paint(canvas, Offset(x + 14, origin.dy + (height - tp.height) / 2));
    x += width + 8;
  }
  return height;
}

void _paintGrid(Canvas canvas, Size size, {required double top, required double pad}) {
  const int columns = 3;
  const double gapX = 12;
  const double gapY = 14;
  const double captionBlock = 32;

  final double cell = (size.width - pad * 2 - gapX * (columns - 1)) / columns;
  final double art = cell * 1.05;
  final double rowHeight = art + captionBlock + gapY;
  final int rows = math.max(1, ((size.height - top) / rowHeight).ceil());

  for (int row = 0; row < rows; row++) {
    for (int col = 0; col < columns; col++) {
      final int i = row * columns + col;
      final double x = pad + col * (cell + gapX);
      final double y = top + row * rowHeight;
      if (y > size.height) return;

      final (Color from, Color to) = _palette[i % _palette.length];
      final Rect rect = Rect.fromLTWH(x, y, cell, art);
      final RRect rr = RRect.fromRectAndRadius(rect, const Radius.circular(16));

      canvas.drawRRect(rr, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[from, to],
        ).createShader(rect));

      canvas.save();
      canvas.clipRRect(rr);
      _paintTilePattern(canvas, rect, i);
      canvas.restore();

      _text(canvas, _titles[i % _titles.length], Offset(x, y + art + 6),
          const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          maxWidth: cell);
      _text(canvas, '${12 + i * 7} items', Offset(x, y + art + 22),
          const TextStyle(color: Color(0x99FFFFFF), fontSize: 10.5),
          maxWidth: cell);
    }
  }
}

/// High-frequency detail inside each tile: rings, diagonals or a dot field,
/// picked by index so the design is the same every run.
void _paintTilePattern(Canvas canvas, Rect rect, int seed) {
  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = const Color(0x40FFFFFF);

  switch (seed % 3) {
    case 0:
      final Offset centre =
          Offset(rect.left + rect.width * 0.62, rect.top + rect.height * 0.38);
      for (double r = 8; r < rect.longestSide; r += 11) {
        canvas.drawCircle(centre, r, paint);
      }
    case 1:
      for (double x = rect.left - rect.height; x < rect.right; x += 9) {
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x + rect.height, rect.bottom),
          paint,
        );
      }
    default:
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x59FFFFFF);
      final math.Random rng = math.Random(seed * 31 + 5);
      for (int i = 0; i < 44; i++) {
        canvas.drawCircle(
          rect.topLeft +
              Offset(rng.nextDouble() * rect.width, rng.nextDouble() * rect.height),
          1.1 + rng.nextDouble() * 1.9,
          paint,
        );
      }
  }
}

TextPainter _layout(String text, TextStyle style, {double maxWidth = double.infinity}) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  return tp;
}

void _text(Canvas canvas, String text, Offset at, TextStyle style,
    {double maxWidth = double.infinity}) {
  _layout(text, style, maxWidth: maxWidth).paint(canvas, at);
}
