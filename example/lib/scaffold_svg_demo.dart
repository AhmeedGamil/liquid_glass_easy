import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'nav_bar_tuning.dart';
import 'scaffold_demo.dart' show AuroraFeed;
import 'tuning_store.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/scaffold_svg_demo.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const ScaffoldSvgDemo(),
    ),
  );
}

/// The same page as [ScaffoldDemo] — the Aurora feed behind a floating
/// glass bottom nav bar — but every tab glyph is an **SVG asset**
/// instead of an [IconData], drawn through
/// [LiquidGlassTabBarItem.iconBuilder].
///
/// What the builder gets is the whole trick: the color the bar already
/// resolved for the layer being drawn, and whether that layer is the
/// selected one. Tint with the first and switch artwork on the second
/// and an SVG behaves exactly like a built-in icon — including the
/// moving pill's reveal, which draws every tab twice per frame (once
/// clipped outside the pill in the unselected color, once inside it in
/// the selected color).
class ScaffoldSvgDemo extends StatefulWidget {
  const ScaffoldSvgDemo({super.key});

  @override
  State<ScaffoldSvgDemo> createState() => _ScaffoldSvgDemoState();
}

class _ScaffoldSvgDemoState extends State<ScaffoldSvgDemo> {
  int _index = 0;

  // Same live tuning hookup as the IconData demo, so both pages react to
  // the Nav Motion Tuner.
  ValueNotifier<NavTuning> get _navTuning => TuningStore.instance.nav;

  @override
  void initState() {
    super.initState();
    _navTuning.addListener(_onTuningChanged);
  }

  @override
  void dispose() {
    _navTuning.removeListener(_onTuningChanged);
    super.dispose();
  }

  void _onTuningChanged() {
    if (mounted) setState(() {});
  }

  /// One tab whose glyph is an SVG pair: `name.svg` when unselected,
  /// `name_fill.svg` when selected.
  ///
  /// `i.color` is the color the bar resolved for this layer — pushing it
  /// through a `srcIn` filter keeps the artwork's shape and repaints it,
  /// which is what makes the pill reveal work. Multi-color art would
  /// simply ignore it.
  static LiquidGlassTabBarItem _svgTab(String name, String label) {
    return LiquidGlassTabBarItem.custom(
      label: label,
      iconBuilder: (context, i) => SvgPicture.asset(
        'assets/icons/${i.selected ? '${name}_fill' : name}.svg',
        width: i.size,
        height: i.size,
        colorFilter: ColorFilter.mode(i.color, BlendMode.srcIn),
      ),
    );
  }

  static final _items = [
    _svgTab('home', 'Home'),
    _svgTab('search', 'Search'),
    _svgTab('heart', 'Liked'),
    _svgTab('star', 'Top'),
    _svgTab('person', 'Profile'),
  ];

  /// Per-tab accent — recolours the feed so the glass has a different
  /// hue to refract on every tab.
  static const _accents = [
    Color(0xFF7C5CFF), // Home    — violet
    Color(0xFF4FB3FF), // Search  — blue
    Color(0xFFFF5C8A), // Liked   — pink
    Color(0xFFFFB020), // Top     — amber
    Color(0xFF2DD4BF), // Profile — teal
  ];

  static const _overlines = [
    'TUESDAY · JUNE 16',
    'BROWSE ALL',
    'YOUR FAVOURITES',
    'TOP CHARTS',
    'YOUR ACCOUNT',
  ];
  static const _greetings = [
    'Good evening',
    'Search',
    'Liked songs',
    'Top this week',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final navTuning = _navTuning.value;
    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: AuroraFeed(
        accent: _accents[_index],
        overline: _overlines[_index],
        greeting: _greetings[_index],
      ),
      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        alignment: Alignment.bottomCenter,
        margin: const EdgeInsets.only(bottom: 24),
        style: navBarStyle(navTuning),
        pillStyle: navPillStyle(navTuning),
        width: 320,
      ),
    );
  }
}
