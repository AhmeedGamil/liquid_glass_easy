// -----------------------------------------------------------------------------
// SOLO vs BATCH vs GROUP — the same lenses, three ways of drawing them.
//
// A field of floating glass lenses over a moving background. Nothing scrolls;
// each lens drifts inside its own cell of an invisible grid, so they are always
// in motion (the raster thread never idles) and never overlap — which is the
// one rule a batch has, and what keeps the three modes comparable.
//
// The three modes differ ONLY in what wraps the lenses:
//
//   SOLO   LiquidGlassBatch(enabled: false)  — every lens reads the backdrop
//                                              for itself. With blur on it
//                                              pushes TWO passes: a blur layer
//                                              below, the shader above.
//   BATCH  LiquidGlassBatch(enabled: true)   — same lenses, same looks, but
//                                              all of them share ONE backdrop
//                                              read, and blur folds into the
//                                              single shader pass.
//   GROUP  LiquidGlassGroup(...)             — the lenses stop being lenses and
//                                              become one merged surface: one
//                                              read, one material, one pass.
//                                              Capped at 8 members.
//
// The tree is otherwise identical between SOLO and BATCH — one boolean apart —
// so any difference in the raster clock is the shared read and nothing else.
//
// HOW TO READ IT
//   1. Run in PROFILE mode. Debug numbers lie, badly.
//          cd example
//          flutter run --profile -t lib/lens_modes_page.dart
//   2. Pick a mode, let it gather a few hundred frames, read "raster avg".
//   3. Switch mode. The window resets itself; wait again. Compare.
//   4. Raster ms is the shader/GPU cost — the number that matters here.
//      Frame total and fps tell you whether it still fits the budget.
//
// The "backdrop reads" line is what the package's code SAYS each mode costs.
// The raster clock is what the device actually does. When they disagree,
// believe the clock.
//
// Note: high SOLO counts are the honest worst case and can get Impeller into
// trouble on some devices — that is the point of the mode, not a bug in it.
// -----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const _LensModesApp());

class _LensModesApp extends StatelessWidget {
  const _LensModesApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LensModesPage(),
    );
  }
}

/// How the lenses on screen are drawn.
enum LensMode {
  /// Each lens on its own — no sharing of any kind.
  solo,

  /// One shared backdrop read, lenses otherwise untouched.
  batch,

  /// One merged surface in place of the individual lenses.
  group,
}

class LensModesPage extends StatefulWidget {
  const LensModesPage({super.key});

  @override
  State<LensModesPage> createState() => _LensModesPageState();
}

