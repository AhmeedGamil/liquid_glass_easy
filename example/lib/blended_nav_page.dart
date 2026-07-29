import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Glass Pill Nav + Elasticity
//
//   flutter run -t lib/blended_nav_page.dart   (standalone)
//   …or open it from the home menu.
//
// The real glass-refracting morph pill: it slides between tabs with the
// jelly spring (LiquidGlassNavJellyConfig) and refracts the page behind
// it.
//
// The BAR ITSELF HAS NO ELASTICITY. Only the side actions carry it —
// those are ordinary lens-anywhere widgets, which listen for their own
// touches. The bar cannot: its tab-gesture overlay is opaque and sits
// above the capsule, so the capsule's own lens never sees a pointer.
// Wiring that up means the bar owning the gesture and feeding the
// deformation itself, which was tried and then taken back out.
//
// WHAT BLENDS HERE, AND WHAT CANNOT
// ---------------------------------
// The two side actions blend with each other and each carry elasticity.
// Drag the mic into the search: the outlines flow together into one
// surface, and both still deform under the finger while merged.
//
// The BAR is not part of that, and it is the JELLY MORPH PILL that rules
// it out rather than the bar. This bar is built on the position-driven
// pipeline (`LiquidGlassView.withPositionedLenses` with `LiquidGlass`
// configs for the capsule and the moving pill) and it is full-screen: it
// composites over the page behind it. `LiquidGlassBlender` merges bounded
// `LiquidGlassLens` *widgets*, and this path never runs
// `LiquidGlassLens.build`, so it never registers with the blender scope.
//
// One thing does not survive a merge: the press-deepens-the-optics cue
// (`refractionBoost`). The blender refracts the whole merged surface
// through ONE shared style, so a press on one blob cannot deepen its own
// optics without deepening the other's. Geometry — stretch, squeeze,
// lean, grip, holdScale, tapScale — all behave normally.
//
// Drop `pillStyle.mode` (the plain `LiquidGlassBottomNavBar` constructor)
// and the bar becomes a single lens that DOES blend — but then the pill
// is a highlight, not glass.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _GlassPillNavApp());
}

class _GlassPillNavApp extends StatelessWidget {
  const _GlassPillNavApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const BlendedNavPage(),
    );
  }
}

/// The glass-pill bottom nav bar (jelly morph pill) with
/// [LiquidGlassElasticity] on its capsule, plus an elastic side action.
class BlendedNavPage extends StatefulWidget {
  const BlendedNavPage({super.key});

  @override
  State<BlendedNavPage> createState() => _BlendedNavPageState();
}

class _BlendedNavPageState extends State<BlendedNavPage> {
  int _index = 0;
  bool _elastic = true;
  bool _showControls = false;

  static const List<LiquidGlassTabBarItem> _items = [
    LiquidGlassTabBarItem(icon: Icons.play_circle_fill_rounded),
    LiquidGlassTabBarItem(icon: Icons.grid_view_rounded),
    LiquidGlassTabBarItem(icon: Icons.favorite_rounded),
    LiquidGlassTabBarItem(icon: Icons.person_rounded),
  ];

  /// The side actions' elasticity. The bar itself has none — see the note
  /// at the top of the file.
  static const LiquidGlassElasticity _actionElasticity =
      LiquidGlassElasticity(stretch: 3, lean: 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07040F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Feed(index: _index),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),

          // The glass pill bar. `withImpeller` is the bodyless variant:
          // drop it as the LAST child of a Stack over the page and the
          // capsule + pill sample the live backdrop directly.
          LiquidGlassBottomNavBar.withImpeller(
            items: _items,
            selectedIndex: _index,
            onChanged: (i) => setState(() => _index = i),
            width: 260,
            height: 64,
            pillStyle: const LiquidGlassNavPillStyle(
              // THIS is the glass pill: a real refracting lens that morphs
              // as it travels. `jelly` is left at its default on purpose —
              // that is the on-device-tuned iOS squash & stretch.
              mode: LiquidGlassPillMode.impellerOnly,
            ),
          ),

          // Side actions — lens-anywhere widgets, so they blend AND take
          // elasticity. Drag the mic into the search and the two outlines
          // flow together; keep dragging and they separate again.
          // FULL-BLEED on purpose. The blender's clip region is
          // `union.inflate(margin).intersect(fullRect)`, where `fullRect` is
          // its OWN rect — so a box around it is a wall the drag cannot cross,
          // and the merged surface would be cut mid-gesture. Filling costs
          // nothing: that clip is a cost bound, recomputed each paint from the
          // live member rects, so the expensive pass stays as tight as the
          // blobs are however large the blender is.
          LiquidGlassBlender(
            // Wide enough that the two fuse before they touch, which is the
            // whole point of the merge.
            smoothness: 34,
            style: const LiquidGlassStyle(
              shape: LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: 30,
              ),
            ),
            child: SafeArea(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 18,
                    bottom: 28,
                    child: LiquidGlassTabBarAction(
                      icon: Icons.search_rounded,
                      size: 60,
                      onTap: () {},
                      elasticity: _elastic ? _actionElasticity : null,
                    ),
                  ),
                  // Draggable member. The blender reads every member's rect
                  // through `getTransformTo`, so a Transform-based drag is fine
                  // here — unlike a lens painting its own glass, which reads
                  // screen-space FragCoord and would count it twice.
                  Positioned(
                    right: 18,
                    bottom: 124,
                    child: LiquidGlassDraggable(
                      child: LiquidGlassTabBarAction(
                        icon: Icons.mic_rounded,
                        size: 60,
                        onTap: () {},
                        elasticity: _elastic ? _actionElasticity : null,
                      ),
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
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 56, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        decoration: BoxDecoration(
          color: const Color(0xCC15102B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile.adaptive(
              value: _elastic,
              onChanged: (v) => setState(() => _elastic = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('elasticity', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                _elastic
                    ? 'the blended actions deform on touch'
                    : 'rigid glass (pill jelly still runs)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// A busy, high-contrast feed so the pill and capsule have something
/// worth refracting. Scrolls under the bar.
class _Feed extends StatelessWidget {
  final int index;
  const _Feed({required this.index});

  static const List<List<Color>> _palettes = [
    [Color(0xFFFF6B9D), Color(0xFFFFC46B)],
    [Color(0xFF6EE7F9), Color(0xFF7C5CFF)],
    [Color(0xFF34D399), Color(0xFF0E7C8C)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
  ];

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = _palettes[index % _palettes.length];
    return ScrollConfiguration(
      // Android's stretch overscroll lifts content into its own layer, and
      // a BackdropFilter lens above it then reads a black backdrop.
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 190),
        itemCount: 30,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, i) {
          final double t = (i % 7) / 6;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(palette[0], palette[1], t)!,
                  Color.lerp(palette[1], palette[0], t)!,
                ],
              ),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
