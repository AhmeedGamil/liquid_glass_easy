import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Minimal test page: a [LiquidGlassView] with a colourful background and
/// THREE [LiquidGlassLens] widgets placed in its `child`, with
/// `useImpellerBackdrop: null` (auto-detect → Impeller, else Skia capture).
///
/// Run directly:
///   flutter run -t lib/three_lens_test.dart                    (Impeller)
///   flutter run -t lib/three_lens_test.dart --no-enable-impeller (Skia)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ThreeLensTestPage(),
    ),
  );
}

class ThreeLensTestPage extends StatefulWidget {
  const ThreeLensTestPage({super.key});

  @override
  State<ThreeLensTestPage> createState() => _ThreeLensTestPageState();
}

class _ThreeLensTestPageState extends State<ThreeLensTestPage> {
  // Each lens: a mutable top-left position (dragged) + fixed size/corner.
  final List<_LensModel> _lenses = [
    _LensModel(pos: const Offset(30, 90), w: 150, h: 150, r: 36, label: '1'),
    _LensModel(pos: const Offset(150, 250), w: 180, h: 110, r: 28, label: '2'),
    _LensModel(pos: const Offset(60, 470), w: 200, h: 130, r: 40, label: '3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        // Auto-detect: prefer Impeller, fall back to Skia capture.

        // The refracted background — bold colours/shapes so refraction is
        // obvious.
        backgroundWidget: const _ColorfulBackground(),

        // Lens-anywhere widgets connect to this view through the scope.
        // Drag any lens to watch the refraction track the background.
        child: Stack(
          children: [
            for (int i = 0; i < _lenses.length; i++)
              Positioned(
                left: _lenses[i].pos.dx,
                top: _lenses[i].pos.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) =>
                      setState(() => _lenses[i].pos += d.delta),
                  child: _Lens(
                    label: _lenses[i].label,
                    width: _lenses[i].w,
                    height: _lenses[i].h,
                    cornerRadius: _lenses[i].r,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LensModel {
  _LensModel({
    required this.pos,
    required this.w,
    required this.h,
    required this.r,
    required this.label,
  });

  Offset pos;
  final double w;
  final double h;
  final double r;
  final String label;
}

class _Lens extends StatelessWidget {
  const _Lens({
    required this.label,
    required this.width,
    required this.height,
    required this.cornerRadius,
  });

  final String label;
  final double width;
  final double height;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: LiquidGlassShape.squircle(
            cornerRadius: cornerRadius,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorfulBackground extends StatelessWidget {
  const _ColorfulBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4FB3FF),
                Color(0xFF7C5CFF),
                Color(0xFFFF5C8A),
                Color(0xFFFFB020),
              ],
            ),
          ),
        ),
        // A few bold shapes so the refraction has hard edges to bend.
        Positioned(
          top: 160,
          left: -40,
          child: _blob(const Color(0xFF2DD4BF), 220),
        ),
        Positioned(
          bottom: 80,
          right: -30,
          child: _blob(const Color(0xFFFFFFFF).withValues(alpha: 0.6), 180),
        ),
        const Center(
          child: Text(
            'BACKGROUND',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
