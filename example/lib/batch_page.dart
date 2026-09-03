// -----------------------------------------------------------------------------
// BATCH — many lenses, one backdrop read.
//
// A scrolling wall of glass cards over a moving background, with the raster
// HUD from the perf benchmark. Flip BATCH off and every card reads the
// backdrop for itself; flip it on and LiquidGlassBatch gives them all one
// shared read. The raster ms is the number to watch.
//
// Run it on its own (profile mode — debug numbers lie):
//     cd example
//     flutter run --profile -t lib/batch_page.dart
// -----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const _BatchApp());

class _BatchApp extends StatelessWidget {
  const _BatchApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BatchPage(),
    );
  }
}

class BatchPage extends StatefulWidget {
  const BatchPage({super.key});

  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // Rolling window of raster-thread durations (microseconds).
  static const int _window = 600;
  final List<int> _rasterUs = <int>[];
  final List<int> _totalUs = <int>[];

  double _t = 0;
  double _lastHudUpdate = -1;
  String _hud = 'warming up…';

  bool _batched = true;
  bool _blur = true;
  int _cardCount = 8;

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
    if (_t - _lastHudUpdate > 0.33) {
      _lastHudUpdate = _t;
      _hud = _computeHud();
    }
    if (mounted) setState(() {});
  }

  String _computeHud() {
    if (_rasterUs.length < 10) return 'warming up… (${_rasterUs.length})';
    final List<int> sorted = List<int>.from(_rasterUs)..sort();
    double pct(double p) => sorted[((sorted.length - 1) * p).round()] / 1000.0;
    final double avg =
        _rasterUs.reduce((int a, int b) => a + b) / _rasterUs.length / 1000.0;
    final double totAvg =
        _totalUs.reduce((int a, int b) => a + b) / _totalUs.length / 1000.0;
    String f(double v) => v.toStringAsFixed(2);
    return 'raster ms — avg ${f(avg)}  p50 ${f(pct(0.5))}  p90 ${f(pct(0.9))}\n'
        'frame ${f(totAvg)} ms (~${(totAvg > 0 ? 1000 / totAvg : 0).toStringAsFixed(0)} fps)'
        '   samples ${_rasterUs.length}';
  }

  void _reset() {
    _rasterUs.clear();
    _totalUs.clear();
    _hud = 'reset — gathering…';
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle cardStyle = LiquidGlassStyle(
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: 28,
        borderWidth: 1.2,
      ),
      appearance: LiquidGlassAppearance(
        color: const Color(0x14FFFFFF),
        blur: _blur
            ? const LiquidGlassBlur(sigmaX: 12, sigmaY: 12)
            : const LiquidGlassBlur(sigmaX: 0, sigmaY: 0),
      ),
      refraction: const LiquidGlassRefraction(
        magnification: 1.12,
        distortion: 0.55,
      ),
    );

    // The cards, laid out so no two of them overlap — the batch's one rule.
    // The first one is kept OUT of the batch: it reads the backdrop on its
    // own while every card below it shares the batch's single read.
    final Widget cards = ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 140, 16, 40),
      itemCount: _cardCount,
      itemBuilder: (BuildContext context, int i) {
        final bool excluded = i == 0;
        final Widget card = LiquidGlassLens(
          style: cardStyle,
          child: Center(
            child: Text(
              excluded ? 'card 1 · excluded' : 'card ${i + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            height: 104,
            child: excluded ? LiquidGlassBatch.exclude(child: card) : card,
          ),
        );
      },
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _MovingBackground(t: _t),
          // Android's stretch overscroll isolates the scrollable into its own
          // layer, which blinds every backdrop lens inside it.
          ScrollConfiguration(
            behavior:
                const MaterialScrollBehavior().copyWith(overscroll: false),
            // The whole point: one wrapper, any number of lenses inside it.
            child: LiquidGlassBatch(enabled: _batched, child: cards),
          ),
          Positioned(left: 0, right: 0, top: 0, child: _panel()),
        ],
      ),
    );
  }

  Widget _panel() {
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
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                _chip(
                  _batched ? 'BATCH ON' : 'BATCH OFF',
                  _batched,
                  () => setState(() {
                    _batched = !_batched;
                    _reset();
                  }),
                ),
                _chip(
                  _blur ? 'blur 12' : 'blur 0',
                  _blur,
                  () => setState(() {
                    _blur = !_blur;
                    _reset();
                  }),
                ),
                _chip('−', false, () {
                  if (_cardCount > 1) {
                    setState(() {
                      _cardCount--;
                      _reset();
                    });
                  }
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('$_cardCount',
                      style: const TextStyle(color: Colors.white)),
                ),
                _chip('+', false, () {
                  setState(() {
                    _cardCount++;
                    _reset();
                  });
                }),
                _chip('reset', false, () => setState(_reset)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Colors.tealAccent.withValues(alpha: 0.85) : Colors.white24,
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

/// Something with high-frequency detail behind the glass, moving every frame
/// so the raster thread keeps working and the HUD keeps reading.
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
          colors: <Color>[Color(0xFF1B2A6B), Color(0xFF7B1F6A), Color(0xFFB8501F)],
        ).createShader(Offset.zero & size),
    );
    // Stripes + blobs: fine detail is what makes refraction and blur visible.
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
