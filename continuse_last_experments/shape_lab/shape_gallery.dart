// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — every primitive in shape_sdf.dart, on screen at once.
//
// Each card rasterizes one SDF over its own tile and shades the result three
// ways: filled, distance rings, or gradient rainbow (the normal debug view).
// The four values that change geometry — corner radius, roundness exponent,
// merge smoothness and the spacing between merged rects — are live at the
// bottom.
//
// Run it:  cd example && flutter run -t shape_lab_main.dart
// ─────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'continuous_compare_page.dart';
import 'shape_sdf.dart';

const Color _background = Color(0xFF15151A);
const Color _tileBackground = Color(0xFF101014);
const Color _accent = Color(0xFF4FC3F7);

void main() => runApp(const ShapeLabApp());

class ShapeLabApp extends StatelessWidget {
  const ShapeLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const ShapeLabPage(),
    );
  }
}

/// One card per SDF primitive.
enum SdfShape {
  circle('circle', 'length(p) − radius'),
  superellipse('superellipse', '24-segment boundary walk — true distance'),
  superellipseApprox(
      'superellipse · fast path', 'the p-norm alone, no boundary walk'),
  superellipseCorner(
      'superellipse corner', '(|x|ⁿ + |y|ⁿ)^(1/n) − r — the corner alone'),
  roundedRectangle('rounded rectangle', 'box with superellipse corners'),
  smoothUnionPair('smooth union', 'two rects, polynomial smooth-min'),
  mergedTrio('merged field', 'track + two thumbs, all merged');

  const SdfShape(this.title, this.formula);

  final String title;
  final String formula;
}

/// How a baked field is coloured.
enum ViewMode {
  fill('fill'),
  bands('rings'),
  normals('normals');

  const ViewMode(this.label);

  final String label;
}

/// The geometry uniforms, shared by every card.
@immutable
class ShapeParams {
  const ShapeParams({
    required this.cornerRadius,
    required this.exponent,
    required this.mergeSmoothness,
    required this.gap,
  });

  /// Corner radius — also the circle's and the p-norm ball's radius.
  final double cornerRadius;

  /// Roundness exponent — 1 = diamond, 2 = circle, 4 = squircle.
  final double exponent;

  /// Merge smoothness, in resolution-normalized units.
  final double mergeSmoothness;

  /// Edge-to-edge spacing between the rects that get merged (points).
  final double gap;

  @override
  bool operator ==(Object other) =>
      other is ShapeParams &&
      other.cornerRadius == cornerRadius &&
      other.exponent == exponent &&
      other.mergeSmoothness == mergeSmoothness &&
      other.gap == gap;

  @override
  int get hashCode =>
      Object.hash(cornerRadius, exponent, mergeSmoothness, gap);
}

class ShapeLabPage extends StatefulWidget {
  const ShapeLabPage({super.key});

  @override
  State<ShapeLabPage> createState() => _ShapeLabPageState();
}

class _ShapeLabPageState extends State<ShapeLabPage> {
  static const Size _tile = Size(320, 150);

  double _cornerRadius = 24;
  double _exponent = 2;
  double _mergeSmoothness = 0.2;
  double _gap = 26;
  ViewMode _mode = ViewMode.fill;

  /// Baking is CPU work on the UI thread, so drags run at a quarter of the
  /// texels and the full-resolution bake lands when the finger lifts.
  bool _dragging = false;

  ShapeParams get _params => ShapeParams(
        cornerRadius: _cornerRadius,
        exponent: _exponent,
        mergeSmoothness: _mergeSmoothness,
        gap: _gap,
      );

  @override
  Widget build(BuildContext context) {
    final scale = _dragging ? 0.75 : 1.5;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Shape lab — SDF primitives'),
        backgroundColor: _background,
        actions: [
          IconButton(
            tooltip: 'Continuous rounded rect / capsule, compared',
            icon: const Icon(Icons.rounded_corner),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContinuousComparePage(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  for (final shape in SdfShape.values)
                    _ShapeCard(
                      shape: shape,
                      params: _params,
                      mode: _mode,
                      tile: _tile,
                      scale: scale,
                    ),
                ],
              ),
            ),
            _ControlPanel(
              mode: _mode,
              onMode: (m) => setState(() => _mode = m),
              cornerRadius: _cornerRadius,
              onCornerRadius: (v) => setState(() => _cornerRadius = v),
              exponent: _exponent,
              onExponent: (v) => setState(() => _exponent = v),
              mergeSmoothness: _mergeSmoothness,
              onMergeSmoothness: (v) => setState(() => _mergeSmoothness = v),
              gap: _gap,
              onGap: (v) => setState(() => _gap = v),
              onDragging: (v) => setState(() => _dragging = v),
            ),
          ],
        ),
      ),
    );
  }
}

