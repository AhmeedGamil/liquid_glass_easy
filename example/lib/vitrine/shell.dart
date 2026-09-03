import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'common.dart';
import 'data.dart';
import 'pages/bag_page.dart';
import 'pages/browse_page.dart';
import 'pages/saved_page.dart';
import 'pages/search_page.dart';
import 'pages/shop_page.dart';
import 'plate.dart';
import 'theme.dart';

// =============================================================
// The shell: one LiquidGlassScaffold, five tabs through it.
//
// The scaffold's `body` is the captured layer, and it holds BOTH the
// room and the page scrolling in it. Everything a page draws — every
// plate — therefore passes under the bars and gets bent by them. Put
// the content up in `lenses` instead and it would paint OVER the tab
// bar rather than sliding beneath it.
//
// The chrome is owned here rather than by the pages, so it survives a
// tab change: the selection pill travels between tabs because the bar
// it lives in is never rebuilt.
//
// Two lenses on screen, and only two. That is the budget the whole app
// is designed around — everything else with a glass edge on it is a
// `LiquidGlassLite`, which is a triangle mesh and reads nothing.
// =============================================================

class VitrineApp extends StatefulWidget {
  const VitrineApp({super.key});

  @override
  State<VitrineApp> createState() => _VitrineAppState();
}

class _VitrineAppState extends State<VitrineApp> {
  final Bag _bag = Bag();

  @override
  void dispose() {
    _bag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vitrine',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: kPaper,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      // The bag is above the navigator, so a pushed product page and the
      // tab bar's count are looking at the same object.
      builder: (BuildContext context, Widget? child) =>
          BagScope(bag: _bag, child: child ?? const SizedBox.shrink()),
      home: const VitrineShell(),
    );
  }
}

class VitrineShell extends StatefulWidget {
  const VitrineShell({super.key});

  @override
  State<VitrineShell> createState() => _VitrineShellState();
}

class _VitrineShellState extends State<VitrineShell> {
  static const List<VitrineTab> _tabs = <VitrineTab>[
    ShopTab(),
    BrowseTab(),
    SearchTab(),
    SavedTab(),
    BagTab(),
  ];

  static const double _barHeight = 60;
  static const double _barBottomMargin = 16;

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final VitrineTab tab = _tabs[_index];
    final Bag bag = BagScope.of(context);
    final double screen = MediaQuery.sizeOf(context).width;
    final double barWidth = (screen - 32).clamp(280.0, 520.0);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,

      // The captured layer: the room, and the page standing in it.
      body: Stack(
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            switchInCurve: Curves.easeOutCubic,
            child: VitrineRoom(
              key: ValueKey<String>(tab.label),
              tone: tab.tone,
              seed: tab.label,
            ),
          ),
          // Keyed, so switching tabs cross-fades rather than reusing the
          // outgoing page's scroll position.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: ValueKey<String>(tab.label),
              child: tab.content(context),
            ),
          ),
        ],
      ),

      appBar: LiquidGlassAppBar(
        width: barWidth,
        height: 54,
        centerTitle: false,
        horizontalPadding: 18,
        style: vitrineChrome(radius: 27),
        foregroundColor: kInk,
        title: Text(
          tab.title,
          style: kTitle.copyWith(fontSize: 17, letterSpacing: -0.35),
        ),
        actions: tab.actions(context),
      ),

      bottomNavigationBar: LiquidGlassTabBar(
        items: <LiquidGlassTabBarItem>[
          for (final VitrineTab t in _tabs)
            LiquidGlassTabBarItem(
              icon: t.icon,
              label: t.label,
              // Only the bag needs a builder, and only so the count can
              // ride on the glyph. It is drawn for every layer the bar
              // renders — including the one under the moving pill — so
              // the badge travels with the icon instead of popping.
              iconBuilder: t is BagTab && bag.count > 0
                  ? (BuildContext ctx, LiquidGlassGlyph g) =>
                      _BagGlyph(glyph: g, count: bag.count, icon: t.icon)
                  : null,
            ),
        ],
        selectedIndex: _index,
        onChanged: (int i) => setState(() => _index = i),
        width: barWidth,
        height: _barHeight,
        itemPadding: 4,
        margin: const EdgeInsets.only(bottom: _barBottomMargin),
        style: vitrineChrome(radius: _barHeight / 2),

        itemStyle: const LiquidGlassTabItemStyle(
          selectedColor: kInk,
          unselectedColor: Color(0x8C1A1714),
          iconSize: 21,
          underGlassIconSize: 23,
          labelFontSize: 9.5,
          iconLabelGap: 3,
          selectedFontWeight: FontWeight.w700,
          unselectedFontWeight: FontWeight.w500,
        ),

        // The pill is glass on both renderers, and what it comes to rest
        // in is barely there: on a light bar a strong rest pill reads as
        // a smudge, and the ink glyph already says which tab is on.
        pillStyle: LiquidGlassTabPillStyle(
          mode: LiquidGlassPillMode.both,
          rest: LiquidGlassStyle(
            shape: const LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: 22,
              borderWidth: 0.6,
            ),
            appearance: LiquidGlassAppearance(
              color: Colors.white.withValues(alpha: 0.30),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bag glyph, with what is in it.
///
/// It draws at the size and colour the bar hands it, so it dims,
/// brightens and grows exactly as a plain `Icon` would — the badge is
/// the only thing added.
class _BagGlyph extends StatelessWidget {
  const _BagGlyph({
    required this.glyph,
    required this.count,
    required this.icon,
  });

  final LiquidGlassGlyph glyph;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: glyph.size,
      height: glyph.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          // The icon gives up a little size so the badge can sit inside
          // the cell: the bar sizes its own layout from its numbers, not
          // from the glyph, so anything hung outside this box is at the
          // mercy of the host's clip.
          Icon(icon, size: glyph.size * 0.92, color: glyph.color),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: BoxConstraints(minWidth: glyph.size * 0.46),
              height: glyph.size * 0.46,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: glyph.size * 0.09),
              decoration: BoxDecoration(
                color: kSignal,
                borderRadius: BorderRadius.circular(glyph.size),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  fontSize: glyph.size * 0.30,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFF3EF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
