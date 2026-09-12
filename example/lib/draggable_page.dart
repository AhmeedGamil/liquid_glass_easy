import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Draggable — LiquidGlassDraggable, drag without rebuilding the lens.
//
//   flutter run -t lib/draggable_page.dart
//
// One lens over a photo, wrapped in a LiquidGlassDraggable. The wrapper
// owns the pan; only a translate rebuilds per frame, so the lens inside
// stays one stable subtree and keeps sampling wherever it ends up.
// `onChanged` reports each offset, read out in the panel rather than
// painted into the backdrop — the photograph is the only thing under the
// glass, so what you see through it is the drag and nothing else.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DraggableApp());
}

class _DraggableApp extends StatelessWidget {
  const _DraggableApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DraggablePage(),
    );
  }
}

class DraggablePage extends StatefulWidget {
  const DraggablePage({super.key});

  @override
  State<DraggablePage> createState() => _DraggablePageState();
}

class _DraggablePageState extends State<DraggablePage> {
  bool _enabled = true;
  Offset _disc = Offset.zero;

  static const double _size = 168;

  static const LiquidGlassStyle _clear = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(
      cornerRadius: _size / 2,
      borderWidth: 1.4,
    ),
    // No magnification: the disc bends what is behind it without
    // enlarging it, so the photograph lines up across its rim.
    refraction: LiquidGlassRefraction(
      distortion: 0.2,
      distortionWidth: 30,
      magnification: 1,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const DemoPhoto(
          'socotra_tree_2.jpg',
          seed: 3,
          scrim: 0.3,
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 36,
              top: 120,
              child: LiquidGlassDraggable(
                enabled: _enabled,
                onChanged: (Offset o) => setState(() => _disc = o),
                child: const SizedBox(
                  width: _size,
                  height: _size,
                  child: LiquidGlassLens(
                    style: _clear,
                    child: Center(
                      child: Icon(Icons.open_with_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),
            DemoPanel(
              title: 'LiquidGlassDraggable',
              children: <Widget>[
                // What `onChanged` reports, live.
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'offset  ${_disc.dx.round()}, ${_disc.dy.round()}',
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12.5,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
                DemoChips<bool>(
                  values: const <bool>[true, false],
                  selected: _enabled,
                  label: (bool v) => v ? 'enabled' : 'locked',
                  onChanged: (bool v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
