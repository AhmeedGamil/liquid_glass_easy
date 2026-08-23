import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_nav_bar_pill.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_nav_bar_motion_pill.dart';

// Verifies LiquidGlassStyle.adaptivity on every tier of the bottom nav
// bar via the manual `permanentBrightness` verdict (no sampling, so no
// view/shader machinery is required): UNSELECTED icons + labels must
// follow the adaptive content color and flip when the verdict does,
// while the SELECTED item never adapts — it keeps the item style's
// fixed `selectedColor` on every backdrop.

const Color _onDark = Color(0xFF102030); // content color over dark backdrops
const Color _onLight = Color(0xFFF0E0D0); // content color over light backdrops
const Color _accent = Colors.red; // fixed selected color (never adapts)

LiquidGlassAdaptivity _adaptivity(Brightness verdict) => LiquidGlassAdaptivity(
      contentColorOnDark: _onDark,
      contentColorOnLight: _onLight,
      permanentBrightness: verdict,
      duration: const Duration(milliseconds: 200),
    );

const _items = [
  LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
  LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Search'),
];

Widget _bar({
  required Brightness verdict,
  LiquidGlassTabPillStyle pillStyle = const LiquidGlassTabPillStyle(),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: LiquidGlassTabBar(
          items: _items,
          selectedIndex: 0,
          onChanged: (_) {},
          pillStyle: pillStyle,
          itemStyle: const LiquidGlassTabItemStyle(selectedColor: _accent),
          style: LiquidGlassTabBar.defaultStyle
              .copyWith(adaptivity: _adaptivity(verdict)),
        ),
      ),
    ),
  );
}

/// The rendered color of the icon for [icon].
Color? _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon).first).color;

