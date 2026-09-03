// -----------------------------------------------------------------------------
// BORDER vs BACKGROUND — drag the rims across the colours and watch.
//
// Five cards ride together across a background of strong colour fields. They
// answer one question: does the rim follow what is behind it? Only the first
// one is allowed a fragment shader.
//
//   shader   — a real lens. Its rim samples the refracted background per
//              pixel, so it picks the colours up on its own. The reference.
//   painted  — LiquidGlassLite, plain. It samples nothing: white light,
//              whatever it is dragged over.
//   blend    — pickup: blend. The rim ADDS its light to the background
//              instead of covering it, so the hue comes through. One blend
//              mode, no read, free.
//   backdrop — pickup: backdrop. The rim is cut out of a brightened copy of
//              the background, per pixel — colour varies ALONG the rim, like
//              the shader. Costs a backdrop read.
//   sampled  — plain rim + one ambientColor, averaged from under its own box.
//              One tone for the whole rim, but it follows the background.
//
// That sample comes from a low-resolution raster of the very background being
// drawn, taken once, so dragging costs a few hundred adds and no readback.
//
// Run it on its own:
//     cd example
//     flutter run -t lib/border_drag_page.dart
// -----------------------------------------------------------------------------

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const _BorderDragApp());

class _BorderDragApp extends StatelessWidget {
  const _BorderDragApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BorderDragPage(),
      );
}

class BorderDragPage extends StatefulWidget {
  const BorderDragPage({super.key});

  @override
  State<BorderDragPage> createState() => _BorderDragPageState();
}

class _BorderDragPageState extends State<BorderDragPage> {
  static const Size _card = Size(_cardWidth, 74);
  static const double _gap = 8;
  static const double _labelRoom = 22;
  static const double _cardWidth = 96;
  static const double _groupWidth = _cardWidth * 3 + _gap * 2;
  static const double _groupHeight = (74 + _labelRoom) * 2 + _gap;

  Offset _position = const Offset(28, 120);
  Size _canvas = Size.zero;

  /// The background, rasterised small, so the colour under a box is an
  /// in-memory average instead of a GPU readback.
  _BackgroundSample? _sample;
  Color? _under;

  double _borderWidth = 2.0;
  double _lightDirection = 40;
  double _blendFloor = 0.35;
  double _magnify = 1.0;
  double _bend = 0.0;

  /// Both halves of the bend: an even scale over the whole surface, and the
  /// harder one cross-faded into the last 30px before the outline.
  LiquidGlassRefraction get _refraction => LiquidGlassRefraction(
        magnification: _magnify,
        distortion: _bend,
        distortionWidth: 30,
      );

  LiquidGlassShape get _shape => LiquidGlassShape(
        cornerRadius: 26,
        clipQuality: LiquidGlassClipQuality.exact,
        borderWidth: _borderWidth,
        lightDirection: _lightDirection,
      );

  void _ensureSample(Size size) {
    if (size == _canvas && _sample != null) return;
    _canvas = size;
    _BackgroundSample.of(size).then((_BackgroundSample sample) {
      if (!mounted) return;
      setState(() {
        _sample = sample;
        _under = sample.averageUnder(_sampledCardRect());
      });
    });
  }

  /// The box of the sampled card — second on the second row — in the page's
  /// coordinates, which is the region its ambient colour is averaged over.
  Rect _sampledCardRect() => Rect.fromLTWH(
        _position.dx + _card.width + _gap,
        _position.dy + _card.height + _labelRoom + _gap,
        _card.width,
        _card.height,
      );