// ── one card ─────────────────────────────────────────────────────────────

class _ShapeCard extends StatefulWidget {
  const _ShapeCard({
    required this.shape,
    required this.params,
    required this.mode,
    required this.tile,
    required this.scale,
  });

  final SdfShape shape;
  final ShapeParams params;
  final ViewMode mode;
  final Size tile;
  final double scale;

  @override
  State<_ShapeCard> createState() => _ShapeCardState();
}

class _ShapeCardState extends State<_ShapeCard> {
  ui.Image? _image;
  bool _baking = false;
  _BakeKey? _rendered;

  _BakeKey get _wanted => _BakeKey(
        shape: widget.shape,
        params: widget.params,
        mode: widget.mode,
        tile: widget.tile,
        scale: widget.scale,
      );

  @override
  void initState() {
    super.initState();
    _maybeBake();
  }

  @override
  void didUpdateWidget(covariant _ShapeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeBake();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Only one bake in flight; whatever the sliders did meanwhile is picked up
  /// on the way out.
  Future<void> _maybeBake() async {
    if (_baking) return;
    var key = _wanted;
    if (key == _rendered) return;
    _baking = true;
    while (true) {
      final image = await bakeShape(
        shape: key.shape,
        params: key.params,
        mode: key.mode,
        tile: key.tile,
        scale: key.scale,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      _rendered = key;
      setState(() {
        _image?.dispose();
        _image = image;
      });
      key = _wanted;
      if (key == _rendered) break;
    }
    _baking = false;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.shape.title,
            style: const TextStyle(
              color: _accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.shape.formula,
            style: const TextStyle(color: Colors.white38, fontSize: 10.5),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: widget.tile.width,
              height: widget.tile.height,
              child: image == null
                  ? const ColoredBox(color: _tileBackground)
                  : RawImage(
                      image: image,
                      width: widget.tile.width,
                      height: widget.tile.height,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything a bake depends on, so a card can tell when it is stale.
@immutable
class _BakeKey {
  const _BakeKey({
    required this.shape,
    required this.params,
    required this.mode,
    required this.tile,
    required this.scale,
  });

  final SdfShape shape;
  final ShapeParams params;
  final ViewMode mode;
  final Size tile;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is _BakeKey &&
      other.shape == shape &&
      other.params == params &&
      other.mode == mode &&
      other.tile == tile &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(shape, params, mode, tile, scale);
}

/// Rasterizes one shape into an image. The cards' own bake, reachable from
/// outside so a tool or a test can render a shape without a card.
Future<ui.Image> bakeShape({
  required SdfShape shape,
  required ShapeParams params,
  required ViewMode mode,
  required Size tile,
  double scale = 1.5,
}) {
  final w = math.max(2, (tile.width * scale).round());
  final h = math.max(2, (tile.height * scale).round());
  final pixels = _shadeField(_ShapeField(shape, params, tile), w, h, mode);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
      pixels, w, h, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

// ── the fields ───────────────────────────────────────────────────────────

/// One shape, laid out inside a [size]-sized tile and ready to be sampled.
///
/// Everything that does not vary per pixel — the boundary table, the rect
/// list, the clamped radius — is resolved here, so [at] stays tight.
class _ShapeField {
  _ShapeField(this.shape, this.params, this.size)
      : centre = Offset(size.width / 2, size.height / 2),
        blobScale = math.min(size.width, size.height) / 2 - 6,
        quadrant = shape == SdfShape.superellipse
            ? superellipseQuadrantTable(params.exponent)
            : const <Offset>[],
        rects = _rectsFor(shape, params, size) {
    // One radius covers every rect in the group, so the shortest half-extent
    // is the ceiling for all of them.
    var limit = math.min(size.width, size.height) / 2;
    for (final rect in rects) {
      limit = math.min(limit, math.min(rect.width, rect.height) / 2);
    }
    cornerRadius = math.min(params.cornerRadius, limit);
  }

  final SdfShape shape;
  final ShapeParams params;
  final Size size;
  final Offset centre;
  final double blobScale;
  final List<Offset> quadrant;
  final List<Rect> rects;
  late final double cornerRadius;

  double at(Offset point) {
    switch (shape) {
      case SdfShape.circle:
        return circleSdf(point - centre, cornerRadius);
      case SdfShape.superellipse:
        return superellipseSdf(
          point - centre,
          blobScale,
          params.exponent,
          quadrant: quadrant,
        ).distance;
      case SdfShape.superellipseApprox:
        return superellipseApproxSdf(
            point - centre, blobScale, params.exponent);
      case SdfShape.superellipseCorner:
        return superellipseCornerSdf(
            point - centre, cornerRadius, params.exponent);
      case SdfShape.roundedRectangle:
        return roundedRectangleSdf(
            point, rects.first, cornerRadius, params.exponent);
      case SdfShape.smoothUnionPair:
      case SdfShape.mergedTrio:
        // The merged field is resolution-normalized — undo it so the shading
        // below still works in points.
        return primaryShapeSdf(
              point,
              rects,
              cornerRadius: cornerRadius,
              cornerRoundnessExponent: params.exponent,
              shapeMergeSmoothness: params.mergeSmoothness,
              resolutionY: size.height,
            ) *
            size.height;
    }
  }

  static List<Rect> _rectsFor(
      SdfShape shape, ShapeParams params, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    switch (shape) {
      case SdfShape.roundedRectangle:
        return [
          Rect.fromCenter(
            center: centre,
            width: size.width - 28,
            height: size.height - 24,
          ),
        ];
      case SdfShape.smoothUnionPair:
        final side = size.height - 34;
        final offset = _clampOffset(params.gap / 2 + side / 2, size, side);
        return [
          Rect.fromCenter(
              center: centre - Offset(offset, 0), width: side, height: side),
          Rect.fromCenter(
              center: centre + Offset(offset, 0), width: side, height: side),
        ];
      case SdfShape.mergedTrio:
        final side = size.height - 52;
        final offset = _clampOffset(params.gap / 2 + side / 2, size, side);
        return [
          Rect.fromCenter(
              center: centre, width: size.width - 40, height: 36),
          Rect.fromCenter(
              center: centre - Offset(offset, 0), width: side, height: side),
          Rect.fromCenter(
              center: centre + Offset(offset, 0), width: side, height: side),
        ];
      case SdfShape.circle:
      case SdfShape.superellipse:
      case SdfShape.superellipseApprox:
      case SdfShape.superellipseCorner:
        return const [];
    }
  }

  /// Keeps a merged rect inside the tile however wide the gap goes.
  static double _clampOffset(double offset, Size size, double side) =>
      math.min(offset, (size.width - 20 - side) / 2);
}

// ── shading ──────────────────────────────────────────────────────────────

/// Samples [field] over a [w]×[h] texel grid, then paints the distances.
Uint8List _shadeField(_ShapeField field, int w, int h, ViewMode mode) {
  final grid = Float64List(w * h);
  final stepX = field.size.width / w;
  final stepY = field.size.height / h;
  for (var y = 0; y < h; y++) {
    final py = (y + 0.5) * stepY;
    final row = y * w;
    for (var x = 0; x < w; x++) {
      grid[row + x] = field.at(Offset((x + 0.5) * stepX, py));
    }
  }

  final out = Uint8List(w * h * 4);
  final aa = stepX;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final d = grid[i];
      final _Rgb rgb;
      switch (mode) {
        case ViewMode.fill:
          rgb = _shadeFill(d, aa);
        case ViewMode.bands:
          rgb = _shadeBands(d);
        case ViewMode.normals:
          final right = grid[i + (x < w - 1 ? 1 : 0)];
          final left = grid[i - (x > 0 ? 1 : 0)];
          final down = grid[i + (y < h - 1 ? w : 0)];
          final up = grid[i - (y > 0 ? w : 0)];
          rgb = _shadeNormals(d, Offset(right - left, down - up));
      }
      final o = i * 4;
      out[o] = _u8(rgb.r);
      out[o + 1] = _u8(rgb.g);
      out[o + 2] = _u8(rgb.b);
      out[o + 3] = 255;
    }
  }
  return out;
}

const _Rgb _bgRgb = _Rgb(0.063, 0.063, 0.078);
const _Rgb _fillRgb = _Rgb(0.16, 0.44, 0.78);
const _Rgb _edgeRgb = _Rgb(0.44, 0.80, 0.98);
const _Rgb _white = _Rgb(1, 1, 1);

/// Solid shape: brighter towards the rim, one texel of coverage AA.
_Rgb _shadeFill(double d, double aa) {
  final coverage = 1 - _smoothstep(-aa, aa, d);
  final body = _Rgb.lerp(_edgeRgb, _fillRgb, _clamp01(-d / 18));
  var rgb = _Rgb.lerp(_bgRgb, body, coverage);
  final rim = 1 - _smoothstep(0, 2, (d + 0.6).abs());
  return _Rgb.lerp(rgb, _white, rim * 0.85);
}

/// Distance rings — the classic SDF read: cool inside, warm outside, one
/// ring every 14 points, white on the surface.
_Rgb _shadeBands(double d) {
  const period = 14.0;
  final ring = 0.5 + 0.5 * math.cos(d * 2 * math.pi / period);
  final base = d < 0 ? const _Rgb(0.25, 0.62, 0.95) : const _Rgb(0.95, 0.55, 0.15);
  final fade = math.exp(-d.abs() / 110);
  final level = (0.30 + 0.70 * math.pow(ring, 1.7).toDouble()) *
      (0.30 + 0.70 * fade);
  final rgb = _Rgb(base.r * level, base.g * level, base.b * level);
  return _Rgb.lerp(rgb, _white, 1 - _smoothstep(0, 1.6, d.abs()));
}

/// Gradient direction as hue, fading away from the surface.
_Rgb _shadeNormals(double d, Offset gradient) {
  if (gradient.distanceSquared < 1e-18) return _bgRgb;
  final hue = vectorToRainbowColor(gradient);
  final level = 0.12 + 0.88 * math.exp(-d.abs() / 26);
  return _Rgb(hue.r * level, hue.g * level, hue.b * level);
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  static _Rgb lerp(_Rgb a, _Rgb b, double t) => _Rgb(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
      );
}

double _smoothstep(double edge0, double edge1, double v) {
  final t = _clamp01((v - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

int _u8(double v) {
  final r = (v * 255.0).round();
  if (r < 0) return 0;
  if (r > 255) return 255;
  return r;
}

// ── controls ─────────────────────────────────────────────────────────────

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.mode,
    required this.onMode,
    required this.cornerRadius,
    required this.onCornerRadius,
    required this.exponent,
    required this.onExponent,
    required this.mergeSmoothness,
    required this.onMergeSmoothness,
    required this.gap,
    required this.onGap,
    required this.onDragging,
  });

  final ViewMode mode;
  final ValueChanged<ViewMode> onMode;
  final double cornerRadius;
  final ValueChanged<double> onCornerRadius;
  final double exponent;
  final ValueChanged<double> onExponent;
  final double mergeSmoothness;
  final ValueChanged<double> onMergeSmoothness;
  final double gap;
  final ValueChanged<double> onGap;
  final ValueChanged<bool> onDragging;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A20),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<ViewMode>(
              segments: [
                for (final m in ViewMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onMode(s.first),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 2),
              child: Text(
                'roundness ⁿ: 1 diamond · 2 circle · 4 squircle   —   '
                'mergeSmooth ships at 0.2',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
            _SliderRow(
              label: 'cornerRadius',
              value: cornerRadius,
              max: 70,
              onChanged: onCornerRadius,
              onDragging: onDragging,
            ),
            _SliderRow(
              label: 'roundness ⁿ',
              value: exponent,
              min: 1,
              max: 12,
              onChanged: onExponent,
              onDragging: onDragging,
            ),
            _SliderRow(
              label: 'mergeSmooth',
              value: mergeSmoothness,
              max: 1,
              decimals: 3,
              onChanged: onMergeSmoothness,
              onDragging: onDragging,
            ),
            _SliderRow(
              label: 'rect gap',
              value: gap,
              max: 120,
              onChanged: onGap,
              onDragging: onDragging,
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
    required this.value,
    required this.max,
    required this.onChanged,
    required this.onDragging,
    this.min = 0,
    this.decimals = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onDragging;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: _accent,
              onChangeStart: (_) => onDragging(true),
              onChangeEnd: (_) => onDragging(false),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              value.toStringAsFixed(decimals),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
