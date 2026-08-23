import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// LiquidGlassScaffoldAdaptivity, the strips-and-palettes contract:
//
//  • the top/bottom strips exist ONLY to judge the system bars — they
//    never contain the app bar, the bottom bar or the action;
//  • the config's palettes ARE inherited by that chrome, which then
//    resolves its own verdict from the background behind itself;
//  • the config's LINK is never inherited — carrying it on a surface's
//    own adaptivity is the one way to couple that surface to a strip.

const _cDark = Color(0xFF102030); // contentColorOnDark
const _cLight = Color(0xFFF0E0D0); // contentColorOnLight

const _palettes = LiquidGlassAdaptivity(
  contentColorOnDark: _cDark,
  contentColorOnLight: _cLight,
  initialBrightness: Brightness.light,
  duration: Duration.zero,
);

const _dark = LiquidGlassAdaptivity(
  contentColorOnDark: _cDark,
  contentColorOnLight: _cLight,
  permanentBrightness: Brightness.dark,
  duration: Duration.zero,
);

Color? _iconColor(WidgetTester tester, IconData icon) =>
    IconTheme.of(tester.element(find.byIcon(icon))).color;

/// The cyan debugBounds outline a strip paints when the flag is on.
bool _isDebugOutline(Widget w) {
  if (w is! DecoratedBox) return false;
  final Decoration deco = w.decoration;
  return deco is BoxDecoration &&
      deco.border is Border &&
      (deco.border as Border).top.color == const Color(0xFF00FFFF);
}

/// A plain (non glass-pill) tab bar, so the scaffold takes the path
/// where it lays the bar out itself.
LiquidGlassTabBar _plainBar() => LiquidGlassTabBar(
      items: const [
        LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
        LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Find'),
      ],
      selectedIndex: 0,
      onChanged: (_) {},
      pillStyle: const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.none),
    );

