import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// LiquidGlassSystemChrome: the adaptivity verdict also drives the
// system bars' icon brightness, declaratively via AnnotatedRegion.
// Dark backdrop → light icons. `none` (default) adds nothing at all.

/// The first liquid-glass chrome annotation inside [within].
SystemUiOverlayStyle _chrome(WidgetTester tester, Finder within) =>
    tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(find
            .descendant(
                of: within,
                matching:
                    find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
            .first)
        .value;

Finder get _annotations =>
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>);

Widget _areaApp({
  required Brightness verdict,
  LiquidGlassSystemChrome chrome = LiquidGlassSystemChrome.navigationBar,
}) {
  return MaterialApp(
    home: Stack(fit: StackFit.expand, children: [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 120,
        child: LiquidGlassAdaptiveArea(
          adaptivity: LiquidGlassAdaptivity(permanentBrightness: verdict),
          systemChrome: chrome,
          child: const SizedBox.expand(),
        ),
      ),
    ]),
  );
}

void main() {
  testWidgets('area: dark verdict → light navigation icons',
      (tester) async {
    await tester.pumpWidget(_areaApp(verdict: Brightness.dark));
    await tester.pump();
    await tester.pump(); // manual verdict publishes post-frame

    final style = _chrome(tester, find.byType(LiquidGlassAdaptiveArea));
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    // navigationBar mode must not touch the status bar.
    expect(style.statusBarIconBrightness, isNull);
    expect(style.statusBarBrightness, isNull);
  });

  testWidgets('area: chrome flips when the verdict flips', (tester) async {
    await tester.pumpWidget(_areaApp(verdict: Brightness.dark));
    await tester.pumpAndSettle();
    expect(
        _chrome(tester, find.byType(LiquidGlassAdaptiveArea))
            .systemNavigationBarIconBrightness,
        Brightness.light);

    await tester.pumpWidget(_areaApp(verdict: Brightness.light));
    await tester.pumpAndSettle();
    expect(
        _chrome(tester, find.byType(LiquidGlassAdaptiveArea))
            .systemNavigationBarIconBrightness,
        Brightness.dark);
  });

  testWidgets('area: `both` styles both bars, `none` adds nothing',
      (tester) async {
    await tester.pumpWidget(_areaApp(
        verdict: Brightness.dark, chrome: LiquidGlassSystemChrome.both));
    await tester.pumpAndSettle();
    final style = _chrome(tester, find.byType(LiquidGlassAdaptiveArea));
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark); // iOS: bar = backdrop

    await tester.pumpWidget(_areaApp(
        verdict: Brightness.dark, chrome: LiquidGlassSystemChrome.none));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(LiquidGlassAdaptiveArea), matching: _annotations),
        findsNothing);
  });

  testWidgets(
      'scaffold plain path: systemChrome alone uses a chrome-only band — '
      'the bar is never wrapped', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.navigationBar,
        body: const ColoredBox(color: Colors.black),
        bottomNavigationBar: LiquidGlassTabBar(
          items: const [
            LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
            LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Find'),
          ],
          selectedIndex: 0,
          onChanged: (_) {},
          // The plain (single-lens) path: the glass-pill bar renders in
          // its own pipeline and annotates the chrome itself, which is
          // the sibling test below.
          pillStyle: const LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.none),
          style: LiquidGlassTabBar.defaultStyle.copyWith(
            adaptivity: const LiquidGlassAdaptivity(
                permanentBrightness: Brightness.dark),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Chrome no longer depends on the nav bar: the bar stays unwrapped…
    expect(
        find.ancestor(
            of: find.byType(LiquidGlassTabBar),
            matching: find.byType(LiquidGlassAdaptiveArea)),
        findsNothing);
    // …and an invisible chrome-only band carries the annotation.
    expect(find.byType(LiquidGlassAdaptiveArea), findsOneWidget);
    final style = _chrome(tester, find.byType(LiquidGlassScaffold));
    expect(style.systemNavigationBarIconBrightness, isNotNull);
  });

  testWidgets(
      'scaffold: the bottom strip drives the nav bar without capturing '
      'the chrome', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.navigationBar,
        adaptivity: const LiquidGlassScaffoldAdaptivity(
          LiquidGlassAdaptivity(permanentBrightness: Brightness.dark),
        ),
        body: const ColoredBox(color: Colors.black),
        bottomNavigationBar: LiquidGlassTabBar(
          items: const [
            LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
            LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Find'),
          ],
          selectedIndex: 0,
          onChanged: (_) {},
          pillStyle:
              const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.none),
        ),
        bottomNavigationBarAction:
            const LiquidGlassTabBarAction(icon: Icons.add_rounded),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Exactly one strip, and neither bottom slot lives inside it — the
    // strip judges the system bar's own band and nothing else.
    final Finder strip = find.byType(LiquidGlassAdaptiveArea);
    expect(strip, findsOneWidget);
    expect(
        find.ancestor(of: find.byType(LiquidGlassTabBar), matching: strip),
        findsNothing);
    expect(
        find.ancestor(
            of: find.byType(LiquidGlassTabBarAction), matching: strip),
        findsNothing);
    // It still annotates the navigation bar from its own verdict.
    final style = _chrome(tester, strip);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('scaffold: statusBar side uses a chrome-only top band',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.statusBar,
        body: const ColoredBox(color: Colors.black),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // One invisible strip exists just for the status bar.
    expect(find.byType(LiquidGlassAdaptiveArea), findsOneWidget);
    final style = _chrome(tester, find.byType(LiquidGlassAdaptiveArea));
    expect(style.statusBarIconBrightness, isNotNull);
    expect(style.systemNavigationBarIconBrightness, isNull);
  });

  testWidgets(
      'scaffold glass-pill path: the bottom strip annotates, not the bar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassScaffold(
        systemChrome: LiquidGlassSystemChrome.navigationBar,
        body: const ColoredBox(color: Colors.black),
        bottomNavigationBar: LiquidGlassTabBar(
          items: const [
            LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
            LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Find'),
          ],
          selectedIndex: 0,
          onChanged: (_) {},
          pillStyle:
              const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.both),
          style: LiquidGlassTabBar.defaultStyle.copyWith(
            adaptivity: const LiquidGlassAdaptivity(
                permanentBrightness: Brightness.dark),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // The bar renders in its own pipeline and judges only its capsule;
    // the system bar is driven by the strip carried in `outerChild`,
    // which samples through the bar's single inner sampler.
    final Finder strip = find.byType(LiquidGlassAdaptiveArea);
    expect(strip, findsOneWidget);
    expect(
        find.ancestor(of: find.byType(LiquidGlassTabBar), matching: strip),
        findsNothing);
    final style = _chrome(tester, find.byType(LiquidGlassScaffold));
    expect(style.systemNavigationBarIconBrightness, isNotNull);

    // Unmount cleanly (stops the capture pipelines) before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
