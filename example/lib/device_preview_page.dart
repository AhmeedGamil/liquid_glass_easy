import 'dart:ui' show FlutterView;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';
import 'lens_page.dart';
import 'tab_bar_page.dart';

// =============================================================
// Device preview — the whole app scaled down to sit inside a phone frame.
//
//   flutter run -t lib/device_preview_page.dart
//
// A reproduction page. `device_preview` simulates another device by
// overriding MediaQuery (size, pixel ratio, insets) and then shrinking the
// app with a FittedBox so the simulated screen fits inside the real one.
// The glass reads its screen size and pixel ratio from that simulated
// MediaQuery, while the shader's fragment coordinates are the real
// physical pixels — so the two no longer agree.
//
// What to look for, on the lens on this page and on the nav pill of the
// "Nav pill" page: the glass sitting off its own outline (wrong place),
// drawn at the wrong size, and a blurred second copy of the backdrop —
// a "ghost" — hanging behind it. Open the tool panel (the bottom-left
// button of the preview) and switch devices, rotate, or hide the frame to
// change the scale; disable the preview there to see the correct glass
// again at 1:1.
// =============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassShaders.ensureLoaded();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DevicePreviewPage(),
    ),
  );
}

/// The demo, wrapped in a real `DevicePreview` exactly as an app would be.
class DevicePreviewPage extends StatelessWidget {
  const DevicePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DevicePreview(
      enabled: true,
      // In-memory only: nothing written to shared preferences, and the
      // preview starts on the same device every time the page opens.
      storage: DevicePreviewStorage.none(),
      defaultDevice: Devices.ios.iPhone13,
      builder: (BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        // device_preview asserts on this flag; Flutter ignores it since 3.7.
        // ignore: deprecated_member_use
        useInheritedMediaQuery: true,
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.transparent,
        ),
        home: const _PreviewedHome(),
      ),
    );
  }
}

/// The app that lives inside the frame: one draggable lens over a photo,
/// and two doors to the demos whose glass the report was about.
class _PreviewedHome extends StatelessWidget {
  const _PreviewedHome();

  /// Neon signage: dense straight edges and bright colour, so a shifted or
  /// resized refraction — and a ghost copy of the backdrop — is unmissable.
  static const String _backdrop =
      'https://images.unsplash.com/photo-1485001564903-56e6a54d46ef'
      '?auto=format&fit=crop&w=1100&q=72';

  static const Size _lensSize = Size(240, 150);

  static const LiquidGlassStyle _style = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 40,
      borderWidth: 1.5,
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x14FFFFFF),
      blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.11,
      distortionWidth: 40,
    ),
  );

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _WithBack(child: page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: const DemoPhoto(_backdrop, seed: 0, scrim: 0.06),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Offset pos = Offset(
              (c.maxWidth - _lensSize.width) / 2,
              (c.maxHeight - _lensSize.height) * 0.36,
            );
            return Stack(
              children: <Widget>[
                Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  width: _lensSize.width,
                  height: _lensSize.height,
                  child: LiquidGlassDraggable(
                    child: LiquidGlassLens(
                      style: _style,
                      child: const Center(
                        child: Text(
                          'LiquidGlassLens',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: mq.padding.top + 12,
                  child: _Readout(mq: mq),
                ),
                DemoPanel(
                  title: 'Inside the preview',
                  children: <Widget>[
                    _Door(
                      label: 'Nav pill',
                      hint: 'LiquidGlassScaffold + LiquidGlassTabBar',
                      onTap: () => _push(context, const TabBarPage()),
                    ),
                    const SizedBox(height: 8),
                    _Door(
                      label: 'Lens',
                      hint: 'The lens page with its style panel',
                      onTap: () => _push(
                        context,
                        const LensPage(showControls: false),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The simulated numbers the glass is reading, next to the real ones the
/// shader is drawing into — the gap between them is the bug.
class _Readout extends StatelessWidget {
  final MediaQueryData mq;
  const _Readout({required this.mq});

  @override
  Widget build(BuildContext context) {
    final FlutterView view = View.of(context);
    final Size real = view.physicalSize / view.devicePixelRatio;
    String size(Size s) => '${s.width.round()}×${s.height.round()}';
    final TextStyle style = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: 12,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'MediaQuery (simulated): ${size(mq.size)} '
              '@ ${mq.devicePixelRatio.toStringAsFixed(2)}x',
              style: style,
            ),
            Text(
              'View (real): ${size(real)} '
              '@ ${view.devicePixelRatio.toStringAsFixed(2)}x',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onTap;
  const _Door({required this.label, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hint,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A demo page with a small back button, since the pages have none of
/// their own and the system back gesture reaches the outer app first.
class _WithBack extends StatelessWidget {
  final Widget child;
  const _WithBack({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          left: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: 'Back',
            ),
          ),
        ),
      ],
    );
  }
}