class _LensModesPageState extends State<LensModesPage>
    with SingleTickerProviderStateMixin {
  /// The group's shader compares every member per fragment, so it is capped —
  /// mirrored here so the count buttons can never trip the assert.
  static const int _groupMax = LiquidGlassGroup.maxLensCount;
  static const int _groupMin = LiquidGlassGroup.minLensCount;
  static const int _soloMax = 24;

  static const double _blurStep = 4;
  static const double _blurMax = 40;

  late final Ticker _ticker;

  // Rolling window of frame timings (microseconds).
  static const int _window = 600;
  final List<int> _rasterUs = <int>[];
  final List<int> _totalUs = <int>[];

  double _t = 0;
  double _lastHudUpdate = -1;
  String _hud = 'warming up…';

  LensMode _mode = LensMode.solo;
  int _count = 6;
  double _blur = 12;
  bool _moving = true;

  /// Group only: `null` smoothness unions the members hard, a radius makes
  /// them flow together. It is a real cost difference, not just a look.
  bool _fuse = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final ui.FrameTiming t in timings) {
      _rasterUs.add(t.rasterDuration.inMicroseconds);
      _totalUs.add(t.totalSpan.inMicroseconds);
    }
    while (_rasterUs.length > _window) {
      _rasterUs.removeAt(0);
      _totalUs.removeAt(0);
    }
  }

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / 1e6;
    // Refresh the readout a few times a second — recomputing percentiles
    // every frame would itself show up in the numbers.
    if (_t - _lastHudUpdate > 0.33) {
      _lastHudUpdate = _t;
      _hud = _computeHud();
    }
    // Every frame, always: the background animates whether or not the lenses
    // drift, so frames keep arriving at full rate and the window keeps
    // filling. "frozen" then isolates the cost of the lenses MOVING from the
    // cost of the backdrop under them changing.
    if (mounted) setState(() {});
  }

  /// The count actually rendered — the group cannot take more than [_groupMax].
  int get _effectiveCount => _mode == LensMode.group
      ? _count.clamp(_groupMin, _groupMax)
      : _count.clamp(1, _soloMax);

  /// What the package's paint paths say this configuration costs, in backdrop
  /// reads per frame. An expectation from the code, not a measurement.
  String get _expectedReads {
    final int n = _effectiveCount;
    switch (_mode) {
      case LensMode.solo:
        // Blur is a second, separate BackdropFilter stacked under the shader.
        final int perLens = _blur > 0 ? 2 : 1;
        return '${n * perLens}  ($n lenses × $perLens)';
      case LensMode.batch:
        // One key, one read — blur composes into the same pass.
        return '1  (shared by all $n)';
      case LensMode.group:
        return '1  (one merged surface)';
    }
  }

  String _computeHud() {
    if (_rasterUs.length < 10) return 'gathering… (${_rasterUs.length})';
    final List<int> sorted = List<int>.from(_rasterUs)..sort();
    double pct(double p) => sorted[((sorted.length - 1) * p).round()] / 1000.0;

    final double avg =
        _rasterUs.reduce((int a, int b) => a + b) / _rasterUs.length / 1000.0;
    final double totAvg =
        _totalUs.reduce((int a, int b) => a + b) / _totalUs.length / 1000.0;
    final double fps = totAvg > 0 ? 1000.0 / totAvg : 0;
    String f(double v) => v.toStringAsFixed(2);

    return 'RASTER (shader) ms — lower is better\n'
        'avg ${f(avg)}   p50 ${f(pct(0.5))}   '
        'p90 ${f(pct(0.9))}   max ${f(pct(1.0))}\n'
        'frame total ${f(totAvg)} ms  (~${fps.toStringAsFixed(0)} fps)   '
        'samples ${_rasterUs.length}\n'
        'backdrop reads (expected): $_expectedReads';
  }

  void _reset() {
    _rasterUs.clear();
    _totalUs.clear();
    _hud = 'reset — gathering…';
  }

  void _setMode(LensMode mode) {
    setState(() {
      _mode = mode;
      // Snap into the group's range rather than asserting inside the blender.
      if (mode == LensMode.group) {
        _count = _count.clamp(_groupMin, _groupMax);
      }
      _reset();
    });
  }

  void _bumpCount(int delta) {
    final int lo = _mode == LensMode.group ? _groupMin : 1;
    final int hi = _mode == LensMode.group ? _groupMax : _soloMax;
    final int next = (_count + delta).clamp(lo, hi);
    if (next == _count) return;
    setState(() {
      _count = next;
      _reset();
    });
  }

  void _bumpBlur(double delta) {
    final double next = (_blur + delta).clamp(0.0, _blurMax);
    if (next == _blur) return;
    setState(() {
      _blur = next;
      _reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle style = LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 34,
        borderWidth: 1.2,
      ),
      appearance: LiquidGlassAppearance(
        color: const Color(0x14FFFFFF),
        blur: LiquidGlassBlur(sigmaX: _blur, sigmaY: _blur),
      ),
      refraction: const LiquidGlassRefraction(
        magnification: 1.12,
        distortion: 0.55,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          // Keep the field clear of the panel so every lens stays readable.
          final double top = MediaQuery.paddingOf(context).top + 156;
          final Rect field = Rect.fromLTRB(
            10,
            top,
            c.maxWidth - 10,
            c.maxHeight - 10,
          );

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _MovingBackground(t: _t),
              Positioned.fill(child: _glass(style, field)),
              Positioned(left: 0, right: 0, top: 0, child: _panel()),
            ],
          );
        },
      ),
    );
  }

  /// The lenses, wrapped in whichever mode is selected.
  ///
  /// SOLO and BATCH build the identical tree and differ by one boolean, so the
  /// clock is comparing the shared read and nothing else. GROUP replaces the
  /// wrapper entirely — the members hand their glass to one merged surface.
  Widget _glass(LiquidGlassStyle style, Rect field) {
    final Widget lenses = Stack(
      clipBehavior: Clip.none,
      children: _lenses(style, field),
    );

    if (_mode == LensMode.group) {
      return LiquidGlassGroup(
        style: style,
        smoothness: _fuse ? 40 : null,
        child: lenses,
      );
    }
    return LiquidGlassBatch(
      enabled: _mode == LensMode.batch,
      child: lenses,
    );
  }

  List<Widget> _lenses(LiquidGlassStyle style, Rect field) {
    final int n = _effectiveCount;
    final List<Rect> cells = _cells(field, n);
    return <Widget>[
      for (int i = 0; i < n; i++) _floatingLens(style, cells[i], i),
    ];
  }

  /// One lens, drifting inside its own cell.
  ///
  /// The orbit is sized from the slack left over after the lens is placed, so
  /// a lens can never leave its cell and therefore never overlaps a neighbour
  /// — the batch's requirement, and what keeps the modes measuring the same
  /// thing.
  Widget _floatingLens(LiquidGlassStyle style, Rect cell, int index) {
    final double w = cell.width * 0.62;
    final double h = cell.height * 0.62;
    final double orbitX = (cell.width - w) / 2 * 0.85;
    final double orbitY = (cell.height - h) / 2 * 0.85;
    final double phase = index * 1.9;
    final Offset drift = _moving
        ? Offset(
            math.cos(_t * 0.8 + phase) * orbitX,
            math.sin(_t * 1.1 + phase) * orbitY,
          )
        : Offset.zero;
    final Offset centre = cell.center + drift;

    return Positioned(
      left: centre.dx - w / 2,
      top: centre.dy - h / 2,
      width: w,
      height: h,
      child: IgnorePointer(
        child: LiquidGlassLens(
          style: style,
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: math.min(w, h) * 0.28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [n] non-overlapping cells tiling [field], in roughly the field's aspect.
  List<Rect> _cells(Rect field, int n) {
    if (n <= 0 || field.isEmpty) return const <Rect>[];
    final double aspect = field.width / math.max(field.height, 1);
    // Columns in the field's own proportion, so the cells come out roughly
    // square whichever way the phone is held.
    int cols = math.sqrt(n * aspect).round();
    if (cols < 1) cols = 1;
    if (cols > n) cols = n;
    // ceil already gives the fewest rows that hold n, so no row is empty.
    final int rows = (n / cols).ceil();
    final double cw = field.width / cols;
    final double ch = field.height / rows;
    return <Rect>[
      for (int i = 0; i < n; i++)
        Rect.fromLTWH(
          field.left + (i % cols) * cw,
          field.top + (i ~/ cols) * ch,
          cw,
          ch,
        ),
    ];
  }

  // ── Panel ─────────────────────────────────────────────────────────

  Widget _panel() {
    final bool atGroupCap =
        _mode == LensMode.group && _count >= _groupMax;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _hud,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.35,
                fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                _chip('SOLO', _mode == LensMode.solo,
                    () => _setMode(LensMode.solo)),
                _chip('BATCH', _mode == LensMode.batch,
                    () => _setMode(LensMode.batch)),
                _chip('GROUP', _mode == LensMode.group,
                    () => _setMode(LensMode.group)),
                const Spacer(),
                _chip('reset', false, () => setState(_reset)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                _label('lenses'),
                _chip('−', false, () => _bumpCount(-1)),
                _value('$_effectiveCount'),
                _chip('+', false, () => _bumpCount(1)),
                const SizedBox(width: 10),
                _label('blur'),
                _chip('−', false, () => _bumpBlur(-_blurStep)),
                _value(_blur.toStringAsFixed(0)),
                _chip('+', false, () => _bumpBlur(_blurStep)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                _chip(_moving ? 'drifting' : 'frozen', _moving, () {
                  setState(() {
                    _moving = !_moving;
                    _reset();
                  });
                }),
                if (_mode == LensMode.group)
                  _chip(_fuse ? 'fuse 40' : 'fuse off', _fuse, () {
                    setState(() {
                      _fuse = !_fuse;
                      _reset();
                    });
                  }),
                if (atGroupCap)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'group caps at 8',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      );

  Widget _value(String text) => Container(
        width: 30,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
          ),
        ),
      );

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:
                on ? Colors.tealAccent.withValues(alpha: 0.85) : Colors.white24,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// High-frequency detail behind the glass, moving every frame so refraction
/// and blur have something to actually work on.
class _MovingBackground extends StatelessWidget {
  const _MovingBackground({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackgroundPainter(t), size: Size.infinite);
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1B2A6B),
            Color(0xFF7B1F6A),
            Color(0xFFB8501F),
          ],
        ).createShader(Offset.zero & size),
    );
    final Paint stripe = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (double x = -size.height; x < size.width; x += 26) {
      canvas.drawRect(
        Rect.fromLTWH(x + (t * 30) % 26, 0, 10, size.height),
        stripe,
      );
    }
    for (int i = 0; i < 7; i++) {
      final double p = t * 0.5 + i;
      canvas.drawCircle(
        Offset(
          size.width * (0.5 + 0.42 * math.sin(p * 0.7 + i)),
          size.height * (0.5 + 0.42 * math.cos(p * 0.5 + i * 1.3)),
        ),
        50.0 + 22 * math.sin(p),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFD166),
            const Color(0xFF06D6A0),
            (math.sin(p) + 1) / 2,
          )!
              .withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => old.t != t;
}
