import 'package:flutter/material.dart';

import '../lab/overscroll_subpass/overscroll_page.dart';

// =============================================================
// Lab: the overscroll displacement.
//
//   cd example && flutter run -t overscroll_subpass_lab.dart
//
// Impeller only - the effect being chased is `StretchEffect`'s shader
// path, which Flutter takes only when ImageFilter.isShaderFilterSupported.
//
// Pull down past the top of the list and watch the glass against its own
// rim. The LiquidGlassLens card measures its geometry from the filtered
// subpass and should stay put; the switch and slider are still on the
// window-relative path and should still jump.
// =============================================================

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverscrollSubpassPage(),
    );
  }
}