  void _drag(DragUpdateDetails details) {
    setState(() {
      final double maxX = _canvas.width - _groupWidth;
      final double maxY = _canvas.height - _groupHeight;
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(0.0, maxX < 0 ? 0.0 : maxX),
        (_position.dy + details.delta.dy).clamp(0.0, maxY < 0 ? 0.0 : maxY),
      );
      _under = _sample?.averageUnder(_sampledCardRect());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _ensureSample(size),
          );

          final LiquidGlassShape shape = _shape;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(painter: _BackdropPainter()),
              Positioned(
                left: _position.dx,
                top: _position.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: _drag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _Card(
                            label: 'shader',
                            child: SizedBox.fromSize(
                              size: _card,
                              child: LiquidGlassLens(
                                style: LiquidGlassStyle(
                                  shape: shape,
                                  appearance: const LiquidGlassAppearance(
                                    color: Color(0x0FFFFFFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: _gap),
                          _Card(
                            label: 'painted',
                            child: SizedBox.fromSize(
                              size: _card,
                              child: LiquidGlassLite(
                                shape: shape,
                                blur: const LiquidGlassBlur(),
                                refraction: _refraction,
                              ),
                            ),
                          ),
                          const SizedBox(width: _gap),
                          _Card(
                            label: 'blend',
                            child: SizedBox.fromSize(
                              size: _card,
                              child: LiquidGlassLite(
                                shape: shape,
                                blur: const LiquidGlassBlur(),
                                pickup: LiquidGlassPickup.blend,
                                blendFloor: _blendFloor,
                                refraction: _refraction,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _gap),
                      Row(
                        children: <Widget>[
                          _Card(
                            label: 'backdrop',
                            child: SizedBox.fromSize(
                              size: _card,
                              child: LiquidGlassLite(
                                shape: shape,
                                blur: const LiquidGlassBlur(),
                                pickup: LiquidGlassPickup.backdrop,
                                refraction: _refraction,
                              ),
                            ),
                          ),
                          const SizedBox(width: _gap),
                          _Card(
                            label: 'sampled',
                            swatch: _under,
                            child: SizedBox.fromSize(
                              size: _card,
                              child: LiquidGlassLite(
                                shape: shape,
                                blur: const LiquidGlassBlur(),
                                ambientColor: _under,
                                refraction: _refraction,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 12,
                child: Column(
                  children: <Widget>[
                    const Text(
                      'drag the three across the colours',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'only the first one is a shader',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Controls(
                  borderWidth: _borderWidth,
                  lightDirection: _lightDirection,
                  blendFloor: _blendFloor,
                  magnify: _magnify,
                  bend: _bend,
                  onWidth: (double v) => setState(() => _borderWidth = v),
                  onDirection: (double v) =>
                      setState(() => _lightDirection = v),
                  onFloor: (double v) => setState(() => _blendFloor = v),
                  onMagnify: (double v) => setState(() => _magnify = v),
                  onBend: (double v) => setState(() => _bend = v),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child, this.swatch});

  final String label;
  final Widget child;
  final Color? swatch;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (swatch != null) ...<Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  shadows: <Shadow>[Shadow(blurRadius: 4)],
                ),
              ),
            ],
          ),
        ],
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.borderWidth,
    required this.lightDirection,
    required this.blendFloor,
    required this.magnify,
    required this.bend,
    required this.onWidth,
    required this.onDirection,
    required this.onFloor,
    required this.onMagnify,
    required this.onBend,
  });

  final double borderWidth;
  final double lightDirection;
  final double blendFloor;
  final double magnify;
  final double bend;
  final ValueChanged<double> onWidth;
  final ValueChanged<double> onDirection;
  final ValueChanged<double> onFloor;
  final ValueChanged<double> onMagnify;
  final ValueChanged<double> onBend;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black45,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _row('width', borderWidth, 0, 6, onWidth),
            _row('light', lightDirection, 0, 360, onDirection),
            // How much plain rim the blend card keeps under its overlay:
            // left = strongest tint but nothing over black, right = safe and
            // washed out.
            _row('floor', blendFloor, 0, 1, onFloor),
            // The affine refraction: the backdrop scaled about each card's
            // own centre. Watch it against the grid, not the blobs.
            _row('zoom', magnify, 1, 1.6, onMagnify),
            // The edge half: how hard the last 30px before the outline push.
            // This one costs a backdrop read of its own.
            _row('bend', bend, 0, 1, onBend),
          ],
        ),
      );

  Widget _row(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) =>
      Row(
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
//  The background, and reading a colour out of it
// ─────────────────────────────────────────────────────────────

/// Strong, well-separated colour fields — including a white one and a black
/// one — so a rim that follows the background has something obvious to follow.
void _paintBackdrop(Canvas canvas, Size size) {
  final double w = size.width;
  final double h = size.height;
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = const Color(0xFF0B0D12),
  );

  final List<(Offset, double, Color)> fields = <(Offset, double, Color)>[
    (Offset(w * 0.20, h * 0.16), w * 0.42, const Color(0xFFE23A3A)),
    (Offset(w * 0.86, h * 0.24), w * 0.40, const Color(0xFF2E6BFF)),
    (Offset(w * 0.14, h * 0.58), w * 0.36, const Color(0xFF19B876)),
    (Offset(w * 0.78, h * 0.62), w * 0.38, const Color(0xFFFFC53D)),
    (Offset(w * 0.50, h * 0.88), w * 0.34, const Color(0xFFF7F7FA)),
    (Offset(w * 0.46, h * 0.40), w * 0.20, const Color(0xFF08090C)),
  ];
  for (final (Offset centre, double radius, Color color) in fields) {
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.28),
    );
  }

  // Soft colour alone cannot show a magnification — scaling a gradient looks
  // like the same gradient. The grid is what makes the bend legible: inside a
  // card the lines are spaced wider than the ones running past it.
  final Paint line = Paint()
    ..color = const Color(0x33FFFFFF)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  for (double x = 0; x < w; x += 22) {
    canvas.drawLine(Offset(x, 0), Offset(x, h), line);
  }
  for (double y = 0; y < h; y += 22) {
    canvas.drawLine(Offset(0, y), Offset(w, y), line);
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => _paintBackdrop(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The same background, rasterised once at a fraction of its size, so the
/// average colour under a box is a few hundred additions.
///
/// This is the demo's stand-in for what the shader gets for free — a lens
/// reads the real backdrop per pixel. A real app would feed `ambientColor`
/// from whatever it already knows about what is behind the widget.
class _BackgroundSample {
  _BackgroundSample._(this._pixels, this._width, this._height, this._scale);

  static const double _rasterScale = 0.12;

  final Uint8List _pixels;
  final int _width;
  final int _height;
  final double _scale;

  static Future<_BackgroundSample> of(Size size) async {
    final int w = (size.width * _rasterScale).ceil().clamp(1, 4096);
    final int h = (size.height * _rasterScale).ceil().clamp(1, 4096);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(_rasterScale);
    _paintBackdrop(canvas, size);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(w, h);
    picture.dispose();
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    return _BackgroundSample._(
      data!.buffer.asUint8List(),
      w,
      h,
      _rasterScale,
    );
  }

  /// The mean colour of the background inside [rect], in page coordinates.
  Color? averageUnder(Rect rect) {
    final int x0 = (rect.left * _scale).floor().clamp(0, _width - 1);
    final int x1 = (rect.right * _scale).ceil().clamp(x0 + 1, _width);
    final int y0 = (rect.top * _scale).floor().clamp(0, _height - 1);
    final int y1 = (rect.bottom * _scale).ceil().clamp(y0 + 1, _height);

    int r = 0;
    int g = 0;
    int b = 0;
    int n = 0;
    for (int y = y0; y < y1; y++) {
      int i = (y * _width + x0) * 4;
      for (int x = x0; x < x1; x++) {
        r += _pixels[i];
        g += _pixels[i + 1];
        b += _pixels[i + 2];
        i += 4;
        n++;
      }
    }
    if (n == 0) return null;
    return Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }
}
