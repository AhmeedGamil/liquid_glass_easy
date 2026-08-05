import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Blue Sliders showcase — a page of LiquidGlassSlider controls whose
// filled (left) portion is blue, on a slimmer track.
//
//   flutter run -t lib/blue_sliders_page.dart   (standalone)
//   …or push BlueSlidersPage() from the home menu.
// =============================================================

/// Blue colour used for the filled portion of every slider.
const Color kSliderBlue = Color(0xFF0A84FF);

/// Slimmer track than the default 8px.
const double kSliderTrackHeight = 6;

/// Glass thumb look with **no blur**. The tuned default thumb style bakes
/// in a `LiquidGlassBlur(1.5, 1.5)`; passing an explicit style replaces
/// the whole default, so we restate the tuned tint + refraction here and
/// only zero out the blur (default `LiquidGlassBlur()` is sigma 0).
const LiquidGlassStyle kNoBlurThumb = LiquidGlassStyle(
  // No border on the thumb (borderWidth: 0). A large cornerRadius keeps it a
  // clean capsule as the pill grows/jellies (it clamps to half-height).
  shape: LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: 100,
    borderWidth: 0.4,
    lightIntensity: 1,
    lightDirection: 80,
    borderType: OpticalBorder(
      borderSaturation: 1,
      ambientIntensity: 1.0,
      borderSolidity: 0.5,
    ),
  ),
  appearance: LiquidGlassAppearance(
    color: Colors.transparent, // white, alpha 28 — same as the tuned default
    blur: LiquidGlassBlur(sigmaX: 0.5, sigmaY: 0.5), // sigmaX/Y = 0 → no blur
  ),
  refraction: LiquidGlassRefraction(
    distortion: 0.05,
    distortionWidth: 18,
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TEMP DIAGNOSTIC: the run console collapses repeated framework errors to
  // a useless one-liner ("Another exception was thrown: … line 6417"). This
  // force-prints the FULL details + stack of the first few errors so we can
  // finally see what actually trips the assertion. Remove once diagnosed.
  final prevOnError = FlutterError.onError;
  var dumped = 0;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (dumped < 3) {
      dumped++;
      debugPrint('\n===== LIQUID GLASS FULL ERROR #$dumped =====');
      debugPrint('library: ${details.library}');
      debugPrint('exception: ${details.exceptionAsString()}');
      debugPrintStack(stackTrace: details.stack, maxFrames: 80);
      debugPrint('===== END FULL ERROR #$dumped =====\n');
    }
    prevOnError?.call(details);
  };

  runApp(const _BlueSlidersApp());
}

class _BlueSlidersApp extends StatelessWidget {
  const _BlueSlidersApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const BlueSlidersPage(),
    );
  }
}

/// A showcase page of glass sliders with a blue filled track.
class BlueSlidersPage extends StatefulWidget {
  const BlueSlidersPage({super.key});

  @override
  State<BlueSlidersPage> createState() => _BlueSlidersPageState();
}

class _BlueSlidersPageState extends State<BlueSlidersPage> {
  double _brightness = 0.65;
  double _volume = 0.4;
  double _warmth = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blue Sliders'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: TunerGradientBackground(
        child: SafeArea(
          // Derive the slider width from layout constraints, NOT
          // MediaQuery: a `MediaQuery.sizeOf` dependency here would make
          // the whole page (every LiquidGlassView) rebuild when MediaQuery
          // settles on the first frame, tripping the InheritedElement
          // "descendant" assertion mid-capture. LayoutBuilder uses the
          // relayout path instead, so the glass subtree isn't notified.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Guard the first (warm-up) frame: the surface width can be 0
              // (see "Width is zero" in the engine log), and `0 - 96` is a
              // NEGATIVE width that crashes _SliderRow's SizedBox — which the
              // framework then re-reports as the `framework.dart:6417`
              // "descendant" assertion. Clamp so the width is never < 0.
              final maxW =
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 392.0;
              final sliderW = math.min(300.0, math.max(0.0, maxW - 96));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TunerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TunerPanelTitle('Sliders'),
                        const SizedBox(height: 14),
                        _SliderRow(Icons.light_mode_rounded, 'Brightness',
                            _brightness, sliderW,
                            (v) => setState(() => _brightness = v)),
                        _SliderRow(Icons.volume_up_rounded, 'Volume', _volume,
                            sliderW, (v) => setState(() => _volume = v)),
                        _SliderRow(Icons.thermostat_rounded, 'Warmth', _warmth,
                            sliderW, (v) => setState(() => _warmth = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Drag the sliders',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
                ],
              );
            },
          ),
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
  final ValueChanged<double> onChanged;

  const _SliderRow(
      this.icon, this.label, this.value, this.width, this.onChanged);

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
                      color: kSliderBlue)),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: width,
              child: LiquidGlassSlider(
                value: value,
                onChanged: onChanged,
                // Blue filled (left) portion + a slimmer track.
                activeColor: kSliderBlue,
                // No blur on the moving glass thumb.
                style: kNoBlurThumb,
                layout: LiquidGlassSliderLayout(
                  width: width,
                  trackHeight: kSliderTrackHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
