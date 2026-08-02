import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Touch — LiquidGlassTouch / LiquidGlassFlex on a real surface
//
//   flutter run -t lib/touch_page.dart   (standalone)
//   …or open it from the home menu.
//
// ONE glass lens holding a four-row list, centred on a flat page. The rows
// are ordinary widgets INSIDE the lens, so deforming the glass carries them
// with it rather than each row having glass of its own — that is
// childFollow, visible in the same gesture as the stretch.
//
// Nothing here is draggable. The lens sits at a fixed position and the only
// thing that moves it is the deformation itself: press and it swells under
// the finger, drag and it elongates along the pull, pinches in the cross
// axis, leans after the finger, then springs back with a wobble.
//
// The page is a flat off-white with no photo behind it, so there is nothing
// for the glass to refract — the gray rim is what draws the shape. Turn the
// tone or the rim up if the surface reads too faint on device.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _TouchApp());
}

class _TouchApp extends StatelessWidget {
  const _TouchApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const TouchPage(),
    );
  }
}

/// A centred list lens carrying [LiquidGlassFlex], with its spec on
/// sliders.
class TouchPage extends StatefulWidget {
  const TouchPage({super.key});

  @override
  State<TouchPage> createState() => _TouchPageState();
}

class _TouchPageState extends State<TouchPage> {
  bool _flexing = true;
  bool _showControls = false;

  /// The LIST's default: more stretch than the package default, so the
  /// deformation is obvious on a panel this size.
  static const LiquidGlassFlex _listDefault =
      LiquidGlassFlex(stretch: 22, lean: 0.5);

  /// The LIST's flex — what the sliders drive.
  LiquidGlassFlex _list = _listDefault;

  static const List<(IconData, String)> _rows = [
    (Icons.wb_sunny_rounded, 'Daylight'),
    (Icons.water_drop_rounded, 'Humidity'),
    (Icons.air_rounded, 'Wind'),
    (Icons.nightlight_round, 'Night'),
  ];

  static const double _listWidth = 184;
  static const double _rowHeight = 52;
  static const double _listPadding = 10;

  void _set(LiquidGlassFlex next) => setState(() => _list = next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageTone,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The list: ONE lens, four rows inside it, centred on the page.
          // The rows are ordinary widgets — deforming the glass carries them
          // with it (childFollow), which is the thing to watch.
          SafeArea(
            child: Center(
              child: SizedBox(
                width: _listWidth,
                height: _rowHeight * _rows.length + _listPadding * 2,
                child: LiquidGlassLens(
                  touch: _flexing ? LiquidGlassTouch(flex: _list) : null,
                  style: const LiquidGlassStyle(
                    shape: LiquidGlassShape.continuousRoundedRectangle(
                      cornerRadius: 26,
                      borderColor: _rim,
                      lightDirection: 39,
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: _listPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in _rows)
                          _ListRow(icon: row.$1, label: row.$2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: IconButton(
                icon: Icon(
                    _showControls ? Icons.close_rounded : Icons.tune_rounded),
                // Sits on the page, not on glass — ink, or it disappears
                // into the off-white.
                color: _ink,
                onPressed: () =>
                    setState(() => _showControls = !_showControls),
              ),
            ),
          ),
          if (_showControls)
            Align(alignment: Alignment.topCenter, child: _controls()),
        ],
      ),
    );
  }

  Widget _controls() {
    final s = _list;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 52, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        // Bounded + scrollable: the panel must not grow down over the tiles
        // it is tuning.
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: const Color(0xCC15102B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SwitchListTile.adaptive(
                value: _flexing,
                onChanged: (v) => setState(() => _flexing = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('flex', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  _flexing
                      ? 'the lens deforms on touch'
                      : 'rigid glass — no listener, no ticker',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const Divider(height: 12),
              Row(
                children: [
                  const TunerPanelTitle('LIST'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _set(_listDefault),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child:
                        const Text('reset', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
              Text(
                'Drives the list lens. Nothing here moves the box — every '
                'pixel of travel is the deformation. Watch the rows go with '
                'the glass: that is childFollow.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 6),
              TunerParamSlider('stretch', s.stretch, 0, 80,
                  s.stretch.toStringAsFixed(0),
                  (v) => _set(s.copyWith(stretch: v))),
              TunerParamSlider('squeeze', s.squeeze, 0, 1,
                  s.squeeze.toStringAsFixed(2),
                  (v) => _set(s.copyWith(squeeze: v))),
              TunerParamSlider('lean', s.lean, 0, 1, s.lean.toStringAsFixed(2),
                  (v) => _set(s.copyWith(lean: v))),
              TunerParamSlider('grip', s.grip, 0, 1, s.grip.toStringAsFixed(2),
                  (v) => _set(s.copyWith(grip: v))),
              // Signed: right of zero the glass swells under the finger, left
              // of zero it yields inward. Fractions of the tile's own size.
              TunerParamSlider('holdScale', s.holdScale, -0.4, 0.4,
                  s.holdScale.toStringAsFixed(3),
                  (v) => _set(s.copyWith(holdScale: v))),
              TunerParamSlider('tapScale', s.tapScale, -0.4, 0.4,
                  s.tapScale.toStringAsFixed(3),
                  (v) => _set(s.copyWith(tapScale: v))),
              TunerParamSlider('maxPull', s.maxPull, 10, 300,
                  s.maxPull.toStringAsFixed(0),
                  (v) => _set(s.copyWith(maxPull: v))),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page: a flat off-white, no photo. White, but held back from the
/// full glare of it.
const Color _pageTone = Color(0xFFEDEAF0);

/// The content on the glass. The surface stays light, so it is ink.
const Color _ink = Color(0xFF1B1B22);

/// Both rims. On a flat page there is nothing for the glass to refract, so
/// the outline is what draws the shape — a solid gray rather than the
/// light/shadow pair the border would otherwise derive.
const Color _rim = Color(0xFF8E8E99);

/// One row inside the list lens. A plain widget: it is the lens's child, so
/// the deformation carries it rather than it deforming on its own.
class _ListRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ListRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 18),
          Icon(icon, color: _ink, size: 21),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

