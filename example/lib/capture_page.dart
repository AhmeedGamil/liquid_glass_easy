import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Capture — what the Skia path does that Impeller does not.
//
//   flutter run -t lib/capture_page.dart
//
// Impeller reads the live backdrop per lens. Skia and the web cannot, so
// LiquidGlassView snapshots what is behind the glass and the lenses refract
// that snapshot. Everything on this page is a knob on that snapshot.
//
// The background never stops sliding, which is the point: freeze the capture
// and the glass keeps refracting bands that have already moved on, while the
// ones around it carry on. The offset between them IS the staleness.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _CaptureApp());
}

class _CaptureApp extends StatelessWidget {
  const _CaptureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const CapturePage(),
    );
  }
}

/// Which backend the page asks for. Skia captures; Impeller reads live.
enum _Engine { skia, impeller }

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage>
    with SingleTickerProviderStateMixin {
  final LiquidGlassViewController _controller = LiquidGlassViewController();

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  _Engine _engine = _Engine.skia;
  bool _realTime = true;
  bool _useSync = true;
  double _pixelRatio = 1.0;
  LiquidGlassRefreshRate _rate = LiquidGlassRefreshRate.deviceRefreshRate;

  /// Impeller exists on the device backends only. Asking for it on the web
  /// is not an error to hide — it is the thing this page is teaching — so
  /// the chip stays pickable and says why nothing changed.
  bool get _impellerUnavailable => _engine == _Engine.impeller && kIsWeb;

  /// What the view is actually told, as opposed to what is selected.
  bool get _useImpeller => _engine == _Engine.impeller && !kIsWeb;

  static const Map<LiquidGlassRefreshRate, String> _rateNames =
      <LiquidGlassRefreshRate, String>{
    LiquidGlassRefreshRate.deviceRefreshRate: 'every frame',
    LiquidGlassRefreshRate.high: '60',
    LiquidGlassRefreshRate.medium: '24',
    LiquidGlassRefreshRate.low: '10',
  };

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capture knobs are inert on Impeller — it never takes one — so the
    // panel greys them out rather than pretending they do something.
    final bool capturing = !_useImpeller;

    return Scaffold(
      body: LiquidGlassView(
        controller: _controller,
        backgroundWidget: _TickingBackdrop(clock: _clock),
        pixelRatio: _pixelRatio,
        realTimeCapture: _realTime,
        useSync: _useSync,
        refreshRate: _rate,
        useImpellerBackdrop: _useImpeller ? true : null,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            return Stack(
              children: <Widget>[
                Positioned(
                  left: (c.maxWidth - 260) / 2,
                  top: (c.maxHeight - 150) * 0.28,
                  width: 260,
                  height: 150,
                  child: const LiquidGlassLens(
                    style: LiquidGlassStyle(
                      shape: LiquidGlassShape.continuousRoundedRectangle(
                        cornerRadius: 38,
                        borderWidth: 1.4,
                      ),
                      refraction: LiquidGlassRefraction(
                        distortion: 0.13,
                        distortionWidth: 34,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'the snapshot,\nrefracted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                DemoPanel(
                  title: 'LiquidGlassView',
                  children: <Widget>[
                    DemoChips<_Engine>(
                      values: _Engine.values,
                      selected: _engine,
                      label: (_Engine e) =>
                          e == _Engine.skia ? 'Skia capture' : 'Impeller live',
                      onChanged: (_Engine e) => setState(() => _engine = e),
                    ),
                    if (_impellerUnavailable) const _Notice(),
                    const SizedBox(height: 8),
                    _Row(
                      enabled: capturing,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: DemoChips<bool>(
                              values: const <bool>[true, false],
                              selected: _realTime,
                              label: (bool v) => v ? 'live' : 'frozen',
                              onChanged: (bool v) =>
                                  setState(() => _realTime = v),
                            ),
                          ),
                          _CaptureOnceButton(
                            enabled: capturing && !_realTime,
                            onPressed: _controller.captureOnce,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Row(
                      enabled: capturing,
                      child: DemoChips<LiquidGlassRefreshRate>(
                        values: _rateNames.keys.toList(),
                        selected: _rate,
                        label: (LiquidGlassRefreshRate r) => _rateNames[r]!,
                        onChanged: (LiquidGlassRefreshRate r) =>
                            setState(() => _rate = r),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Row(
                      enabled: capturing,
                      child: DemoChips<bool>(
                        values: const <bool>[true, false],
                        selected: _useSync,
                        label: (bool v) => v ? 'useSync' : 'async',
                        onChanged: (bool v) => setState(() => _useSync = v),
                      ),
                    ),
                    _Row(
                      enabled: capturing,
                      child: DemoSlider(
                        label: 'pixel ratio',
                        value: _pixelRatio,
                        min: 0.3,
                        max: 1.0,
                        decimals: 2,
                        onChanged: (double v) =>
                            setState(() => _pixelRatio = v),
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

/// Dims a control the current backend does not use.
class _Row extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _Row({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(opacity: enabled ? 1 : 0.35, child: child),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded,
              size: 15, color: Color(0xFFFFB86B)),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Impeller is not available on the web. This page keeps '
              'running the Skia capture path.',
              style: TextStyle(
                color: Color(0xFFFFB86B),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureOnceButton extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onPressed;

  const _CaptureOnceButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: const Text(
            'capture once',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A background that never stops moving.
///
/// Freeze the capture and the bands inside the glass stand still while the
/// ones around it keep sliding: how far the two have drifted apart is how old
/// the snapshot the lens is refracting has become.
class _TickingBackdrop extends StatelessWidget {
  final Animation<double> clock;

  const _TickingBackdrop({required this.clock});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (BuildContext context, _) => CustomPaint(
        painter: _TickingPainter(clock.value),
        size: Size.infinite,
      ),
    );
  }
}

class _TickingPainter extends CustomPainter {
  /// 0 → 1, looping.
  final double t;

  const _TickingPainter(this.t);

  static const List<Color> _bands = <Color>[
    Color(0xFF6C3BFF),
    Color(0xFF1FB6FF),
    Color(0xFFFF4D8D),
    Color(0xFF2BD9A6),
    Color(0xFFFFB020),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0A12));

    // Diagonal bands sliding one full period across the box, so the pattern
    // under the lens is never the same twice in a row — and a frozen capture
    // is visibly out of step with the live background around it.
    final double span = size.width + size.height;
    final double bandWidth = span / 9;
    final double shift = t * bandWidth * _bands.length;
    for (int i = -_bands.length; i < 14; i++) {
      final double x = i * bandWidth + shift;
      final Path p = Path()
        ..moveTo(x, 0)
        ..lineTo(x + bandWidth * 0.62, 0)
        ..lineTo(x + bandWidth * 0.62 - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(
        p,
        Paint()..color = _bands[(i % _bands.length + _bands.length) %
                _bands.length]
            .withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_TickingPainter old) => old.t != t;
}
