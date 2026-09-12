import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Motion Pill — LiquidGlassMotionPill on a rail.
//
//   flutter run -t lib/motion_pill_page.dart
//
// The capsule thumb the slider carries, on its own, riding a horizontal
// rail over a photo. Press it and it lifts into glass at its active
// size; drag and it squashes from acceleration, not speed; let go and it
// contracts back where you left it. The page feeds it a `center` and an
// `active` flag per frame — the morph, the squash and the rendering are
// the pill's own.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _MotionPillApp());
}

class _MotionPillApp extends StatelessWidget {
  const _MotionPillApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MotionPillPage(),
    );
  }
}

class MotionPillPage extends StatefulWidget {
  const MotionPillPage({super.key});

  @override
  State<MotionPillPage> createState() => _MotionPillPageState();
}

class _MotionPillPageState extends State<MotionPillPage> {
  /// Where along the rail the pill sits, 0..1.
  double _t = 0.35;
  bool _active = false;
  double _restWidth = 84;
  double _grow = 1.3;

  static const double _restHeight = 46;
  static const double _railInset = 44;

  static const LiquidGlassStyle _glass = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: _restHeight / 2,
      borderWidth: 1.2,
      // Lit from just off the top-left, so the rim brightens along the
      // capsule's leading shoulder rather than dead across its top.
      lightDirection: 39,
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.2,
      distortionWidth: 22,
      magnification: 1.12,
    ),
    appearance: LiquidGlassAppearance(
      shadow: LiquidGlassShadow(blur: 12, opacity: 0.2),
    ),
  );

  void _moveTo(double x, double width) {
    final double x0 = _railInset;
    final double x1 = width - _railInset;
    setState(() => _t = ((x - x0) / (x1 - x0)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const _Rail(),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double railY = c.maxHeight * _Rail.yFraction;
                final double x =
                    _railInset + _t * (c.maxWidth - 2 * _railInset);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent e) {
                    _moveTo(e.localPosition.dx, c.maxWidth);
                    setState(() => _active = true);
                  },
                  onPointerMove: (PointerMoveEvent e) =>
                      _moveTo(e.localPosition.dx, c.maxWidth),
                  onPointerUp: (_) => setState(() => _active = false),
                  onPointerCancel: (_) => setState(() => _active = false),
                  child: LiquidGlassMotionPill(
                    // Only the x moves; the rail fixes the y.
                    center: Offset(x, railY),
                    active: _active,
                    restSize: Size(_restWidth, _restHeight),
                    activeSize: Size(
                      _restWidth * _grow,
                      _restHeight * (1 + (_grow - 1) * 0.5),
                    ),
                    style: _glass,
                    // At rest: a white capsule, crossfading out as the
                    // glass arrives.
                    cover: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                );
              },
            ),
            DemoPanel(
              title: 'LiquidGlassMotionPill',
              children: <Widget>[
                DemoSlider(
                  label: 'rest width',
                  value: _restWidth,
                  min: 56,
                  max: 140,
                  onChanged: (double v) => setState(() => _restWidth = v),
                ),
                DemoSlider(
                  label: 'active ×',
                  value: _grow,
                  min: 1,
                  max: 1.8,
                  decimals: 2,
                  onChanged: (double v) => setState(() => _grow = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo with the rail painted on it, so the pill refracts the rail
/// it rides.
class _Rail extends StatelessWidget {
  const _Rail();

  static const double yFraction = 0.38;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DemoPhoto('neon.png', seed: 0, scrim: 0.22),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) => Stack(
            children: <Widget>[
              Positioned(
                left: _MotionPillPageState._railInset,
                right: _MotionPillPageState._railInset,
                top: c.maxHeight * yFraction - 4,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: c.maxHeight * yFraction - 70,
                child: const Text(
                  'press and drag along the rail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
