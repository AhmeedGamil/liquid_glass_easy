import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Blender — four draggable tiles fused by one LiquidGlassBlender.
//
//   flutter run -t lib/blender_page.dart
//
// Four glass tiles, each its own lens with its own icon and label, drawn
// as one surface by the blender around them. Drag any two together and
// they flow into each other through a metaball bridge; pull them apart
// and they separate again. The slider is the smoothness of that bridge.
//
// Take it to zero and the bridge is gone: the four keep their own hard
// outlines while still sharing one surface, one backdrop read and one
// material. That is the whole of what LiquidGlassGroup does.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BlenderApp());
}

class _BlenderApp extends StatelessWidget {
  const _BlenderApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const BlenderPage(),
    );
  }
}

class BlenderPage extends StatefulWidget {
  const BlenderPage({super.key, this.members = 4})
      : assert(members == 2 || members == 4);

  /// How many tiles the blender fuses: the full 2×2 block, or just the
  /// top row of two.
  final int members;

  @override
  State<BlenderPage> createState() => _BlenderPageState();
}

class _BlenderPageState extends State<BlenderPage> {
  double _smoothness = 44;

  static const Size _tile = Size(118, 96);

  /// The 2×2 block, relative to its own top-left. The gaps are what the
  /// bridge closes, so they are the composition and never change.
  static const double _gapX = 146;
  static const double _gapY = 124;
  static const List<Offset> _grid = <Offset>[
    Offset(0, 0),
    Offset(_gapX, 0),
    Offset(0, _gapY),
    Offset(_gapX, _gapY),
  ];

  /// Top-left of each tile, once a finger has moved one.
  ///
  /// Null until then: where the block *starts* depends on the box this page
  /// is given, and a fixed offset tuned for a phone leaves the block sitting
  /// right of centre in the narrow frame the docs site embeds it in.
  List<Offset>? _pos;

  /// The block, centred across and a little above centre down the page.
  List<Offset> _start(Size box) {
    final double blockH =
        widget.members == 4 ? _gapY + _tile.height : _tile.height;
    final Offset origin = Offset(
      (box.width - (_gapX + _tile.width)) / 2,
      (box.height - blockH) * 0.34,
    );
    return <Offset>[
      for (final Offset g in _grid.take(widget.members)) origin + g
    ];
  }

  static const List<(IconData, String)> _tiles = <(IconData, String)>[
    (Icons.wifi_rounded, 'Wi-Fi'),
    (Icons.bluetooth_rounded, 'Bluetooth'),
    (Icons.flashlight_on_rounded, 'Torch'),
    (Icons.dark_mode_rounded, 'Focus'),
  ];

  static const LiquidGlassStyle _glass = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 30,
      borderWidth: 1.4,
    ),
    appearance: LiquidGlassAppearance(color: Color(0x1AFFFFFF)),
    refraction: LiquidGlassRefraction(distortion: 0.12, distortionWidth: 26),
  );

  Widget _member(int i, List<Offset> pos) {
    final (IconData icon, String label) = _tiles[i];
    return Positioned(
      left: pos[i].dx,
      top: pos[i].dy,
      width: _tile.width,
      height: _tile.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (DragUpdateDetails d) => setState(() {
          final List<Offset> next = List<Offset>.of(pos);
          next[i] += d.delta;
          _pos = next;
        }),
        child: LiquidGlassLens(
          style: _glass,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const DemoBackdrop(seed: 3),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final List<Offset> pos =
                _pos ?? _start(Size(c.maxWidth, c.maxHeight));
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: LiquidGlassBlender(
                    // The radius of the bridge. Members within about half of
                    // it flow together. Zero switches the metaball off
                    // entirely — one surface, one read, four hard outlines.
                    smoothness: _smoothness,
                    style: _glass,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        for (int i = 0; i < widget.members; i++)
                          _member(i, pos),
                      ],
                    ),
                  ),
                ),
                DemoPanel(
                  title: 'LiquidGlassBlender',
                  children: <Widget>[
                    DemoSlider(
                      label: 'smoothness',
                      value: _smoothness,
                      min: 0,
                      max: 120,
                      onChanged: (double v) => setState(() => _smoothness = v),
                    ),
                    // Zero is a branch, not a small radius: the shader stops
                    // running the smooth union at all. Worth saying, because
                    // it is the whole of what LiquidGlassGroup does.
                    if (_smoothness == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'metaball off — hard union, one surface, one read',
                          style: TextStyle(
                            color: Color(0xFF9BE7C4),
                            fontSize: 12,
                          ),
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
}
