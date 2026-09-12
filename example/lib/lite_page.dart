import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Lite glass — the material without the shader.
//
//   flutter run -t lib/lite_page.dart
//
// No LiquidGlassView, no shader, no capture. Two draggable surfaces over a
// painted backdrop, both lite glass by different routes: the card IS a
// LiquidGlassLite, and the round button is an ordinary LiquidGlassLens whose
// style names its lite rim in `liteGlass`, which draws the same thing. The
// panel drives what a lite surface is made of — the frost, the flat
// magnification, the tint, the rim — and where the rim takes its colour
// from, on both surfaces at once.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LiteApp());
}

class _LiteApp extends StatelessWidget {
  const _LiteApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LitePage(),
    );
  }
}

class LitePage extends StatefulWidget {
  const LitePage({super.key});

  @override
  State<LitePage> createState() => _LitePageState();
}

class _LitePageState extends State<LitePage> {
  LiquidGlassLitePickup _pickup = LiquidGlassLitePickup.backdrop;
  double _blur = 3;
  double _magnification = 1.0;
  int _tint = 1;
  double _border = 1.5;

  /// The tints on offer. `null` is no tint at all.
  static const List<(String, Color?)> _tints = <(String, Color?)>[
    ('no tint', null),
    ('white', Color(0x33FFFFFF)),
    ('ink', Color(0x40000000)),
    ('blue', Color(0x59104BE0)),
  ];

  static const Size _card = Size(264, 148);
  static const double _button = 68;

  // Where the surfaces have been dragged to is NOT page state: a setState
  // per pan update would rebuild this whole view on every pointer move.
  // LiquidGlassDraggable keeps each offset in its own ValueNotifier.

  Offset _cardAt(Size box) => Offset(
        (box.width - _card.width) / 2,
        (box.height - _card.height) * 0.30,
      );
  Offset _buttonAt(Size box) => Offset(
        (box.width + _card.width) / 2 - _button,
        (box.height - _card.height) * 0.30 + _card.height + 28,
      );

  Color? get _color => _tints[_tint].$2;

  LiquidGlassBlur get _frost => LiquidGlassBlur(sigmaX: _blur, sigmaY: _blur);

  LiquidGlassShape _shape(double radius) =>
      LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: radius,
        borderWidth: _border,
        lightDirection: 39,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: DemoBackdrop(seed: 2)),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Size box = Size(c.maxWidth, c.maxHeight);
              final Offset card = _cardAt(box);
              final Offset button = _buttonAt(box);
              return Stack(
                children: <Widget>[
                  // The widget itself, with every knob on it.
                  Positioned(
                    left: card.dx,
                    top: card.dy,
                    width: _card.width,
                    height: _card.height,
                    child: LiquidGlassDraggable(
                      child: LiquidGlassLite(
                        shape: _shape(34),
                        blur: _frost,
                        magnification: _magnification,
                        pickup: _pickup,
                        color: _color,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'LiquidGlassLite',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No shader behind this',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The same material by the other route: a lens whose style
                  // names the pickup in `liteGlass`, so the same chips move
                  // its rim and the card's together.
                  Positioned(
                    left: button.dx,
                    top: button.dy,
                    width: _button,
                    height: _button,
                    child: LiquidGlassDraggable(
                      child: LiquidGlassLens(
                        style: LiquidGlassStyle(
                          liteGlass: _pickup,
                          shape: _shape(_button / 2),
                          appearance: LiquidGlassAppearance(
                            color: _color ?? Colors.transparent,
                            blur: _frost,
                          ),
                          refraction: LiquidGlassRefraction(
                            magnification: _magnification,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_rounded,
                              color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: DemoHeader(title: 'Lite glass'),
                    ),
                  ),
                  DemoPanel(
                    title: 'LiquidGlassLite',
                    children: <Widget>[
                      DemoChips<LiquidGlassLitePickup>(
                        values: LiquidGlassLitePickup.values,
                        selected: _pickup,
                        label: (LiquidGlassLitePickup v) => 'rim: ${v.name}',
                        onChanged: (LiquidGlassLitePickup v) =>
                            setState(() => _pickup = v),
                      ),
                      const SizedBox(height: 6),
                      DemoChips<int>(
                        values: List<int>.generate(_tints.length, (int i) => i),
                        selected: _tint,
                        label: (int i) => _tints[i].$1,
                        onChanged: (int i) => setState(() => _tint = i),
                      ),
                      const SizedBox(height: 6),
                      DemoSlider(
                        label: 'blur',
                        value: _blur,
                        min: 0,
                        max: 12,
                        onChanged: (double v) => setState(() => _blur = v),
                      ),
                      DemoSlider(
                        label: 'magnification',
                        value: _magnification,
                        min: 1,
                        max: 1.4,
                        decimals: 2,
                        onChanged: (double v) =>
                            setState(() => _magnification = v),
                      ),
                      DemoSlider(
                        label: 'border width',
                        value: _border,
                        min: 0,
                        max: 4,
                        decimals: 1,
                        onChanged: (double v) => setState(() => _border = v),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