void main() {
  testWidgets('the strips never capture the chrome', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.both,
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
        appBar: const LiquidGlassAppBar(actions: [Icon(Icons.search_rounded)]),
        bottomNavigationBar: _plainBar(),
        bottomNavigationBarAction:
            const LiquidGlassTabBarAction(icon: Icons.add_rounded),
      ),
    ));
    await tester.pump();

    // Both strips exist (systemChrome asked for both sides)…
    expect(find.byType(LiquidGlassAdaptiveArea), findsNWidgets(2));
    // …and none of the chrome sits inside one.
    for (final Finder chrome in <Finder>[
      find.byType(LiquidGlassAppBar),
      find.byType(LiquidGlassTabBar),
      find.byType(LiquidGlassTabBarAction),
    ]) {
      expect(
        find.ancestor(
            of: chrome, matching: find.byType(LiquidGlassAdaptiveArea)),
        findsNothing,
      );
    }
  });

  testWidgets('chrome inherits the config palettes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
        appBar: const LiquidGlassAppBar(actions: [Icon(Icons.search_rounded)]),
        bottomNavigationBarAction:
            const LiquidGlassTabBarAction(icon: Icons.add_rounded),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // A manual dark verdict in the config reaches both surfaces.
    expect(_iconColor(tester, Icons.search_rounded), _cDark);
    expect(_iconColor(tester, Icons.add_rounded), _cDark);
  });

  testWidgets('the config link is NOT inherited by the chrome',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);

    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: LiquidGlassScaffoldAdaptivity(_palettes,
            bottomFollowLink: link),
        body: const ColoredBox(color: Colors.black),
        appBar: const LiquidGlassAppBar(actions: [Icon(Icons.search_rounded)]),
      ),
    ));
    await tester.pump();
    expect(_iconColor(tester, Icons.search_rounded), _cLight);

    // The link drives the STRIP only. An app bar that inherited it would
    // flip; this one must not — it judges its own backdrop.
    link.value = Brightness.dark;
    await tester.pump();
    await tester.pump();
    expect(_iconColor(tester, Icons.search_rounded), _cLight);
  });

  testWidgets('a surface carrying the strip link DOES follow it',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);

    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: const LiquidGlassScaffoldAdaptivity(_palettes),
        body: const ColoredBox(color: Colors.black),
        appBar: LiquidGlassAppBar(
          actions: const [Icon(Icons.search_rounded)],
          style: LiquidGlassStyle(
            adaptivity: LiquidGlassAdaptivity(
              contentColorOnDark: _cDark,
              contentColorOnLight: _cLight,
              initialBrightness: Brightness.light,
              duration: Duration.zero,
              link: link,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(_iconColor(tester, Icons.search_rounded), _cLight);

    link.value = Brightness.dark;
    await tester.pump();
    await tester.pump();
    expect(_iconColor(tester, Icons.search_rounded), _cDark);
  });

  testWidgets('LiquidGlassAdaptivity.none escapes the inherited palettes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
        appBar: const LiquidGlassAppBar(
          actions: [Icon(Icons.search_rounded)],
          style: LiquidGlassStyle(adaptivity: LiquidGlassAdaptivity.none),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Opted out: back to the app bar's plain white foreground.
    expect(_iconColor(tester, Icons.search_rounded), Colors.white);
  });

  testWidgets('no chrome side and no link means no strip at all',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
        appBar: const LiquidGlassAppBar(actions: [Icon(Icons.search_rounded)]),
      ),
    ));
    await tester.pump();

    expect(find.byType(LiquidGlassAdaptiveArea), findsNothing);
    // The palettes still reach the chrome — inheritance is independent
    // of whether any strip was pinned.
    await tester.pump();
    expect(_iconColor(tester, Icons.search_rounded), _cDark);
  });

  testWidgets('a follow link alone pins nothing — a strip only ever '
      'exists to annotate', (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);

    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: LiquidGlassScaffoldAdaptivity(_palettes,
            topFollowLink: link),
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();

    expect(find.byType(LiquidGlassAdaptiveArea), findsNothing);
  });

  testWidgets('a following strip mirrors the link and never samples',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);

    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.statusBar,
        adaptivity: LiquidGlassScaffoldAdaptivity(_palettes,
            topFollowLink: link),
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();

    // Following, so there is no judging area in the tree at all…
    expect(find.byType(LiquidGlassAdaptiveArea), findsNothing);
    // …and the annotation tracks whatever the link carries.
    link.value = Brightness.dark;
    await tester.pump();
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first)
          .value
          .statusBarIconBrightness,
      Brightness.light, // dark backdrop → light icons
    );
  });

  testWidgets('a strip floors its height so a zero inset still samples',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.statusBar,
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();

    // No safe-area inset in the test harness, so the floor applies
    // instead of a zero-height (unsamplable) strip.
    expect(tester.getSize(find.byType(LiquidGlassAdaptiveArea)).height, 24.0);
  });

  testWidgets('an explicit extent overrides the strip height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.statusBar,
        adaptivity:
            const LiquidGlassScaffoldAdaptivity(_dark, topHeight: 70),
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();

    expect(tester.getSize(find.byType(LiquidGlassAdaptiveArea)).height, 70.0);
  });

  testWidgets('debugBounds outlines every pinned strip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.both,
        adaptivity:
            const LiquidGlassScaffoldAdaptivity(_dark, debugBounds: true),
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();

    expect(find.byWidgetPredicate(_isDebugOutline), findsNWidgets(2));
  });

  testWidgets('debugBounds is off by default', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.both,
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();

    expect(find.byWidgetPredicate(_isDebugOutline), findsNothing);
  });

  testWidgets('the palettes win over an explicit foreground',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        adaptivity: const LiquidGlassScaffoldAdaptivity(_dark),
        body: const ColoredBox(color: Colors.black),
        bottomNavigationBarAction: const LiquidGlassTabBarAction(
          icon: Icons.add_rounded,
          foregroundColor: Color(0xFFFF0000),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // The glyph carries NO color of its own: adaptivity outranks the
    // named foreground, so it is handed to the ambient adaptive
    // IconTheme instead of being baked in.
    expect(tester.widget<Icon>(find.byIcon(Icons.add_rounded)).color, isNull);
  });
}
