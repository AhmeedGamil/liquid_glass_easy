import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Shadow — the contact shadow that sets glass into the page.
//
//   flutter run -t lib/shadow_page.dart
//
// A light page — the kind a shadow actually shows on — with two draggable
// lenses floating over it: a wide card and a round button. Both wear a
// LiquidGlassShadow through `appearance.shadow`, and the panel drives its
// numbers. The first chip switches it off outright, which is the whole
// argument: without it the glass floats flat, with it the glass sits in.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ShadowApp());
}

class _ShadowApp extends StatelessWidget {
  const _ShadowApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const ShadowPage(),
    );
  }
}

class ShadowPage extends StatefulWidget {
  const ShadowPage({super.key});

  @override
  State<ShadowPage> createState() => _ShadowPageState();
}

class _ShadowPageState extends State<ShadowPage> {
  bool _on = true;
  double _blur = 10;
  double _opacity = 0.4;
  double _offset = 12;
  double _inset = 0;

  static const Color _ink = Color(0xFF1F2937);

  static const Size _card = Size(264, 148);
  static const double _button = 68;

  // Where the lenses have been dragged to is NOT page state: a setState per
  // pan update would rebuild this whole view on every pointer move.
  // LiquidGlassDraggable keeps each offset in its own ValueNotifier.

  /// The card centred a little above the middle, the button below-right of
  /// it, so both sit over the white rows where the shadow reads best.
  Offset _cardAt(Size box) => Offset(
        (box.width - _card.width) / 2,
        (box.height - _card.height) * 0.30,
      );
  Offset _buttonAt(Size box) => Offset(
        (box.width + _card.width) / 2 - _button,
        (box.height - _card.height) * 0.30 + _card.height + 28,
      );

  LiquidGlassShadow get _shadow => LiquidGlassShadow(
        blur: _blur,
        opacity: _opacity,
        offset: Offset(0, _offset),
        inset: _inset,
        visible: _on,
      );

  LiquidGlassStyle _style(LiquidGlassShape shape) => LiquidGlassStyle(
        shape: shape,
        appearance: LiquidGlassAppearance(
          blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
          color: const Color(0x40FFFFFF),
          shadow: _shadow,
        ),
        refraction:
            const LiquidGlassRefraction(distortion: 0.1, distortionWidth: 30),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const _NotesPage(),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Size box = Size(c.maxWidth, c.maxHeight);
            final Offset card = _cardAt(box);
            final Offset button = _buttonAt(box);
            return Stack(
              children: <Widget>[
                Positioned(
                  left: card.dx,
                  top: card.dy,
                  width: _card.width,
                  height: _card.height,
                  child: LiquidGlassDraggable(
                    child: LiquidGlassLens(
                      style: _style(
                        const LiquidGlassShape.continuousRoundedRectangle(
                          cornerRadius: 34,
                          borderWidth: 1.2,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'LiquidGlassShadow',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Drag me over the rows',
                              style: TextStyle(
                                color: Color(0xB31F2937),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: button.dx,
                  top: button.dy,
                  width: _button,
                  height: _button,
                  child: LiquidGlassDraggable(
                    child: LiquidGlassLens(
                      style: _style(
                        const LiquidGlassShape.roundedRectangle(
                          cornerRadius: _button / 2,
                          borderWidth: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_rounded, color: _ink, size: 30),
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
                    child: DemoHeader(title: 'Shadow', foreground: _ink),
                  ),
                ),
                DemoPanel(
                  title: 'LiquidGlassShadow',
                  children: <Widget>[
                    DemoChips<bool>(
                      values: const <bool>[true, false],
                      selected: _on,
                      label: (bool v) => v ? 'shadow on' : 'shadow off',
                      onChanged: (bool v) => setState(() => _on = v),
                    ),
                    const SizedBox(height: 6),
                    DemoSlider(
                      label: 'blur',
                      value: _blur,
                      min: 0,
                      max: 24,
                      onChanged: (double v) => setState(() => _blur = v),
                    ),
                    DemoSlider(
                      label: 'opacity',
                      value: _opacity,
                      min: 0,
                      max: 0.7,
                      decimals: 2,
                      onChanged: (double v) => setState(() => _opacity = v),
                    ),
                    DemoSlider(
                      label: 'offset',
                      value: _offset,
                      min: 0,
                      max: 30,
                      onChanged: (double v) => setState(() => _offset = v),
                    ),
                    DemoSlider(
                      label: 'inset',
                      value: _inset,
                      min: 0,
                      max: 14,
                      onChanged: (double v) => setState(() => _inset = v),
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

/// A light notes list: the page the shadow is cast on. White rows on a pale
/// ground, so the multiply shadow darkens both and the contact reads.
class _NotesPage extends StatelessWidget {
  const _NotesPage();

  static const List<(String, String, Color)> _rows = <(String, String, Color)>[
    ('Groceries', 'Oat milk, lemons, basil, eggs', Color(0xFFFDE68A)),
    ('Studio', 'Move the lamp left, retake the hero shot', Color(0xFFBFDBFE)),
    ('Reading', 'Finish chapter nine before Friday', Color(0xFFFBCFE8)),
    ('Garden', 'Repot the fig, water the herbs twice', Color(0xFFBBF7D0)),
    ('Calls', 'Dentist, the landlord, Sami about the trip', Color(0xFFDDD6FE)),
    (
      'Ideas',
      'A glass card that sits in the page, not on it',
      Color(0xFFFED7AA)
    ),
    ('Weekend', 'Hike early, bakery after, nothing else', Color(0xFFA5F3FC)),
    ('Later', 'Sort the photo library by trip', Color(0xFFE5E7EB)),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F4F5),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 12),
            child: Text(
              'Notes',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          for (final (String title, String body, Color accent) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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
