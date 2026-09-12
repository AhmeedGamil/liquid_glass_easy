import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Lens — one LiquidGlassLens over a photo, and the style that shapes it.
//
//   flutter run -t lib/lens_page.dart
//
// A single draggable lens inside a LiquidGlassView. The panel drives a
// LiquidGlassStyle: the corner style of the shape, the blur of the
// appearance, and the two numbers of the refraction band — how far it
// bends and how wide it is. Drag the glass across the photo to read them.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LensApp());
}

class _LensApp extends StatelessWidget {
  const _LensApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LensPage(),
    );
  }
}

class LensPage extends StatefulWidget {
  /// Whether the style panel rides along the bottom.
  ///
  /// The docs site shows this page twice: with the panel, as the lens
  /// documentation, and without it — a lens over a photo and nothing else —
  /// as the landing hero.
  final bool showControls;

  const LensPage({super.key, this.showControls = true});

  @override
  State<LensPage> createState() => _LensPageState();
}

class _LensPageState extends State<LensPage> {
  LiquidGlassCornerStyle _corner =
      LiquidGlassCornerStyle.continuousRoundedRectangle;
  double _blur = 0;
  double _distortion = 0.11;
  double _width = 40;

  // Where the lens has been dragged to is NOT page state. A setState per
  // pan update would rebuild this whole LiquidGlassView — background image
  // included — on every pointer move, and the glass would trail the finger
  // by however long that takes. LiquidGlassDraggable keeps the offset in its
  // own ValueNotifier and rebuilds a Transform.translate, so the lens
  // subtree runs its pipeline once and the renderer resolves its sampling
  // rect through the layer transform.

  /// Traffic light trails at night: long straight strokes of magenta and
  /// cyan on dark. Straight lines are the readable test of a refraction
  /// band — you see exactly where the glass bends them and by how much.
  static const String _backdrop =
      'https://images.unsplash.com/photo-1485001564903-56e6a54d46ef'
      '?auto=format&fit=crop&w=1100&q=72';

  static const Size _size = Size(280, 176);

  /// Centred across, and a little above centre down the page so the panel at
  /// the bottom has room — dead centre when there is no panel.
  Offset _start(Size box) => Offset(
        (box.width - _size.width) / 2,
        (box.height - _size.height) * (widget.showControls ? 0.36 : 0.5),
      );

  static const Map<LiquidGlassCornerStyle, String> _cornerNames =
      <LiquidGlassCornerStyle, String>{
    LiquidGlassCornerStyle.roundedRectangle: 'rounded',
    LiquidGlassCornerStyle.squircle: 'squircle',
    LiquidGlassCornerStyle.continuousRoundedRectangle: 'continuous',
  };

  LiquidGlassStyle get _style => LiquidGlassStyle(
        shape: LiquidGlassShape(
          cornerStyle: _corner,
          cornerRadius: 44,
          borderWidth: 1.4,
        ),
        appearance: LiquidGlassAppearance(
          blur: LiquidGlassBlur(sigmaX: _blur, sigmaY: _blur),
          color: const Color(0x12FFFFFF),
        ),
        refraction: LiquidGlassRefraction(
          distortion: _distortion,
          distortionWidth: _width,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const DemoPhoto(_backdrop, seed: 0, scrim: 0.06),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Offset pos = _start(Size(c.maxWidth, c.maxHeight));
            return Stack(
              children: <Widget>[
                Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  width: _size.width,
                  height: _size.height,
                  child: LiquidGlassDraggable(
                    child: LiquidGlassLens(
                      style: _style,
                      child: const Center(
                        child: Text(
                          'LiquidGlassLens',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.showControls)
                  DemoPanel(
                    title: 'LiquidGlassStyle',
                    children: <Widget>[
                      DemoChips<LiquidGlassCornerStyle>(
                        values: _cornerNames.keys.toList(),
                        selected: _corner,
                        label: (LiquidGlassCornerStyle c) => _cornerNames[c]!,
                        onChanged: (LiquidGlassCornerStyle c) =>
                            setState(() => _corner = c),
                      ),
                      const SizedBox(height: 6),
                      DemoSlider(
                        label: 'blur',
                        value: _blur,
                        min: 0,
                        max: 14,
                        onChanged: (double v) => setState(() => _blur = v),
                      ),
                      DemoSlider(
                        label: 'distortion',
                        value: _distortion,
                        min: 0,
                        max: 0.4,
                        decimals: 2,
                        onChanged: (double v) => setState(() => _distortion = v),
                      ),
                      DemoSlider(
                        label: 'distortion width',
                        value: _width,
                        min: 6,
                        max: 90,
                        onChanged: (double v) => setState(() => _width = v),
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
}
