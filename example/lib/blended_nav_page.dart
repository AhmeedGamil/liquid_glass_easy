import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Blended List + Elasticity
//
//   flutter run -t lib/blended_nav_page.dart   (standalone)
//   …or open it from the home menu.
//
// A vertical list of four glass tiles and a round action, ALL members of one
// LiquidGlassBlender. Nothing here is draggable: the tiles sit at fixed
// positions, close enough that DEFORMING one is what reaches its neighbour.
// Press and pull a tile and watch it stretch into the one above or below —
// the merge is caused by the elasticity rather than by moving anything.
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

/// A blended vertical list plus one action, every member carrying
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
  /// next tile is the point here.
  static const LiquidGlassElasticity _listDefault =
      LiquidGlassElasticity(stretch: 22, lean: 0.5);

  /// The LIST's elasticity — what the sliders drive.
  LiquidGlassElasticity _list = _listDefault;

  static const List<IconData> _listIcons = [
    Icons.wb_sunny_rounded,
    Icons.water_drop_rounded,
    Icons.air_rounded,
    Icons.nightlight_round,
  ];

  static const double _tile = 62;

  /// Gap between tiles. Deliberately small: `stretch` only has to reach a
  /// little way before the outlines fuse, which is the whole demonstration.
  static const double _gap = 18;

  void _set(LiquidGlassElasticity next) => setState(() => _list = next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07040F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _Backdrop(),

          // Every member lives in ONE blender: the four list tiles and the
          // action. Full-bleed — see the note at the top of the file.
          LiquidGlassBlender(
            // Enough that neighbouring tiles start reaching for each other
            // slightly before their outlines actually touch.
            smoothness: 26,
            style: const LiquidGlassStyle(
              shape: LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: 22,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // The list, centred vertically, left of middle.
                  Align(
                    alignment: const Alignment(-0.62, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < _listIcons.length; i++) ...[
                          if (i > 0) const SizedBox(height: _gap),
                          _ListTile(
                            icon: _listIcons[i],
                            size: _tile,
                            elasticity: _elastic ? _list : null,
                          ),
                        ],
                      ],
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
                color: Colors.white,
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
                'Drives the four tiles only. Pull one toward its neighbour '
                'and the outlines fuse — the merge comes from the stretch, '
                'nothing moves. The action on the right stays at the defaults '
                'as a reference.',
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

/// One tile of the vertical list — a plain [LiquidGlassLens], so it registers
/// with the surrounding blender and carries its own elasticity.
class _ListTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final LiquidGlassElasticity? elasticity;

  const _ListTile({
    required this.icon,
    required this.size,
    required this.elasticity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: LiquidGlassLens(
        elasticity: elasticity,
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 22),
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 26)),
      ),
    );
  }
}

/// Busy, high-contrast detail so the refraction has something to bend.
///
/// The photo is the one the other blending demos use; the gradient stands in
/// while it loads and if the network is unavailable, so the page is never a
/// flat void.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  static const String _url =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  static const Widget _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF6B9D),
          Color(0xFF7C5CFF),
          Color(0xFF34D399),
          Color(0xFFFFC46B),
        ],
      ),
    ),
    child: SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback,
    );
  }
}
