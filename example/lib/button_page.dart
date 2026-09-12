import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Button — two LiquidGlassButtons that flex under the finger.
//
//   flutter run -t lib/button_page.dart
//
// A round one and a wide one over a photo. Both carry a `touch` with the
// default LiquidGlassFlex, so a press sinks them slightly and a drag
// stretches the glass toward the finger before it springs back — the same
// soft body any lens can wear.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ButtonApp());
}

class _ButtonApp extends StatelessWidget {
  const _ButtonApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const ButtonPage(),
    );
  }
}

class ButtonPage extends StatefulWidget {
  const ButtonPage({super.key});

  @override
  State<ButtonPage> createState() => _ButtonPageState();
}

class _ButtonPageState extends State<ButtonPage> {
  int _liked = 0;
  int _added = 0;

  /// The stock soft body: press to sink, drag to stretch, release to spring.
  static const LiquidGlassTouch _touch =
      LiquidGlassTouch.flexing(LiquidGlassFlex());

  static const LiquidGlassStyle _round = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 44, borderWidth: 1.2),
    appearance: LiquidGlassAppearance(color: Color(0x1AFFFFFF)),
    refraction: LiquidGlassRefraction(distortion: 0.2, distortionWidth: 32),
  );

  static const LiquidGlassStyle _wide = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 32,
      borderWidth: 1.2,
    ),
    appearance: LiquidGlassAppearance(color: Color(0x1AFFFFFF)),
    refraction: LiquidGlassRefraction(distortion: 0.16, distortionWidth: 38),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const DemoPhoto('flower.jpg', seed: 2),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Align(
              alignment: const Alignment(0, -0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Round: icon only, as wide as it is tall, corners at
                  // half the size so the capsule closes into a circle.
                  LiquidGlassButton(
                    icon: Icons.favorite_rounded,
                    width: 88,
                    height: 88,
                    iconSize: 34,
                    padding: EdgeInsets.zero,
                    style: _round,
                    touch: _touch,
                    onPressed: () => setState(() => _liked++),
                  ),
                  const SizedBox(height: 34),
                  // Wide: icon and label on one long capsule.
                  LiquidGlassButton(
                    icon: Icons.add_rounded,
                    label: 'Add to library',
                    width: 340,
                    height: 64,
                    fontSize: 17,
                    style: _wide,
                    touch: _touch,
                    onPressed: () => setState(() => _added++),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'liked $_liked   ·   added $_added',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Press and hold, then pull sideways.',
                    style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
