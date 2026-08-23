import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity_driver.dart';

// Direct unit tests for the shared verdict machine — the sampled-path
// behaviors (hysteresis, dead zone, first-sample rule) that widget
// tests can't drive without a live capture pipeline.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LiquidGlassAdaptivityDriver sampledDriver([
    LiquidGlassAdaptivity adaptivity = const LiquidGlassAdaptivity(),
  ]) {
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(
      adaptivity,
      canSample: true,
      platformBrightness: Brightness.light,
    );
    return d;
  }

  test('by default the verdict just follows the neutral split', () {
    // Shipped thresholds both sit at 0.50, so there is no band to hold
    // inside: the background is dark or light, nothing between.
    final d = sampledDriver();
    expect(d.verdict, isNull); // sampled mode: nothing until a sample
    d.onLuminance(0.3);
    expect(d.verdict, Brightness.dark);
    // A sampled first verdict arrives after paint → it ANIMATES in
    // (mount-flash fix), so the flip position hasn't jumped to 1.0.
    expect(d.flipT, lessThan(1.0));
    d.onLuminance(0.51);
    expect(d.verdict, Brightness.light); // a hair over is enough
    d.onLuminance(0.49);
    expect(d.verdict, Brightness.dark); // and a hair under flips back
    // Landing EXACTLY on the split is the one place it holds, so a
    // background parked there still cannot chatter.
    d.onLuminance(0.50);
    expect(d.verdict, Brightness.dark);
    d.dispose();
  });

  test('widening the thresholds opens a dead zone that holds further out',
      () {
    final d = sampledDriver(const LiquidGlassAdaptivity(
      darkBelow: 0.45,
      lightAbove: 0.55,
    ));
    d.onLuminance(0.3);
    expect(d.verdict, Brightness.dark);
    d.onLuminance(0.50);
    expect(d.verdict, Brightness.dark); // dead zone → hold
    d.onLuminance(0.54);
    expect(d.verdict, Brightness.dark); // still below the light bound
    d.onLuminance(0.56);
    expect(d.verdict, Brightness.light); // crossed
    d.onLuminance(0.46);
    expect(d.verdict, Brightness.light); // hold — above the dark bound
    d.onLuminance(0.44);
    expect(d.verdict, Brightness.dark); // crossed back
    d.dispose();
  });

  test('the verdict runs on the majority vote, not the mean', () {
    final d = sampledDriver();
    // Bimodal region: mean is a useless 0.5, but 80% of pixels read
    // dark → verdict dark.
    d.onLuminance(0.5, lightFraction: 0.2);
    expect(d.verdict, Brightness.dark);
    // Same mean, vote flips to 80% light → verdict light.
    d.onLuminance(0.5, lightFraction: 0.8);
    expect(d.verdict, Brightness.light);
    // Near-tie vote inside the band → hold the current verdict.
    d.onLuminance(0.5, lightFraction: 0.5);
    expect(d.verdict, Brightness.light);
    d.dispose();
  });

  test('custom darkBelow/lightAbove narrow the hysteresis band', () {
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(
      const LiquidGlassAdaptivity(darkBelow: 0.48, lightAbove: 0.52),
      canSample: true,
      platformBrightness: Brightness.light,
    );
    d.onLuminance(0.3);
    expect(d.verdict, Brightness.dark);
    // 0.51 sits in the DEFAULT dead zone (0.45–0.55) but crosses the
    // narrowed light bound (0.52)? No — 0.51 < 0.52 → still held.
    d.onLuminance(0.51);
    expect(d.verdict, Brightness.dark);
    // 0.53 would be held by the default band, but crosses 0.52 here.
    d.onLuminance(0.53);
    expect(d.verdict, Brightness.light);
    // 0.47 would be held by the default band, but crosses 0.48 here.
    d.onLuminance(0.47);
    expect(d.verdict, Brightness.dark);
    d.dispose();
  });

  test('first sample inside the dead zone picks the nearest side', () {
    final a = sampledDriver();
    a.onLuminance(0.48);
    expect(a.verdict, Brightness.dark);
    a.dispose();

    final b = sampledDriver();
    b.onLuminance(0.52);
    expect(b.verdict, Brightness.light);
    b.dispose();
  });

  test('sampled mode has no verdict until luminance arrives '
      '(no premature platform fallback)', () {
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(
      const LiquidGlassAdaptivity(),
      canSample: true,
      platformBrightness: Brightness.dark,
    );
    expect(d.verdict, isNull);
    d.dispose();
  });

  test('a manual verdict ignores samples entirely', () {
    final d = LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    d.sync(
      const LiquidGlassAdaptivity(permanentBrightness: Brightness.dark),
      canSample: true,
      platformBrightness: Brightness.light,
    );
    expect(d.verdict, Brightness.dark);
    d.onLuminance(0.9); // bright sample — must not flip a manual verdict
    expect(d.verdict, Brightness.dark);
    d.dispose();
  });

  test('onLuminance after dispose is a no-op', () {
    final d = sampledDriver();
    d.dispose();
    expect(() => d.onLuminance(0.2), returnsNormally);
  });

  test('the shipped palettes agree with the background, contrast in content',
      () {
    // The glass sits IN the page, so it takes the page's side: a dark
    // veil over a dark backdrop, a light one over a light backdrop.
    // Inverting that reads as a bright chip stamped on the page. Only
    // the content crosses over, because it has to stay legible.
    const LiquidGlassAdaptivity a = LiquidGlassAdaptivity();

    double lum(Color c) => (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b);

    expect(lum(a.glassColorOnDark), lessThan(0.5),
        reason: 'the dark-backdrop veil should darken, not lighten');
    expect(lum(a.glassColorOnLight), greaterThan(0.5),
        reason: 'the light-backdrop veil should lighten, not darken');
    expect(lum(a.contentColorOnDark), greaterThan(0.5),
        reason: 'content over a dark backdrop has to read light');
    expect(lum(a.contentColorOnLight), lessThan(0.5),
        reason: 'content over a light backdrop has to read dark');

    // Every surface the package ships uses the same disabled sentinel
    // as its inert stand-in, so it must carry the same palette.
    expect(LiquidGlassAdaptivity.none.glassColorOnDark, a.glassColorOnDark);
    expect(
        LiquidGlassAdaptivity.none.contentColorOnDark, a.contentColorOnDark);
    expect(LiquidGlassAdaptivity.none.glassColorOnLight, a.glassColorOnLight);
    expect(
        LiquidGlassAdaptivity.none.contentColorOnLight, a.contentColorOnLight);
  });
}
