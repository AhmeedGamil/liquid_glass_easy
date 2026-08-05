import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Corner Styles — three glass lenses side by side, one per
// LiquidGlassCornerStyle (rounded / squircle / continuous), all sharing
// width / height / cornerRadius sliders so you can compare the corner
// curves at any geometry. All three live in ONE LiquidGlassView (one
// capture pipeline, three lenses — under the Impeller multi-lens ceiling).
//
//   flutter run -t lib/corner_style_page.dart   (standalone)
//   …or open it from the home menu.
// =============================================================

void main() => runApp(const _CornerStyleApp());

class _CornerStyleApp extends StatelessWidget {
  const _CornerStyleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const CornerStylePage(),
    );
  }
}

class _Variant {
  final String label;
  final LiquidGlassCornerStyle style;
  const _Variant(this.label, this.style);
}

/// Side-by-side comparison of the three corner styles. Pushable from the
/// home menu.
class CornerStylePage extends StatefulWidget {
  const CornerStylePage({super.key});

  @override
  State<CornerStylePage> createState() => _CornerStylePageState();
}

class _CornerStylePageState extends State<CornerStylePage> {
  final _viewController = LiquidGlassViewController();

  double _width = 92;
  double _height = 120;
  double _radius = 28;

  static const _variants = [
    _Variant('rounded', LiquidGlassCornerStyle.roundedRectangle),
    _Variant('squircle', LiquidGlassCornerStyle.squircle),
    _Variant('continuous', LiquidGlassCornerStyle.continuousRoundedRectangle),
  ];

  @override
  void dispose() {
    _viewController.detach();
    super.dispose();
  }

  LiquidGlassStyle _styleFor(LiquidGlassCornerStyle corner) => LiquidGlassStyle(
        shape: LiquidGlassShape(
          cornerStyle: corner,
          cornerRadius: _radius,
          clipQuality: LiquidGlassClipQuality.exact,
          borderWidth: 1.5,
          lightIntensity: 1.2,
          lightDirection: 39,
          borderType: const OpticalBorder(
            borderSaturation: 1.0,
            ambientIntensity: 1.0,
            borderSolidity: 0.6,
          ),
        ),
        refraction: const LiquidGlassRefraction(
          distortion: 0.1,
          distortionWidth: 24,
          magnification: 0.5
        ),
        appearance: LiquidGlassAppearance(color: Colors.white.withAlpha(20),blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corner Styles'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          LiquidGlassView(
            controller: _viewController,
            backgroundWidget: const _ColorfulBackground(),
            pixelRatio: 1,
            useSync: true,
            realTimeCapture: true,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            child: SafeArea(
              child: Padding(
                // Leave room for the controls panel pinned at the bottom.
                padding: const EdgeInsets.fromLTRB(12, 80, 12, 220),
                child: Center(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 18,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    children: [
                      for (final v in _variants)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: _width,
                              height: _height,
                              child: LiquidGlassLens(style: _styleFor(v.style)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              v.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Crisp controls overlay (not refracted).
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: TunerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TunerPanelTitle('Geometry'),
                    const SizedBox(height: 8),
                    TunerParamSlider('width', _width, 40, 160,
                        _width.round().toString(),
                        (v) => setState(() => _width = v)),
                    TunerParamSlider('height', _height, 40, 220,
                        _height.round().toString(),
                        (v) => setState(() => _height = v)),
                    TunerParamSlider('cornerRadius', _radius, 0, 110,
                        _radius.round().toString(),
                        (v) => setState(() => _radius = v)),
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

/// A detailed photo backdrop so the glass corners have rich content to
/// bend. Falls back to a vivid gradient when the image can't load.
class _ColorfulBackground extends StatelessWidget {
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/neon.png';

  const _ColorfulBackground();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _FallbackGradient(),
      // Hold a solid black backdrop until the first frame decodes, so the
      // glass capture never samples an empty/transparent screen (which Skia
      // would otherwise grab before the photo loads).
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const ColoredBox(color: Colors.black);
      },
    );
  }
}

/// In-code vivid gradient shown if the hosted photo can't load.
class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF5C8A),
            Color(0xFF7C5CFF),
            Color(0xFF2DD4BF),
            Color(0xFF4FB3FF),
          ],
          stops: [0.0, 0.4, 0.7, 1.0],
        ),
      ),
    );
  }
}
