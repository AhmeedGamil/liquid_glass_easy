import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// Characterization tests for the adaptivity verdict machine, pinned
// against the behavior of the shipped widgets. They define
// "functionality unchanged" for the driver refactor: every behavior
// here must keep passing, unmodified, after the state machine moves
// into the shared driver.
//
// The sampled path (hysteresis / dead zone) can't be driven from a
// widget test without a live capture pipeline; those behaviors get
// direct unit tests on the driver once it exists.

const _cDark = Color(0xFF111111); // contentColorOnDark
const _cLight = Color(0xFFEEEEEE); // contentColorOnLight
const _gDark = Color(0xE0222222); // glassColorOnDark
const _gLight = Color(0xE0DDDDDD); // glassColorOnLight

LiquidGlassAdaptivity _adapt({
  Brightness? manual,
  Brightness? initial,
  LiquidGlassAdaptivityLink? link,
}) =>
    LiquidGlassAdaptivity(
      contentColorOnDark: _cDark,
      contentColorOnLight: _cLight,
      glassColorOnDark: _gDark,
      glassColorOnLight: _gLight,
      duration: const Duration(milliseconds: 200),
      permanentBrightness: manual,
      initialBrightness: initial,
      link: link,
    );

Widget _lensApp(LiquidGlassAdaptivity? adaptivity,
    {Brightness platform = Brightness.light}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(platformBrightness: platform),
      child: Center(
        child: SizedBox(
          width: 200,
          height: 80,
          child: LiquidGlassLens(
            style: LiquidGlassStyle(adaptivity: adaptivity),
            child: const Icon(Icons.circle),
          ),
        ),
      ),
    ),
  );
}

/// The adaptive content color as delivered to the lens/band child.
Color? _contentColor(WidgetTester tester) =>
    IconTheme.of(tester.element(find.byIcon(Icons.circle))).color;

void main() {
  testWidgets('manual verdict applies instantly at mount (no flash)',
      (tester) async {
    await tester.pumpWidget(_lensApp(_adapt(manual: Brightness.dark)));
    await tester.pump();
    expect(_contentColor(tester), _cDark);
  });

  testWidgets(
      'initialBrightness shows before the first verdict; a confirming '
      'verdict causes no motion', (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);
    await tester.pumpWidget(
        _lensApp(_adapt(link: link, initial: Brightness.dark)));
    await tester.pump();

    // No verdict yet — the guess palette is already showing.
    expect(_contentColor(tester), _cDark);

    // The first verdict CONFIRMS the guess: nothing may move.
    link.value = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_contentColor(tester), _cDark);

    // A differing verdict animates away from the guess as usual.
    link.value = Brightness.light;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Color? mid = _contentColor(tester);
    expect(mid, isNot(_cDark));
    expect(mid, isNot(_cLight));
    await tester.pumpAndSettle();
    expect(_contentColor(tester), _cLight);
  });

  testWidgets('unset initialBrightness guesses the platform brightness',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);
    // Dark-mode device, no initialBrightness, no verdict yet: the
    // pre-verdict palette must be the dark one.
    await tester.pumpWidget(
        _lensApp(_adapt(link: link), platform: Brightness.dark));
    await tester.pump();
    expect(_contentColor(tester), _cDark);
  });

  testWidgets('first manual flip animates over the configured duration',
      (tester) async {
    await tester.pumpWidget(_lensApp(_adapt(manual: Brightness.dark)));
    await tester.pump();
    await tester.pumpWidget(_lensApp(_adapt(manual: Brightness.light)));
    await tester.pump(const Duration(milliseconds: 100));
    final Color? mid = _contentColor(tester);
    expect(mid, isNot(_cDark));
    expect(mid, isNot(_cLight));
    await tester.pumpAndSettle();
    expect(_contentColor(tester), _cLight);
  });

  testWidgets('disabling adaptivity resets: re-enable lands instantly',
      (tester) async {
    await tester.pumpWidget(_lensApp(_adapt(manual: Brightness.dark)));
    await tester.pumpAndSettle();
    expect(_contentColor(tester), _cDark);

    await tester.pumpWidget(_lensApp(null));
    await tester.pump();

    // Re-enabled with the opposite verdict: fresh seed, no animation.
    await tester.pumpWidget(_lensApp(_adapt(manual: Brightness.light)));
    await tester.pump();
    expect(_contentColor(tester), _cLight);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_contentColor(tester), _cLight);
  });

  testWidgets('platform brightness is the last-resort verdict',
      (tester) async {
    await tester.pumpWidget(_lensApp(_adapt(), platform: Brightness.dark));
    await tester.pump();
    expect(_contentColor(tester), _cDark);
  });

  testWidgets('an adaptive area publishes its verdict to its link',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassAdaptiveArea(
        adaptivity: _adapt(manual: Brightness.dark, link: link),
        child: const SizedBox.expand(),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(link.value, Brightness.dark);
  });

  testWidgets('a consumer with a link follows it (never publishes)',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);
    // A consumer holding a link + a manual verdict must NOT write to the
    // link — only areas publish.
    await tester
        .pumpWidget(_lensApp(_adapt(manual: Brightness.dark, link: link)));
    await tester.pump();
    await tester.pump();
    expect(link.value, isNull);
  });

  testWidgets(
      'adaptive widgets inside an area follow its verdict automatically',
      (tester) async {
    // The lens has its OWN palettes but no link and no manual verdict —
    // being inside the area is enough to follow its (manual) verdict.
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassAdaptiveArea(
        adaptivity: LiquidGlassAdaptivity(
          permanentBrightness: Brightness.dark,
          duration: const Duration(milliseconds: 200),
        ),
        child: Center(
          child: SizedBox(
            width: 200,
            height: 80,
            child: LiquidGlassLens(
              style: LiquidGlassStyle(adaptivity: _adapt()),
              child: const Icon(Icons.circle),
            ),
          ),
        ),
      ),
    ));
    // The area publishes post-frame; the lens animates into the verdict.
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_contentColor(tester), _cDark);
  });

  testWidgets('widgets with no adaptivity inherit the area\'s wholesale',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassAdaptiveArea(
        adaptivity: _adapt(manual: Brightness.dark),
        child: Center(
          child: SizedBox(
            width: 200,
            height: 80,
            child: LiquidGlassLens(
              // No adaptivity of its own at all.
              style: const LiquidGlassStyle(),
              child: const Icon(Icons.circle),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    // Inherited palettes + the area's verdict.
    expect(_contentColor(tester), _cDark);
  });

  testWidgets('a follower animates into linked verdicts (no snap)',
      (tester) async {
    final link = LiquidGlassAdaptivityLink();
    addTearDown(link.dispose);
    await tester.pumpWidget(_lensApp(_adapt(link: link)));
    await tester.pump();

    // First linked verdict arrives AFTER frames already painted the
    // default palette — it must animate in, not snap (the mount-flash
    // fix). Warm-up pump: triggered between frames, first tick is
    // elapsed-zero.
    link.value = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Color? seedMid = _contentColor(tester);
    expect(seedMid, isNot(_cDark));
    expect(seedMid, isNot(_cLight));
    await tester.pumpAndSettle();
    expect(_contentColor(tester), _cDark);

    // Later flips: animated as always.
    link.value = Brightness.light;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Color? mid = _contentColor(tester);
    expect(mid, isNot(_cDark));
    expect(mid, isNot(_cLight));
    await tester.pumpAndSettle();
    expect(_contentColor(tester), _cLight);
  });

}
