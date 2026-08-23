import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_adaptivity_driver.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LiquidGlassAdaptivityDriver driver([LiquidGlassAdaptivity? adaptivity]) {
    final LiquidGlassAdaptivityDriver result =
        LiquidGlassAdaptivityDriver(vsync: const TestVSync());
    result.sync(
      adaptivity ?? const LiquidGlassAdaptivity(),
      canSample: true,
      platformBrightness: Brightness.light,
    );
    return result;
  }

  group('background color science', () {
    test('linearizes sRGB before applying luminance weights', () {
      expect(liquidGlassRelativeLuminanceFromSrgb8(0, 0, 0), 0);
      expect(liquidGlassRelativeLuminanceFromSrgb8(255, 255, 255), 1);
      expect(
        liquidGlassRelativeLuminanceFromSrgb8(255, 0, 0),
        closeTo(0.2126, 0.000001),
      );
      expect(
        liquidGlassRelativeLuminanceFromSrgb8(128, 128, 128),
        closeTo(0.21586, 0.0001),
      );
    });

    test('converts relative luminance to perceptual CIE lightness', () {
      expect(liquidGlassPerceptualLightness(0), 0);
      expect(liquidGlassPerceptualLightness(1), 1);
      expect(
        liquidGlassPerceptualLightness(0.2126),
        closeTo(0.5324, 0.0001),
      );
    });

    test('area average retains magnitude instead of using majority bits', () {
      final LiquidGlassBackdropSample barelyLightMajority =
          LiquidGlassBackdropSample.fromLuminances(<double>[
        ...List<double>.filled(56, 0.20),
        ...List<double>.filled(44, 0.0),
      ]);

      expect(barelyLightMajority.lightFraction, 0.56);
      expect(barelyLightMajority.meanLightness, lessThan(0.47));

      final LiquidGlassAdaptivityDriver result = driver();
      result.onBackdropSample(barelyLightMajority);
      expect(result.verdict, Brightness.dark);
      result.dispose();
    });

    test('saturated red is classified from perception, not encoded bytes', () {
      final double redLuminance =
          liquidGlassRelativeLuminanceFromSrgb8(255, 0, 0);
      final LiquidGlassAdaptivityDriver result = driver();
      result.onBackdropSample(
          LiquidGlassBackdropSample.fromLuminances(<double>[redLuminance]));

      expect(result.verdict, Brightness.light);
      result.dispose();
    });
  });

  test('configured palette colors cannot change the background verdict', () {
    const LiquidGlassAdaptivity first = LiquidGlassAdaptivity(
      glassColorOnDark: Colors.black,
      contentColorOnDark: Colors.white,
      glassColorOnLight: Colors.white,
      contentColorOnLight: Colors.black,
    );
    const LiquidGlassAdaptivity reversed = LiquidGlassAdaptivity(
      glassColorOnDark: Colors.white,
      contentColorOnDark: Colors.black,
      glassColorOnLight: Colors.black,
      contentColorOnLight: Colors.white,
    );
    final LiquidGlassBackdropSample sample =
        LiquidGlassBackdropSample.fromLuminances(const <double>[0.9]);
    final LiquidGlassAdaptivityDriver a = driver(first);
    final LiquidGlassAdaptivityDriver b = driver(reversed);

    a.onBackdropSample(sample);
    b.onBackdropSample(sample);

    expect(a.verdict, Brightness.light);
    expect(b.verdict, Brightness.light);
    a.dispose();
    b.dispose();
  });

  test('a later flip needs two confirming samples', () {
    final LiquidGlassAdaptivityDriver result = driver();
    final LiquidGlassBackdropSample dark =
        LiquidGlassBackdropSample.fromLuminances(const <double>[0.0]);
    final LiquidGlassBackdropSample light =
        LiquidGlassBackdropSample.fromLuminances(const <double>[1.0]);

    result.onBackdropSample(dark);
    expect(result.verdict, Brightness.dark);

    result.onBackdropSample(light);
    expect(result.verdict, Brightness.dark);
    result.onBackdropSample(light);
    expect(result.verdict, Brightness.light);

    result.onBackdropSample(dark);
    expect(result.verdict, Brightness.light);
    result.onBackdropSample(dark);
    expect(result.verdict, Brightness.dark);
    result.dispose();
  });

  test('small regions raise the sampling ratio to a useful density', () {
    const LiquidGlassAdaptiveSampling sampling = LiquidGlassAdaptiveSampling(
      pixelRatio: 0.05,
      minimumRegionSamples: 8,
    );

    expect(
      liquidGlassAdaptiveCaptureRatio(
          sampling, const <Rect>[Rect.fromLTWH(0, 0, 40, 40)]),
      closeTo(0.2, 0.000001),
    );
    expect(
      liquidGlassAdaptiveCaptureRatio(
          sampling, const <Rect>[Rect.fromLTWH(0, 0, 400, 400)]),
      0.05,
    );
  });

  test('shape path excludes transparent bounding-box corners', () {
    final Path path = liquidGlassOutlinePath(
      const LiquidGlassShape.roundedRectangle(cornerRadius: 24),
      const Size(100, 60),
      const Offset(1, 1),
    );

    expect(path.contains(const Offset(50, 30)), isTrue);
    expect(path.contains(const Offset(0, 0)), isFalse);
  });
}
