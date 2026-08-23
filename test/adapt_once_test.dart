import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity_driver.dart';

// LiquidGlassAdaptivityController.adaptOnce(): while disabled, every
// attached driver takes exactly ONE look (sample, link delivery, or
// platform fallback), animates to it, then holds again — `enabled`
// stays false throughout. A delivered look is consumed even when it
// moves nothing (dead zone / unchanged verdict).

const _cDark = Color(0xFF102030); // contentColorOnDark
const _cLight = Color(0xFFF0E0D0); // contentColorOnLight

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('adaptOnce is a no-op while enabled', () {
    final adaptCtrl = LiquidGlassAdaptivityController();
    int notifications = 0;
    adaptCtrl.addListener(() => notifications++);
    adaptCtrl.adaptOnce();
    expect(adaptCtrl.refreshGeneration, 0);
    expect(notifications, 0);
  });

  test('held + adaptOnce: exactly one sample lands, animated; sampling is '
      'wanted only until delivery', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final adaptivity = LiquidGlassAdaptivity(controller: adaptCtrl);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    int resyncs = 0;
    d.onResync = () => resyncs++;
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);

    bool wanted() => d.samplingWanted(adaptivity,
        following: false, canRegister: true);

    d.onLuminance(0.2); // held, no request → dropped
    expect(d.verdict, isNull);
    expect(wanted(), isFalse);

    adaptCtrl.adaptOnce();
    expect(resyncs, 1); // owner rebuilds → registers
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);
    expect(wanted(), isTrue); // stays registered until the look lands

    d.onLuminance(0.2); // the one look
    expect(d.verdict, Brightness.dark);
    expect(d.flipT, lessThan(1.0)); // animates in, no snap
    expect(wanted(), isFalse); // consumed → owner unregisters
    expect(resyncs, 2);

    d.onLuminance(0.9); // held again → dropped
    expect(d.verdict, Brightness.dark);
    d.dispose();
  });

  test('a dead-zone sample still consumes the one look', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final adaptivity = LiquidGlassAdaptivity(controller: adaptCtrl);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);

    adaptCtrl.adaptOnce();
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);
    d.onLuminance(0.2); // seed dark
    expect(d.verdict, Brightness.dark);

    adaptCtrl.adaptOnce();
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);
    expect(
        d.samplingWanted(adaptivity, following: false, canRegister: true),
        isTrue);
    d.onLuminance(0.5); // dead zone (0.45–0.55): verdict keeps, look taken
    expect(d.verdict, Brightness.dark);
    expect(
        d.samplingWanted(adaptivity, following: false, canRegister: true),
        isFalse);
    d.onLuminance(0.9); // held → dropped
    expect(d.verdict, Brightness.dark);
    d.dispose();
  });

  test('publisher one-shot with an UNCHANGED verdict re-delivers the link '
      'so held followers complete the same request', () {
    final adaptCtrl = LiquidGlassAdaptivityController();
    final link = LiquidGlassAdaptivityLink();
    final adaptivity =
        LiquidGlassAdaptivity(controller: adaptCtrl, link: link);
    final p = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    final f = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    p.sync(adaptivity,
        canSample: true, platformBrightness: Brightness.light, publish: link);
    f.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);

    p.onLuminance(0.2); // live: both seed dark through the link
    expect(f.verdict, Brightness.dark);

    adaptCtrl.disable();
    p.sync(adaptivity,
        canSample: true, platformBrightness: Brightness.light, publish: link);
    f.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);

    adaptCtrl.adaptOnce();
    p.sync(adaptivity,
        canSample: true, platformBrightness: Brightness.light, publish: link);
    f.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);

    p.onLuminance(0.1); // still dark — no value change on the link
    expect(p.verdict, Brightness.dark);
    expect(f.verdict, Brightness.dark);

    // Both looks are consumed: a later app-driven link flip is held out.
    link.value = Brightness.light;
    expect(f.verdict, Brightness.dark);
    expect(
        p.samplingWanted(adaptivity, following: false, canRegister: true),
        isFalse);
    p.dispose();
    f.dispose();
    link.dispose();
  });

  test('publisher one-shot with a CHANGED verdict flips followers in '
      'lockstep, consumed', () {
    final adaptCtrl = LiquidGlassAdaptivityController();
    final link = LiquidGlassAdaptivityLink();
    final adaptivity =
        LiquidGlassAdaptivity(controller: adaptCtrl, link: link);
    final p = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    final f = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    p.sync(adaptivity,
        canSample: true, platformBrightness: Brightness.light, publish: link);
    f.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);
    p.onLuminance(0.2); // seed dark
    expect(f.verdict, Brightness.dark);

    adaptCtrl.disable();
    adaptCtrl.adaptOnce();
    p.sync(adaptivity,
        canSample: true, platformBrightness: Brightness.light, publish: link);
    f.sync(adaptivity,
        canSample: false, platformBrightness: Brightness.light, follow: link);

    p.onLuminance(0.9); // background flipped while held → light
    expect(p.verdict, Brightness.light);
    expect(f.verdict, Brightness.light);

    link.value = Brightness.dark; // consumed → held out again
    expect(f.verdict, Brightness.light);
    p.dispose();
    f.dispose();
    link.dispose();
  });

  test('enable() voids a pending one-shot (continuous supersedes)', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final adaptivity = LiquidGlassAdaptivity(controller: adaptCtrl);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);

    adaptCtrl.adaptOnce();
    adaptCtrl.enable();
    adaptCtrl.disable();
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);
    expect(
        d.samplingWanted(adaptivity, following: false, canRegister: true),
        isFalse); // no stale pending keeping the sampler alive
    d.onLuminance(0.2);
    expect(d.verdict, isNull); // held — the old request is gone
    d.dispose();
  });

  test('a fresh driver never reads controller history as a request', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    adaptCtrl.adaptOnce(); // before the widget existed
    final adaptivity = LiquidGlassAdaptivity(controller: adaptCtrl);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(adaptivity, canSample: true, platformBrightness: Brightness.light);
    expect(
        d.samplingWanted(adaptivity, following: false, canRegister: true),
        isFalse);
    d.onLuminance(0.2);
    expect(d.verdict, isNull);
    d.dispose();
  });

  test('no sampler and no link: the one look falls back to the platform '
      'brightness inside sync, animated', () {
    final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
    final adaptivity = LiquidGlassAdaptivity(
        controller: adaptCtrl, initialBrightness: Brightness.light);
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(adaptivity, canSample: false, platformBrightness: Brightness.dark);
    expect(d.verdict, isNull); // held on the light guess
    expect(d.flipT, 0.0);

    adaptCtrl.adaptOnce();
    d.sync(adaptivity, canSample: false, platformBrightness: Brightness.dark);
    expect(d.verdict, Brightness.dark);
    expect(d.flipT, lessThan(1.0)); // the held guess was on screen
    d.dispose();
  });

  testWidgets(
      'lens follower: adaptOnce completes on the publisher re-delivery; '
      'the palette then holds again', (tester) async {
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
    expect(iconColor(), _cLight);

    // adaptOnce → the next link delivery (here a publisher finishing an
    // unchanged one-shot re-delivers) is the lens's one look.
    adaptCtrl.adaptOnce();
    await tester.pump();
    link.republish();
    await tester.pumpAndSettle();
    expect(iconColor(), _cDark);

    // Consumed — the palette holds against further link traffic.
    link.value = Brightness.light;
    await tester.pump();
    await tester.pump();
    expect(iconColor(), _cDark);

    await tester.pumpWidget(const SizedBox());
    link.dispose();
  });
}
