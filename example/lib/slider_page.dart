import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// The slider's own default active colour, restated so the readout
/// percentage can be tinted to match the fill.
const Color _kSliderBlue = Color(0xFF0A84FF);

// =============================================================
// Slider showcase — LiquidGlassSlider, the glass thumb carried along a
// track, standalone so nothing in the gallery changes.
//
//   flutter run -t lib/slider_page.dart
//
// The same thumb the sliding switch carries between its two rest
// positions — see `switch_page.dart`.
//
// What to try:
//   • Drag a thumb. It stretches as it launches and squashes as it
//     brakes into a stop, on acceleration rather than speed.
//   • Tap anywhere on a track. The thumb travels there and lands with
//     the same squash a drag-release gives it.
//   • Press and hold without moving. The thumb lifts into glass and
//     stays there until you let go.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SliderApp());
}

class _SliderApp extends StatelessWidget {
  const _SliderApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const SliderPage(),
    );
  }
}

class SliderPage extends StatefulWidget {
  const SliderPage({super.key});

  @override
  State<SliderPage> createState() => _SliderPageState();
}

class _SliderPageState extends State<SliderPage> {
  double _brightness = 0.65;
  double _volume = 0.4;
  double _warmth = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A flat off-white behind the glass — dimmed rather than pure
          // white, so the thumb's rim and shadow still have something to
          // sit against.
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFE9E9EC)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              children: [
                const Text(
                  'Sliders',
                  style: TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Drag the thumb — it deforms on force, not speed.',
                  style: TextStyle(color: Color(0x9911131A), fontSize: 14),
                ),
                const SizedBox(height: 26),
                _card([
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Derive the width from constraints, never MediaQuery:
                      // a MediaQuery dependency here rebuilds every
                      // LiquidGlassView when it settles on the first frame,
                      // mid-capture. Clamp at 0 too — the warm-up frame can
                      // report a zero width, and a negative SizedBox width
                      // takes the whole glass subtree down with it.
                      final double avail = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : 300.0;
                      final double w = math.max(0.0, math.min(360.0, avail));
                      return Column(
                        children: [
                          _sliderRow(
                              Icons.light_mode_rounded,
                              'Brightness',
                              _brightness,
                              w,
                              (v) => setState(() => _brightness = v)),
                          _divider(),
                          _sliderRow(Icons.volume_up_rounded, 'Volume', _volume,
                              w, (v) => setState(() => _volume = v)),
                          _divider(),
                          _sliderRow(Icons.thermostat_rounded, 'Warmth',
                              _warmth, w, (v) => setState(() => _warmth = v)),
                        ],
                      );
                    },
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: Colors.black.withValues(alpha: 0.07),
      );

  Widget _sliderRow(
    IconData icon,
    String label,
    double value,
    double width,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: Colors.black.withValues(alpha: 0.75)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: _kSliderBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: width,
              // Only the width is this page's: the blue fill, the faint
              // track, the clear unblurred thumb and its inset contact
              // shadow are all the shipped defaults now.
              child: LiquidGlassSlider(
                value: value,
                onChanged: onChanged,
                layout: LiquidGlassSliderLayout(width: width),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
