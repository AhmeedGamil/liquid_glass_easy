import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens_scope.dart';

// LiquidGlassAdaptiveClient.adaptiveRegions: the sampler's multi-rect
// contract — single-rect clients bridge through adaptiveRegion, a null
// region becomes an empty list (sample skipped).

class _SingleRectClient extends LiquidGlassAdaptiveClient {
  Rect? region;

  @override
  Rect? adaptiveRegion(RenderBox backgroundBox) => region;

  @override
  void onAdaptiveLuminance(double luminance, double lightFraction) {}
}

void main() {
  final RenderBox box = RenderConstrainedBox(
      additionalConstraints: const BoxConstraints.tightFor(width: 1));

  test('adaptiveRegions defaults to the single adaptiveRegion', () {
    final client = _SingleRectClient()
      ..region = const Rect.fromLTWH(1, 2, 3, 4);
    expect(client.adaptiveRegions(box), [const Rect.fromLTWH(1, 2, 3, 4)]);
  });

  test('a null adaptiveRegion yields no rects (sample skipped)', () {
    final client = _SingleRectClient()..region = null;
    expect(client.adaptiveRegions(box), isEmpty);
  });
}
