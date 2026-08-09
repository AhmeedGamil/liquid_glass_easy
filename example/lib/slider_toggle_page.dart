import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';
import 'tuning_store.dart';

// =============================================================
// Slider & Toggle showcase — a gallery of live LiquidGlassSlider and
// LiquidGlassToggle controls. The sliders read their jelly from the
// shared [TuningStore.slider], so values dialled in the Slider Motion
// Tuner show up here (great for a clean GIF). The toggle has no jelly
// knob — it's showcased as-is.
//
//   flutter run -t lib/slider_toggle_page.dart   (standalone)
//   …or open it from the home menu.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SliderToggleApp());
}

class _SliderToggleApp extends StatelessWidget {
  const _SliderToggleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SliderTogglePage(),
    );
  }
}

/// A showcase page of glass sliders + toggles. Pushable from the home menu.
class SliderTogglePage extends StatefulWidget {
  const SliderTogglePage({super.key});

  @override
  State<SliderTogglePage> createState() => _SliderTogglePageState();
}

class _SliderTogglePageState extends State<SliderTogglePage> {
  double _brightness = 0.65;
  double _volume = 0.4;
  double _warmth = 0.8;

  bool _wifi = true;
  bool _bluetooth = false;
  bool _silent = true;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sliderW = math.min(300.0, width - 96);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slider & Toggle'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: TunerGradientBackground(
        // Rebuild the sliders whenever the slider tuning changes so the
        // tuner's values flow in live.
        child: ValueListenableBuilder<SliderTuning>(
          valueListenable: TuningStore.instance.slider,
          builder: (context, tuning, _) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TunerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TunerPanelTitle('Sliders'),
                        const SizedBox(height: 14),
                        _SliderRow(
                            Icons.light_mode_rounded,
                            'Brightness',
                            _brightness,
                            sliderW,
                            tuning.motion,
                            (v) => setState(() => _brightness = v)),
                        _SliderRow(Icons.volume_up_rounded, 'Volume', _volume,
                            sliderW, tuning.motion,
                            (v) => setState(() => _volume = v)),
                        _SliderRow(Icons.thermostat_rounded, 'Warmth', _warmth,
                            sliderW, tuning.motion,
                            (v) => setState(() => _warmth = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TunerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TunerPanelTitle('Toggles'),
                        const SizedBox(height: 6),
                        _ToggleRow(Icons.wifi_rounded, 'Wi-Fi', _wifi,
                            (v) => setState(() => _wifi = v)),
                        _ToggleRow(Icons.bluetooth_rounded, 'Bluetooth',
                            _bluetooth, (v) => setState(() => _bluetooth = v)),
                        _ToggleRow(Icons.nightlight_round, 'Silent mode',
                            _silent, (v) => setState(() => _silent = v),
                            activeColor: kTunerAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Drag the sliders and flip the switches',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double width;
  final LiquidGlassLensMotionSpec motion;
  final ValueChanged<double> onChanged;

  const _SliderRow(this.icon, this.label, this.value, this.width, this.motion,
      this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
              const Spacer(),
              Text('${(value * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTunerAccent)),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: width,
              child: LiquidGlassSlider(
                value: value,
                onChanged: onChanged,
                layout: LiquidGlassSliderLayout(width: width),
                motion: motion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _ToggleRow(this.icon, this.label, this.value, this.onChanged,
      {this.activeColor = const Color(0xFF34C759)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 14.5, color: Colors.white)),
          const Spacer(),
          LiquidGlassToggle(
            layout: LiquidGlassToggleLayout(pinchedHeight: 20),
            value: value,
            style: LiquidGlassStyle(
              shape: LiquidGlassShape.continuousRoundedRectangle(borderWidth: 0.3,lightDirection: 39, borderType: OpticalBorder(lightSpread: 0.3,borderSaturation: 0,)),
              refraction: LiquidGlassRefraction(
                magnification: 1,
                distortion: 0.05,
                distortionWidth: 10,
                chromaticAberration: 0.003
              ),
              appearance: LiquidGlassAppearance(
                //color: Colors.white.withOpacity(0.15),
                blur: const LiquidGlassBlur(sigmaX: 0.7, sigmaY: 0.7),
              ),
            ),
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }
}
