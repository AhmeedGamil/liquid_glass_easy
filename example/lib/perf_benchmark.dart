// -----------------------------------------------------------------------------
// PRACTICAL PERF BENCHMARK — highp vs mediump shader test
//
// Gives you a HARD NUMBER for the shader cost, on-device, no DevTools:
//   * One large LiquidGlassLens (the production single-lens shader) is driven
//     with the HEAVIEST settings (optical refraction + wide band + dispersion
//     + magnification) and ANIMATED every frame, so the GPU/raster
//     thread is the bottleneck and the per-pixel shader cost dominates.
//   * A HUD reads ui.FrameTiming.rasterDuration (microseconds, the time the
//     RASTER thread spends — i.e. the shader) and shows avg / p50 / p90 / max
//     over a rolling window.
//
// HOW TO USE
//   1. Run in PROFILE mode (debug numbers lie):
//          cd example
//          flutter run --profile -t lib/perf_benchmark.dart
//   2. Let it run ~10s, tap RESET, let it gather a few hundred frames.
//   3. Write down "raster avg" and "raster p90".
//   4. Flip GLASS_FLOAT_PRECISION to `highp` (or `mediump`) in
//      lib/assets/shaders/liquid_glass_common.glsl, do a FULL rebuild
//      (shaders only recompile on a clean build), and repeat.
//   5. Compare the raster µs. Lower = cheaper. The verdict:
//        < ~8%  difference -> noise, not worth it.
//        > ~10% difference -> real; now judge edge quality by eye.
//
//   Use the + / - buttons to add lenses (heavier) if a single lens already
//   holds 60fps with headroom and you can't see a gap — more lenses pushes
//   the raster thread harder so the per-pixel difference shows up. (Impeller
//   can get unstable past ~4 active lenses, so don't go wild.)
// -----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const _BenchApp());

class _BenchApp extends StatelessWidget {
  const _BenchApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PerfBenchmarkPage(),
    );
  }
}

class PerfBenchmarkPage extends StatefulWidget {
  const PerfBenchmarkPage({super.key});

  @override
  State<PerfBenchmarkPage> createState() => _PerfBenchmarkPageState();
}

class _PerfBenchmarkPageState extends State<PerfBenchmarkPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // Rolling window of raster-thread durations (microseconds).
  static const int _window = 600; // ~5-10s of frames
  final List<int> _rasterUs = <int>[];
  final List<int> _totalUs = <int>[];

  double _t = 0; // animation clock (seconds)
  int _lensCount = 1;

  // HUD snapshot (recomputed ~3x/sec, not every frame).
  String _hud = 'warming up…';
  double _lastHudUpdate = -1;

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
    for (final t in timings) {
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
    // Refresh the HUD text a few times a second so reading it doesn't
    // itself cost a setState every frame.
    if (_t - _lastHudUpdate > 0.33) {
      _lastHudUpdate = _t;
      _hud = _computeHud();
    }
    if (mounted) setState(() {}); // animate the lenses every frame
  }

  String _computeHud() {
    if (_rasterUs.length < 10) return 'warming up… (${_rasterUs.length})';
    final sorted = List<int>.from(_rasterUs)..sort();
    double pct(double p) {
      final idx = ((sorted.length - 1) * p).round();
      return sorted[idx] / 1000.0; // µs -> ms
    }

    final avg = _rasterUs.reduce((a, b) => a + b) / _rasterUs.length / 1000.0;
    final totAvg = _totalUs.reduce((a, b) => a + b) / _totalUs.length / 1000.0;
    final fps = totAvg > 0 ? (1000.0 / totAvg) : 0;
    String f(double v) => v.toStringAsFixed(2);
    return 'RASTER (shader) ms — lower is better\n'
        'avg ${f(avg)}   p50 ${f(pct(0.5))}   '
        'p90 ${f(pct(0.9))}   max ${f(pct(1.0))}\n'
        'frame total avg ${f(totAvg)} ms  (~${fps.toStringAsFixed(0)} fps)\n'
        'samples ${_rasterUs.length}   lenses $_lensCount';
  }

  void _reset() {
    _rasterUs.clear();
    _totalUs.clear();
    _hud = 'reset — gathering…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final size = c.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            const _BusyBackground(),
            // Heavy, animated lenses — the thing under test.
            for (int i = 0; i < _lensCount; i++)
              _animatedLens(size, i),
            _hudPanel(),
          ],
        );
      }),
    );
  }

  // A big lens on the worst-case path: optical refraction, wide edge band,
  // strong dispersion, magnification. Animated so it repaints every
  // frame and the raster thread never idles.
  Widget _animatedLens(Size size, int index) {
    // Each lens sweeps a Lissajous path so they overlap/separate over the
    // background, keeping the refraction continuously busy.
    final phase = index * 1.7;
    final w = math.min(size.width * 0.82, 360.0);
    final h = math.min(size.height * 0.42, 360.0);
    final cx = size.width * 0.5 +
        math.cos(_t * 0.7 + phase) * (size.width * 0.18);
    final cy = size.height * 0.5 +
        math.sin(_t * 0.9 + phase) * (size.height * 0.22);

    return Positioned(
      left: cx - w / 2,
      top: cy - h / 2,
      width: w,
      height: h,
      child: IgnorePointer(
        child: LiquidGlassLens(
          style: const LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: 48,
            ),
            color: Color(0x14FFFFFF),
            magnification: 1.15,
            dispersion: 13.2,
          ),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _hudPanel() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hud,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _btn('RESET', _reset),
                  const SizedBox(width: 8),
                  _btn('- lens', () {
                    if (_lensCount > 1) setState(() => _lensCount--);
                    _reset();
                  }),
                  const SizedBox(width: 8),
                  _btn('+ lens', () {
                    if (_lensCount < 4) setState(() => _lensCount++);
                    _reset();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}

// A high-contrast, detailed background so the refraction has something to
// fetch (and so quality regressions are easy to see).
class _BusyBackground extends StatelessWidget {
  const _BusyBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
        ),
      ),
      child: Stack(
        children: [
          for (int i = 0; i < 18; i++)
            Positioned(
              left: (i * 53 % 360).toDouble(),
              top: (i * 97 % 720).toDouble(),
              child: Container(
                width: 60 + (i % 4) * 24.0,
                height: 60 + (i % 4) * 24.0,
                decoration: BoxDecoration(
                  color: Color.fromARGB(
                      217, (i * 40) % 255, (i * 90) % 255, (i * 140) % 255),
                  shape: i.isEven ? BoxShape.circle : BoxShape.rectangle,
                ),
              ),
            ),
          const Center(
            child: Text(
              'PERF\nBENCH',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