void main() {
  testWidgets(
      'static tier: unselected follows the adaptive color, selected stays fixed',
      (tester) async {
    await tester.pumpWidget(_bar(verdict: Brightness.dark));
    await tester.pump();

    // Selected cell: the fixed accent — never the adaptive color.
    expect(_iconColor(tester, Icons.home_rounded), _accent);
    // Unselected cell: the adaptive content color.
    expect(_iconColor(tester, Icons.search_rounded), _onDark);
  });

  testWidgets(
      'static tier: unselected flips (animated) when the verdict flips, selected does not',
      (tester) async {
    await tester.pumpWidget(_bar(verdict: Brightness.dark));
    await tester.pump();
    expect(_iconColor(tester, Icons.search_rounded), _onDark);

    await tester.pumpWidget(_bar(verdict: Brightness.light));
    // Mid-flip: the unselected color is between the two palettes.
    await tester.pump(const Duration(milliseconds: 100));
    final Color? mid = _iconColor(tester, Icons.search_rounded);
    expect(mid, isNot(_onDark));
    expect(mid, isNot(_onLight));
    // The selected item is pinned throughout.
    expect(_iconColor(tester, Icons.home_rounded), _accent);
    // Settled: the light-backdrop palette; selected still pinned.
    await tester.pumpAndSettle();
    expect(_iconColor(tester, Icons.search_rounded), _onLight);
    expect(_iconColor(tester, Icons.home_rounded), _accent);
  });

  testWidgets('sliding tier: only the unselected reveal layer adapts',
      (tester) async {
    await tester.pumpWidget(_bar(
      verdict: Brightness.light,
      pillStyle: const LiquidGlassTabPillStyle(animated: true),
    ));
    await tester.pumpAndSettle();

    // The sliding tier draws every icon twice (selected layer clipped
    // inside the pill, unselected outside): the selected copy carries
    // the fixed accent, the unselected copy the adaptive color.
    final colors = tester
        .widgetList<Icon>(find.byIcon(Icons.home_rounded))
        .map((w) => w.color)
        .toSet();
    expect(colors, {_accent, _onLight});
  });

  testWidgets(
      'glass-pill tier: shell follows the manual verdict, selected stays fixed',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        body: const ColoredBox(color: Colors.black),
        bottomNavigationBar: LiquidGlassTabBar(
          items: _items,
          selectedIndex: 0,
          onChanged: (_) {},
          pillStyle:
              const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.both),
          itemStyle: const LiquidGlassTabItemStyle(selectedColor: _accent),
          style: LiquidGlassTabBar.defaultStyle
              .copyWith(adaptivity: _adaptivity(Brightness.dark)),
        ),
      ),
    ));
    await tester.pump();

    // The shell renders in the dual-view pipeline; with a manual verdict
    // no sampling runs, and the unselected icon must already carry the
    // adaptive content color while the selected keeps the accent.
    expect(_iconColor(tester, Icons.home_rounded), _accent);
    expect(_iconColor(tester, Icons.search_rounded), _onDark);

    // Unmount cleanly (stops the capture pipelines) before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'no accent (selected == unselected): the selected item adapts too',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassTabBar(
            items: _items,
            selectedIndex: 0,
            onChanged: (_) {},
            itemStyle: const LiquidGlassTabItemStyle(
              selectedColor: Colors.white,
              unselectedColor: Colors.white,
            ),
            style: LiquidGlassTabBar.defaultStyle
                .copyWith(adaptivity: _adaptivity(Brightness.dark)),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Identical colors = no accent: BOTH cells follow the adaptive
    // content color.
    expect(_iconColor(tester, Icons.home_rounded), _onDark);
    expect(_iconColor(tester, Icons.search_rounded), _onDark);
  });

  testWidgets('adaptivity off: cells keep the configured item colors',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassTabBar(
            items: _items,
            selectedIndex: 0,
            onChanged: (_) {},
            itemStyle: const LiquidGlassTabItemStyle(
              selectedColor: Colors.amber,
              unselectedColor: Colors.teal,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(_iconColor(tester, Icons.home_rounded), Colors.amber);
    expect(_iconColor(tester, Icons.search_rounded), Colors.teal);
  });

  // ── the static selection pill ────────────────────────────────
  // It sits ON the bar's capsule, so it flips on the BAR's verdict and
  // contrasts the capsule rather than the page. Its palette is its own,
  // never the bar's — the two point opposite ways.

  /// The rendered fill of the flat selection pill — read off the
  /// painter that actually draws it, not off a style object, so the
  /// test proves the color reached the canvas.
  Color? pillFill(WidgetTester tester) {
    for (final CustomPaint p in tester.widgetList<CustomPaint>(find.descendant(
      of: find.byType(LiquidGlassTabBar),
      matching: find.byType(CustomPaint),
    ))) {
      final CustomPainter? painter = p.painter;
      if (painter is LiquidGlassNavPillSurfacePainter) return painter.color;
    }
    return null;
  }

  /// A pill that has opted into flipping, on the shipped palette.
  const LiquidGlassTabPillStyle adaptivePill = LiquidGlassTabPillStyle(
    rest: LiquidGlassStyle(
      adaptivity: LiquidGlassTabPillStyle.defaultRestAdaptivity,
    ),
  );

  testWidgets("the bar's OWN adaptivity brings the pill with it",
      (tester) async {
    // `_bar` puts adaptivity on the bar's own style, and `pillStyle`
    // names no palette — the shipped pair applies.
    await tester.pumpWidget(_bar(verdict: Brightness.dark));
    await tester.pumpAndSettle();
    final Color? overDark = pillFill(tester);

    await tester.pumpWidget(_bar(verdict: Brightness.light));
    await tester.pumpAndSettle();
    final Color? overLight = pillFill(tester);

    expect(overDark, isNotNull, reason: 'no pill fill found');
    expect(overDark, isNot(overLight), reason: 'the pill never flipped');
    // Light over a dark page, dark over a light one — the polarity that
    // contrasts the capsule, not the page.
    expect(overDark,
        LiquidGlassTabPillStyle.defaultRestAdaptivity.glassColorOnDark);
    expect(overLight,
        LiquidGlassTabPillStyle.defaultRestAdaptivity.glassColorOnLight);
  });

  testWidgets('rest.adaptivity still overrides the shipped palette',
      (tester) async {
    await tester.pumpWidget(
        _bar(verdict: Brightness.dark, pillStyle: adaptivePill));
    await tester.pumpAndSettle();
    expect(pillFill(tester),
        LiquidGlassTabPillStyle.defaultRestAdaptivity.glassColorOnDark);
  });

  testWidgets('an INHERITED adaptivity reaches the pill', (tester) async {
    // The pill contrasts the CAPSULE, and the capsule flips on an
    // inherited verdict exactly as it does on the bar's own. A fill that
    // stayed put would leave a light pill sitting on a darkened bar.
    final Map<Brightness, Color?> got = <Brightness, Color?>{};
    for (final Brightness v in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LiquidGlassAdaptiveArea(
            adaptivity: _adaptivity(v),
            child: Center(
              child: LiquidGlassTabBar(
                items: _items,
                selectedIndex: 0,
                onChanged: (_) {},
                // No adaptivity of its own — only the area's.
                itemStyle:
                    const LiquidGlassTabItemStyle(selectedColor: _accent),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      got[v] = pillFill(tester);
    }
    expect(got[Brightness.dark],
        LiquidGlassTabPillStyle.defaultRestAdaptivity.glassColorOnDark);
    expect(got[Brightness.light],
        LiquidGlassTabPillStyle.defaultRestAdaptivity.glassColorOnLight);
  });

  testWidgets('adaptivity.none holds a chosen fill under an inherited verdict',
      (tester) async {
    // The opt-out for a caller who picked the fill deliberately: the
    // flip is on by default, so refusing it has to be sayable.
    const Color mine = Color(0xFF123456);
    for (final Brightness v in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LiquidGlassAdaptiveArea(
            adaptivity: _adaptivity(v),
            child: Center(
              child: LiquidGlassTabBar(
                items: _items,
                selectedIndex: 0,
                onChanged: (_) {},
                pillStyle: const LiquidGlassTabPillStyle(
                  rest: LiquidGlassStyle(
                    adaptivity: LiquidGlassAdaptivity.none,
                    appearance: LiquidGlassAppearance(color: mine),
                  ),
                ),
                itemStyle:
                    const LiquidGlassTabItemStyle(selectedColor: _accent),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(pillFill(tester), mine,
          reason: 'adaptivity.none still repainted the pill on $v');
    }
  });

  testWidgets('the moving pill lands on the fill the flat pill paints',
      (tester) async {
    // The glass pill lerps INTO the rest fill and the flat pill is
    // painted in it. If only one of the two followed the verdict, the
    // hand-over would swap one colour for another in a single frame —
    // which is exactly what shipped when only the flat pill was fixed.
    // The glass tier only exists under a host that calls
    // `buildGlassPillBar` — a bare bar builds the flat tier — and it runs
    // a capture ticker, so `pumpAndSettle` would never return here.
    int index = 0;
    await tester.pumpWidget(StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => MaterialApp(
        home: LiquidGlassScaffold(
          adaptivity:
              LiquidGlassScaffoldAdaptivity(_adaptivity(Brightness.dark)),
          body: const ColoredBox(color: Colors.black),
          bottomNavigationBar: LiquidGlassTabBar(
            items: _items,
            selectedIndex: index,
            onChanged: (int i) => setState(() => index = i),
            pillStyle:
                const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.both),
            itemStyle: const LiquidGlassTabItemStyle(selectedColor: _accent),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.search_rounded), warnIfMissed: false);
    // Mid-travel, where the glass pill is mounted and carrying the
    // endpoint it is heading for.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final Iterable<LiquidGlassNavBarMotionPill> moving =
        tester.widgetList<LiquidGlassNavBarMotionPill>(
            find.byType(LiquidGlassNavBarMotionPill));
    expect(moving, isNotEmpty, reason: 'the glass pill never mounted');
    expect(
      moving.first.restStyle.appearance.color,
      LiquidGlassTabPillStyle.defaultRestAdaptivity.glassColorOnDark,
      reason: 'the glass pill is heading for a different colour than the '
          'flat pill paints',
    );
  });

  testWidgets('rest.adaptivity names the pill palette', (tester) async {
    const Color mine = Color(0xFF00FF00);
    await tester.pumpWidget(_bar(
      verdict: Brightness.dark,
      pillStyle: const LiquidGlassTabPillStyle(
        rest: LiquidGlassStyle(
          adaptivity: LiquidGlassAdaptivity(glassColorOnDark: mine),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(pillFill(tester), mine);
  });

  testWidgets('a bar with no adaptivity keeps its fixed pill', (tester) async {
    // The flip is opt-in with the bar: a plain bar must not start
    // repainting its pill on a verdict it never asked for.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassTabBar(
            items: _items,
            selectedIndex: 0,
            onChanged: (_) {},
            pillStyle: const LiquidGlassTabPillStyle(color: Color(0xFF123456)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(pillFill(tester), const Color(0xFF123456));
  });
}
