import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Lens over image — blended.
//
// A photo fills the screen and a few draggable glass shapes float on top, fused
// by a LiquidGlassBlender: drag any two together and they merge into one liquid
// surface (metaball), then pull apart as you separate them. No blur — clear
// refraction over the photo.
//
// The slider is the radius of that bridge. Take it to zero and the bridge is
// gone: the shapes keep their own hard outlines while still sharing one
// surface, one backdrop read and one material.
//
// Wrapped in LiquidGlassView so it works on BOTH backends.
//
//   flutter run -t lib/lens_image_page.dart   (standalone)
//   …or open it from the gallery.
// =============================================================

void main() {
  runApp(const _LensImageApp());
}

class _LensImageApp extends StatelessWidget {
  const _LensImageApp();

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
  const LensImagePage({super.key, this.showCard = true});

  /// Whether the wide text card is part of the cluster. Off, the blend is
  /// just the circle and the squircle.
  final bool showCard;

  @override
  State<LensImagePage> createState() => _LensImagePageState();
}

class _LensImagePageState extends State<LensImagePage> {
  // Busy detail makes the refraction easy to read as the glass passes over it.
  // Served from the project's asset repo (same source as the other demos).
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  // The composition, relative to its own top-left: three shapes placed close
  // enough to start fused. These offsets are the arrangement and never change.
  static const Offset _cardAt = Offset(0, 0);
  static const Offset _circleAt = Offset(20, 100);
  static const Offset _squircleAt = Offset(110, 150);

  // Without the card the same two offsets, re-based on the circle's corner.
  static const Offset _circleAloneAt = Offset(0, 0);
  static const Offset _squircleAloneAt = Offset(90, 50);

  /// The box the shapes occupy together.
  Size get _cluster =>
      widget.showCard ? const Size(250, 290) : const Size(230, 190);

  // Where each shape has been dragged to is NOT page state. A setState per
  // pan update would rebuild this whole view — the background photo, the
  // blender and all three members — on every pointer move, and the glass
  // would trail the finger by however long that takes. LiquidGlassDraggable
  // keeps each offset in its own ValueNotifier and rebuilds only a
  // Transform.translate; the blender reads its members through
  // `getTransformTo`, so the merged outline follows the transform without
  // anything above it rebuilding.

  /// Radius of the metaball bridge. Zero switches it off outright.
  double _smoothness = 58;

  /// The cluster, centred across and a little above centre down the page.
  Offset _origin(Size box) => Offset(
        (box.width - _cluster.width) / 2,
        (box.height - _cluster.height) * 0.38,
      );

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
        child: LayoutBuilder(
          builder: (context, c) {
            final Offset o = _origin(Size(c.maxWidth, c.maxHeight));
            final bool withCard = widget.showCard;
            final Offset card = o + _cardAt;
            final Offset circle = o + (withCard ? _circleAt : _circleAloneAt);
            final Offset squircle =
                o + (withCard ? _squircleAt : _squircleAloneAt);
            return Stack(
              children: [
                Positioned.fill(
                  child: LiquidGlassBlender(
                    smoothness: _smoothness,
                    style: _groupStyle,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (withCard)
                          _draggable(
                            pos: card,
                            size: const Size(248, 120),
                            shape: const LiquidGlassShape
                                .continuousRoundedRectangle(
                              cornerRadius: 32,
                            ),
                            child: const _CardContent(),
                          ),
                        _draggable(
                          pos: circle,
                          size: const Size(120, 120),
                          shape: const LiquidGlassShape.roundedRectangle(
                            cornerRadius: 60,
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: Colors.white, size: 38),
                        ),
                        _draggable(
                          pos: squircle,
                          size: const Size(140, 140),
                          shape:
                              const LiquidGlassShape.squircle(cornerRadius: 40),
                          child: const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 40),
                        ),
                      ],
                    ),
                  ),
                ),
                DemoPanel(
                  title: 'LiquidGlassBlender',
                  children: <Widget>[
                    const Text(
                      'Drag the glass shapes together to blend',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    DemoSlider(
                      label: 'smoothness',
                      value: _smoothness,
                      min: 0,
                      max: 120,
                      onChanged: (double v) => setState(() => _smoothness = v),
                    ),
                    // Zero is a branch, not a small radius: the shader stops
                    // running the smooth union at all.
                    if (_smoothness == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'metaball off — hard union, one surface, one read',
                          style:
                              TextStyle(color: Color(0xFF9BE7C4), fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _draggable({
    required Offset pos,
    required Size size,
    required LiquidGlassShape shape,
    required Widget child,
  }) {
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: size.width,
      height: size.height,
      child: LiquidGlassDraggable(
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
