import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Blended List + Elasticity
//
//   flutter run -t lib/blended_nav_page.dart   (standalone)
//   …or open it from the home menu.
//
// ONE glass lens holding a four-row list, plus a round action — both members
// of one LiquidGlassBlender. The rows are ordinary widgets INSIDE the lens,
// so deforming the glass carries them with it rather than each row having
// glass of its own.
//
// Nothing here is draggable. The two members sit at fixed positions, and the
// only thing that can close the gap between them is the deformation itself:
// pull the list toward the action and the outlines fuse.
//
// The sliders drive the LIST only. The action on the right stays at the
// defaults, so a value can be felt against an unchanged reference on the
// same screen.
//
// The blender is FULL-BLEED on purpose. Its clip region is
// `union.inflate(margin).intersect(fullRect)`, where `fullRect` is its OWN
// rect — so a box around it is a wall the deformation cannot cross, and the
// merged surface would be cut mid-gesture. Filling costs nothing: that clip
// is a cost bound, recomputed each paint from the live member rects, so the
// expensive pass stays as tight as the blobs are.
//
// One thing does not survive a merge: the press-deepens-the-optics cue
// (`refractionBoost`). The blender refracts the whole merged surface through
// ONE shared style, so a press on one tile cannot deepen its own optics
// without deepening every other member's. Geometry — stretch, squeeze, lean,
// grip, holdScale, tapScale — all behave normally.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BlendedListApp());
}

class _BlendedListApp extends StatelessWidget {
  const _BlendedListApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const BlendedNavPage(),
    );
  }
}

/// A blended list lens plus one action, both carrying
/// [LiquidGlassElasticity], with the list's spec on sliders.
class BlendedNavPage extends StatefulWidget {
  const BlendedNavPage({super.key});

  @override
  State<BlendedNavPage> createState() => _BlendedNavPageState();
}

class _BlendedNavPageState extends State<BlendedNavPage> {
  bool _elastic = true;
  bool _showControls = false;

  /// The ACTION's elasticity, left alone so the sliders have something to be
  /// compared against on the same screen.
  static const LiquidGlassElasticity _actionElasticity =
      LiquidGlassElasticity(stretch: 3, lean: 3);

  /// The LIST's default: more stretch than the action, because reaching the
  /// action across the gap is the point here.
  static const LiquidGlassElasticity _listDefault =
      LiquidGlassElasticity(stretch: 22, lean: 0.5);

  /// The LIST's elasticity — what the sliders drive.
  LiquidGlassElasticity _list = _listDefault;

  static const List<(IconData, String)> _rows = [
    (Icons.wb_sunny_rounded, 'Daylight'),
    (Icons.water_drop_rounded, 'Humidity'),
    (Icons.air_rounded, 'Wind'),
    (Icons.nightlight_round, 'Night'),
  ];

  static const double _listWidth = 208;
  static const double _rowHeight = 52;
  static const double _listPadding = 10;

  void _set(LiquidGlassElasticity next) => setState(() => _list = next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Backdrop.tone,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Backdrop(),

          // Both members live in ONE blender: the list lens and the action.
          // Full-bleed — see the note at the top of the file.
          LiquidGlassBlender(
            // Enough that the two start reaching for each other slightly
            // before their outlines actually touch.
            smoothness: 26,
            style: const LiquidGlassStyle(
              shape: LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: 22,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // The list: ONE lens, four rows inside it. The rows are
                  // ordinary widgets — deforming the glass carries them with
                  // it (childFollow), which is the thing to watch.
                  Align(
                    alignment: const Alignment(-0.55, 0),
                    child: SizedBox(
                      width: _listWidth,
                      height: _rowHeight * _rows.length + _listPadding * 2,
                      child: LiquidGlassLens(
                        elasticity: _elastic ? _list : null,
                        style: const LiquidGlassStyle(
                          shape: LiquidGlassShape.continuousRoundedRectangle(
                            cornerRadius: 26,
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

                  // The action, centred vertically on the right.
                  Align(
                    alignment: const Alignment(0.82, 0),
                    child: LiquidGlassTabBarAction(
                      icon: Icons.search_rounded,
                      size: 60,
                      onTap: () {},
                      elasticity: _elastic ? _actionElasticity : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: IconButton(
                icon: Icon(
                    _showControls ? Icons.close_rounded : Icons.tune_rounded),
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
                value: _elastic,
                onChanged: (v) => setState(() => _elastic = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('elasticity', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  _elastic
                      ? 'every member deforms on touch'
                      : 'rigid glass (members still blend by proximity)',
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
                'Drives the list lens only. Pull it toward the action and the '
                'outlines fuse — the merge comes from the stretch, nothing '
                'moves. Watch the rows travel with the glass: that is '
                'childFollow. The action stays at the defaults as a reference.',
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

/// Glass over a light field is light, so white content would wash out.
const Color _ink = Color(0xFF1B1B22);

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

/// A flat, slightly-off-white field.
///
/// Deliberately plain. Busy detail is what you want to judge REFRACTION, but
/// it hides the thing this page is about — the silhouette. Against one calm
/// tone the outline reads exactly: where it stretches, where it squashes, and
/// where two members fuse. The trade is that there is almost nothing behind
/// the glass to bend, so the refraction itself is barely visible here.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  static const Color tone = Color(0xFFDCDCE1);

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: tone, child: SizedBox.expand());
}
