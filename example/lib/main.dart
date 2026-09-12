import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Liquid Glass Easy — headline example: lens over image, blended.
//
// A photo fills the screen and a few draggable glass shapes float on top, fused
// by a LiquidGlassBlender: drag any two together and they merge into one liquid
// surface (metaball), then pull apart as you separate them.
//
// Wrapped in LiquidGlassView so it refracts on BOTH backends — the live backdrop
// on Impeller, the captured backgroundWidget on Skia.
//
// -------------------------------------------------------------------------
// Want the full set of demos shown in the package README (control center,
// slider, toggle, nav bar, corner styles)? They live next to this file in
// example/lib/. Run the gallery with:
//
//     flutter run -t lib/gallery.dart
// -------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compile every glass program before the first frame: the lens's two and
  // the blender's merged-surface entry. Without this the blender below paints
  // nothing until its shader arrives — not even a lone lens's frosted fallback.
  await LiquidGlassShaders.ensureLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LensImagePage(),
    );
  }
}

/// A page showcasing the blend over a photographic background.
class LensImagePage extends StatefulWidget {
  const LensImagePage({super.key});

  @override
  State<LensImagePage> createState() => _LensImagePageState();
}

class _LensImagePageState extends State<LensImagePage> {
  // Busy detail makes the refraction easy to read as the glass passes over it.
  // Served from the project's asset repo (same source as the other demos).
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  // Top-left of each draggable shape — placed close so they start fused.
  Offset _card = const Offset(40, 170);
  Offset _circle = const Offset(60, 270);
  Offset _squircle = const Offset(150, 320);

  // The merged material: clear glass (NO blur), slight tint + saturation, an
  // optical rim and a gentle optical refraction.
  static const _groupStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 36,
      borderWidth: 1.5,
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x14FFFFFF),
      saturation: 1.05,
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    ),
    refraction: LiquidGlassRefraction(
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 24,
        depth: 0.7,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Lens over image'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _imageUrl),
        child: Stack(
          children: [
            Positioned.fill(
              child: LiquidGlassBlender(
                smoothness: 58,
                style: _groupStyle,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _draggable(
                      pos: _card,
                      size: const Size(248, 120),
                      shape: const LiquidGlassShape.continuousRoundedRectangle(
                        cornerRadius: 32,
                      ),
                      onMove: (d) => setState(() => _card += d),
                      child: const _CardContent(),
                    ),
                    _draggable(
                      pos: _circle,
                      size: const Size(120, 120),
                      shape: const LiquidGlassShape.roundedRectangle(
                        cornerRadius: 60,
                      ),
                      onMove: (d) => setState(() => _circle += d),
                      child: const Icon(Icons.favorite_rounded,
                          color: Colors.white, size: 38),
                    ),
                    _draggable(
                      pos: _squircle,
                      size: const Size(140, 140),
                      shape: const LiquidGlassShape.squircle(cornerRadius: 40),
                      onMove: (d) => setState(() => _squircle += d),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: IgnorePointer(
                child: Text(
                  'Drag the glass shapes together to blend',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draggable({
    required Offset pos,
    required Size size,
    required LiquidGlassShape shape,
    required ValueChanged<Offset> onMove,
    required Widget child,
  }) {
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (e) => onMove(e.delta),
        child: LiquidGlassLens(
          style: LiquidGlassStyle(shape: shape),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Liquid Glass',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Refraction over a live photo',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// The refractable background captured by [LiquidGlassView]: the network photo
/// (with a gradient fallback) plus a soft scrim for text legibility.
class _Background extends StatelessWidget {
  final String url;
  const _Background({required this.url});

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Stack(
              fit: StackFit.expand,
              children: [
                _fallback,
                Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x66000000)],
            ),
          ),
        ),
      ],
    );
  }
}
