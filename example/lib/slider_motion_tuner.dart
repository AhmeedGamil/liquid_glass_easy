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
// slider below reacts and any page reading the store picks up the same
// values (in memory, this session).
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

  late double _sampleWindow;
  late double _sensitivity;
  late double _maxDeformation;
  late double _responseTime;

  @override
  void initState() {
    super.initState();
    _seedFrom(TuningStore.instance.slider.value.motion);
  }

  void _seedFrom(LiquidGlassLensMotionSpec m) {
    _sampleWindow = m.sampleWindow;
    _sensitivity = m.sensitivity;
    _maxDeformation = m.maxDeformation;
    _responseTime = m.responseTime;
  }

  LiquidGlassLensMotionSpec get _motion => LiquidGlassLensMotionSpec(
        sampleWindow: _sampleWindow,
        sensitivity: _sensitivity,
        maxDeformation: _maxDeformation,
        responseTime: _responseTime,
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
    sampleWindow: ${_sampleWindow.toStringAsFixed(2)},
    sensitivity: ${_sensitivity.toStringAsFixed(5)},
    maxDeformation: ${_maxDeformation.toStringAsFixed(2)},
    responseTime: ${_responseTime.toStringAsFixed(2)},
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
                          // The shipped default track is black at 8 %,
                          // which disappears on this dark panel.
                          inactiveColor: const Color(0x3CFFFFFF),
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
                    TunerParamSlider('maxDeformation', _maxDeformation, 0, 0.5,
                        _maxDeformation.toStringAsFixed(2),
                        (v) => _update(() => _maxDeformation = v)),
                    TunerParamSlider('sensitivity', _sensitivity, 0, 0.0003,
                        _sensitivity.toStringAsFixed(5),
                        (v) => _update(() => _sensitivity = v)),
                    const Divider(color: Colors.white12, height: 24),
                    TunerParamSlider('sampleWindow', _sampleWindow, 0.05, 0.8,
                        _sampleWindow.toStringAsFixed(2),
                        (v) => _update(() => _sampleWindow = v)),
                    TunerParamSlider('responseTime', _responseTime, 0, 0.6,
                        _responseTime.toStringAsFixed(2),
                        (v) => _update(() => _responseTime = v)),
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
