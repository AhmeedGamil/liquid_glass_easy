import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity_driver.dart';

// LiquidGlassAdaptivityController: runtime pause/resume. Disabled =
// HOLD (palette freezes, sampling stops, link/sampled verdicts are
// ignored; manual still applies); enable() resumes and the catch-up
// verdict ANIMATES in.

const _cDark = Color(0xFF102030); // contentColorOnDark
const _cLight = Color(0xFFF0E0D0); // contentColorOnLight

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disabled: sampled luminance is held; resume applies and animates',
      () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final adaptivity = LiquidGlassAdaptivity(controller: adaptCtrl);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);

    d.onLuminance(0.2); // dark sample while held → dropped
    expect(d.verdict, isNull);
    expect(d.flipT, 0.0); // still on the (light) guess

    adaptCtrl.enable();
    // The owning widget rebuilds (onResync) and re-syncs; then sampling
    // resumes and the next sample decides.
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);
    d.onLuminance(0.2);
    expect(d.verdict, Brightness.dark);
    expect(d.flipT, lessThan(1.0)); // animates in, no snap
    d.dispose();
  });

  test('disabled: link verdicts are held; resume catches up ANIMATED even '
      'though it resolves inside sync', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final link = LiquidGlassAdaptivityLink();
    final adaptivity =
        LiquidGlassAdaptivity(controller: adaptCtrl, link: link);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);

    link.value = Brightness.dark; // publisher flips while held
    expect(d.verdict, isNull);

    adaptCtrl.enable();
    d.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);
    expect(d.verdict, Brightness.dark);
    // The held guess was on screen — the catch-up must not snap.
    expect(d.flipT, lessThan(1.0));
    d.dispose();
    link.dispose();
  });

  test('a manual verdict still applies while disabled (explicit override, '
      'not adaptation)', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(
      LiquidGlassAdaptivity(
          controller: adaptCtrl, permanentBrightness: Brightness.dark),
      canSample: true,
      platformBrightness: Brightness.light,
    );
    expect(d.verdict, Brightness.dark);
    d.dispose();
  });

  test('toggling notifies onResync (enable and disable)', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: true);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    int resyncs = 0;
    d.onResync = () => resyncs++;
    d.sync(LiquidGlassAdaptivity(controller: adaptCtrl),
        canSample: true, platformBrightness: Brightness.light);

    adaptCtrl.disable();
    expect(resyncs, 1);
    adaptCtrl.disable(); // no-op — already disabled
    expect(resyncs, 1);
    adaptCtrl.enable();
    expect(resyncs, 2);
    d.dispose();
    adaptCtrl.enable(); // disposed driver unsubscribed — must not throw
  });

  testWidgets(
      'lens: disabled holds the entry palette; enable() adapts through the '
      'public API', (tester) async {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final link = LiquidGlassAdaptivityLink();

    await tester.pumpWidget(MaterialApp(
      home: LiquidGlassLens(
        style: LiquidGlassStyle(
          adaptivity: LiquidGlassAdaptivity(
            controller: adaptCtrl,
            link: link,
            initialBrightness: Brightness.light,
            contentColorOnDark: _cDark,
            contentColorOnLight: _cLight,
          ),
        ),
        child: const Icon(Icons.star_rounded),
      ),
    ));
    await tester.pump();

    Color? iconColor() =>
        IconTheme.of(tester.element(find.byIcon(Icons.star_rounded))).color;

    // Publisher flips while held → the lens stays on the light guess.
    link.value = Brightness.dark;
    await tester.pump();
    await tester.pump();
    expect(iconColor(), _cLight);

    // enable() → resync → catch-up verdict animates to the dark palette.
    adaptCtrl.enable();
    await tester.pumpAndSettle();
    expect(iconColor(), _cDark);

    await tester.pumpWidget(const SizedBox());
    link.dispose();
  });
}
