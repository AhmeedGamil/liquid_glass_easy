import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Scroll-edge blur BENCHMARK — shader vs ladder, raster-thread cost.
//
// BackdropFilter cost lands on the RASTER thread, so `rasterDuration` is
// the number that matters; the UI thread is barely involved. The list is
// scrolled by a ticker every single frame so the backdrop genuinely
// changes and nothing can be cached between frames.
//
// Sweeps every (route, blur) pair, discards a warm-up pass, then prints
// median / p90 / max raster ms per config prefixed with `BENCH|`.
//
// MUST be run in profile mode — debug raster numbers are meaningless:
//   flutter run --profile -t lib/blur_bench.dart
// =============================================================

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const BenchPage(),
      );
}

/// One measured configuration.
class _Cfg {
  final String label;

  /// null = no band at all (the scene's own cost, the baseline every
  /// other row should be read against).
  final bool? shader;
  final double blur;

  const _Cfg(this.label, this.shader, this.blur);
}

const List<_Cfg> _configs = <_Cfg>[
  _Cfg('baseline (no band)', null, 0),
  _Cfg('ladder  blur  4', false, 4),
  _Cfg('shader  blur  4', true, 4),
  _Cfg('ladder  blur 10', false, 10),
  _Cfg('shader  blur 10', true, 10),
  _Cfg('ladder  blur 20', false, 20),
  _Cfg('shader  blur 20', true, 20),
  _Cfg('ladder  blur 40', false, 40),
  _Cfg('shader  blur 40', true, 40),
];

/// Frames measured per config, and frames burned first so shader
/// compilation / texture allocation never lands inside a measurement.
const int _kMeasureFrames = 150;
const int _kWarmFrames = 45;

class BenchPage extends StatefulWidget {
  const BenchPage({super.key});

  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker;

  int _index = 0;
  bool _warming = true;
  final List<double> _samples = <double>[];
  final List<String> _report = <String>[];
  bool _done = false;

  double _offset = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Move the list every frame. A static scene lets the engine reuse
  /// work between frames and would flatter both routes equally wrongly.
  void _tick(Duration _) {
    if (_done || !_scroll.hasClients) return;
    _offset += 6;
    final double max = _scroll.position.maxScrollExtent;
    if (max > 0 && _offset > max) _offset = 0;
    _scroll.jumpTo(_offset);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_done) return;
    for (final FrameTiming t in timings) {
      final double ms = t.rasterDuration.inMicroseconds / 1000.0;
      if (_warming) {
        if (_samples.length + 1 >= _kWarmFrames) {
          _samples.clear();
          _warming = false;
        } else {
          _samples.add(ms);
        }
        continue;
      }
      _samples.add(ms);
      if (_samples.length >= _kMeasureFrames) {
        _finishConfig();
        return;
      }
    }
  }

  void _finishConfig() {
    final List<double> s = List<double>.of(_samples)..sort();
    double pct(double p) => s[(p * (s.length - 1)).round()];
    final double median = pct(0.5);
    final double p90 = pct(0.90);
    final double max = s.last;
    final int over16 = s.where((double v) => v > 16.7).length;

    final _Cfg c = _configs[_index];
    final String line = '${c.label.padRight(20)} '
        'median ${median.toStringAsFixed(2)}ms  '
        'p90 ${p90.toStringAsFixed(2)}ms  '
        'max ${max.toStringAsFixed(2)}ms  '
        'over16.7ms ${(100 * over16 / s.length).toStringAsFixed(0)}%';
    _report.add(line);
    debugPrint('BENCH|$line');

    _samples.clear();
    _warming = true;
    if (_index + 1 >= _configs.length) {
      _done = true;
      _ticker.stop();
      debugPrint('BENCH|--- done, shaderFilter='
          '${ui.ImageFilter.isShaderFilterSupported} '
          'dpr=${MediaQuery.devicePixelRatioOf(context)} ---');
    } else {
      _index++;
    }
    if (mounted) setState(() {});
  }

  static const double _bandHeight = 240;

  @override
  Widget build(BuildContext context) {
    final _Cfg c = _configs[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          _Content(controller: _scroll),
          if (c.shader != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _bandHeight,
              child: LiquidGlassScrollEdge(
                edge: LiquidGlassEdge.bottom,
                blur: c.blur,
                useShaderBlur: c.shader!,
                color: Colors.transparent,
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            top: MediaQuery.paddingOf(context).top + 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF21C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _done
                          ? 'DONE  (${_configs.length} configs)'
                          : 'running ${_index + 1}/${_configs.length}: ${c.label}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    ..._report.map((String r) => Text(r,
                        style: const TextStyle(
                          fontSize: 8.5,
                          height: 1.35,
                          fontFeatures: <ui.FontFeature>[
                            ui.FontFeature.tabularFigures()
                          ],
                        ))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same hostile backdrop as the visual A/B: hard mono edges, fine text,
/// and a smooth colour field.
class _Content extends StatelessWidget {
  final ScrollController controller;

  const _Content({required this.controller});

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 120,
        itemBuilder: (BuildContext context, int i) => switch (i % 4) {
          0 => const _Bars(),
          1 => const _FineText(),
          2 => const _Gradient(),
          _ => const _Headline(),
        },
      );
}

class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 90,
        child: Row(
          children: List<Widget>.generate(
            16,
            (int i) => Expanded(
              child: ColoredBox(color: i.isEven ? Colors.white : Colors.black),
            ),
          ),
        ),
      );
}

class _FineText extends StatelessWidget {
  const _FineText();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: const Text(
          'The tap radius alone carries the falloff, riding the curve from '
          'full blur at the hugged edge down to zero at the inner boundary. '
          'At zero the pass samples each fragment own pixel, so it lands on '
          'the sharp page exactly and no alpha ramp is needed to hide a seam.',
          style: TextStyle(color: Colors.black, fontSize: 11, height: 1.3),
        ),
      );
}

class _Gradient extends StatelessWidget {
  const _Gradient();

  @override
  Widget build(BuildContext context) => Container(
        height: 110,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF0A84FF),
              Color(0xFFBF5AF2),
              Color(0xFFFF375F),
              Color(0xFFFF9F0A),
            ],
          ),
        ),
      );
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: const Text(
          'SHARP EDGES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      );
}
