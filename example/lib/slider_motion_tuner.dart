import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';
import 'tuning_store.dart';

// =============================================================
// Slider Motion Tuner — a live playground for the LiquidGlassSlider thumb.
//
//   flutter run -t lib/slider_motion_tuner.dart   (standalone)
//   …or open it from the home menu.
//
// Every knob writes into the shared [TuningStore.slider], so the live
// slider below reacts AND the Slider & Toggle page picks up the same
// values (in memory, this session) — tune here, record the GIF there.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SliderTunerApp());
}

class _SliderTunerApp extends StatelessWidget {
  const _SliderTunerApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SliderMotionTunerPage(),
    );
  }
}

/// Live tuner for the [LiquidGlassSlider] thumb's squash & stretch.
/// Writes to
/// [TuningStore.slider]; pushable as its own route from the home menu.
class SliderMotionTunerPage extends StatefulWidget {
  const SliderMotionTunerPage({super.key});

  @override
  State<SliderMotionTunerPage> createState() => _SliderMotionTunerPageState();
}

class _SliderMotionTunerPageState extends State<SliderMotionTunerPage> {
  double _value = 0.5;

  late double _window;
  late double _coefficient;
  late double _maxDeviation;
  late double _responseTau;

  @override
  void initState() {
    super.initState();
    _seedFrom(TuningStore.instance.slider.value.motion);
  }

  void _seedFrom(LiquidGlassLensMotionSpec m) {
    _window = m.window;
    _coefficient = m.coefficient;
    _maxDeviation = m.maxDeviation;
    _responseTau = m.responseTau;
  }

  LiquidGlassLensMotionSpec get _motion => LiquidGlassLensMotionSpec(
        window: _window,
        coefficient: _coefficient,
        maxDeviation: _maxDeviation,
        responseTau: _responseTau,
      );

  /// Applies a local edit then commits it to the shared in-memory store.
  void _update(VoidCallback change) {
    setState(change);
    TuningStore.instance.slider.value = SliderTuning(motion: _motion);
  }

  void _reset() {
    setState(() => _seedFrom(SliderTuning.defaults.motion));
    TuningStore.instance.slider.value = SliderTuning.defaults;
  }

  String get _snippet => '''
LiquidGlassSlider(
  value: _value,
  onChanged: (v) => setState(() => _value = v),
  motion: const LiquidGlassLensMotionSpec(
    window: ${_window.toStringAsFixed(2)},
    coefficient: ${_coefficient.toStringAsFixed(5)},
    maxDeviation: ${_maxDeviation.toStringAsFixed(2)},
    responseTau: ${_responseTau.toStringAsFixed(2)},
  ),
)''';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sliderW = math.min(320.0, width - 96);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slider Motion Tuner'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: TunerGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Live slider — feeds straight off the knobs below.
              TunerCard(
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: TunerPanelTitle('Live slider'),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: SizedBox(
                        width: sliderW,
                        child: LiquidGlassSlider(
                          value: _value,
                          onChanged: (v) => setState(() => _value = v),
                          layout: LiquidGlassSliderLayout(width: sliderW),
                          motion: _motion,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                        'Drag fast, then release — the thumb should jelly.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TunerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TunerPanelTitle('Squash & stretch'),
                    const SizedBox(height: 4),
                    const Text(
                        'Acceleration deforms the thumb: launch stretches it '
                        'wide, braking squashes it tall.',
                        style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 8),
                    TunerParamSlider('maxDeviation', _maxDeviation, 0, 0.5,
                        _maxDeviation.toStringAsFixed(2),
                        (v) => _update(() => _maxDeviation = v)),
                    TunerParamSlider('coefficient', _coefficient, 0, 0.0003,
                        _coefficient.toStringAsFixed(5),
                        (v) => _update(() => _coefficient = v)),
                    const Divider(color: Colors.white12, height: 24),
                    TunerParamSlider('window', _window, 0.05, 0.8,
                        _window.toStringAsFixed(2),
                        (v) => _update(() => _window = v)),
                    TunerParamSlider('responseTau', _responseTau, 0, 0.6,
                        _responseTau.toStringAsFixed(2),
                        (v) => _update(() => _responseTau = v)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TunerCodeCard(snippet: _snippet, onReset: _reset),
            ],
          ),
        ),
      ),
    );
  }
}
