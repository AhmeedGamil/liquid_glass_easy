import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Lens reveal — the switch's first-tap stall, bisected.
//
//   flutter run --profile --no-enable-impeller -t lib/lens_reveal_page.dart
//
// A page sitting idle with no glass on it, then glass arriving on a
// press. With every knob OFF this measured ~20 ms on the first reveal
// and nothing after — clean. The switch in the same conditions stalls
// ~120 ms. So the cost is NOT the reveal, the capture, the shader or the
// lens's first paint; it is something the switch does that this page
// did not.
//
// The knobs are that list. Turn ON exactly one, relaunch, reveal once,
// read row 1. The one that turns 20 ms into something like 120 ms is the
// answer.
//
//   shadow          the contact shadow the thumb wears — a
//                   MaskFilter.blur under BlendMode.multiply, sized to
//                   the lens, faded in with the morph. The page had none.
//   morph size      the lens box springs 37x24 -> 58x38.33 like the
//                   thumb, so every frame wants a differently sized
//                   offscreen for the blur, the clip and the opacity
//                   layer. The page's lens was one fixed size.
//   live background the captured background repaints every frame, the
//                   way the track does under the thumb. The page's
//                   background was static, so its captures re-rasterized
//                   an unchanged layer.
//   capture gated   ON mirrors the switch (pipeline stopped while there
//                   is no glass). OFF runs it from launch. Expected to
//                   change nothing — the view's capture target is one
//                   constant size, already allocated by the mount
//                   snapshot — which is why it is the control.
//
// Row 1 is a first-reveal reading ONLY on the first reveal after a full
// app launch. Relaunch between settings.
// =============================================================

void main() {
  runApp(const _LensRevealApp());
}

class _LensRevealApp extends StatelessWidget {
  const _LensRevealApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LensRevealPage(),
    );
  }
}

/// One reveal's cost, as the frame timings saw it.
class _Reveal {
  final int index;
  final Duration raster;
  final Duration build;

  const _Reveal({
    required this.index,
    required this.raster,
    required this.build,
  });
}

class LensRevealPage extends StatefulWidget {
  const LensRevealPage({super.key});

  @override
  State<LensRevealPage> createState() => _LensRevealPageState();
}

class _LensRevealPageState extends State<LensRevealPage>
    with SingleTickerProviderStateMixin {
  /// Whether the glass is on screen. False means the lens is not in the
  /// tree at all — a real hide, not an invisible one.
  bool _shown = false;

  // ── The knobs ────────────────────────────────────────────────
  bool _gateCapture = true;
  bool _shadow = false;
  bool _morphSize = false;
  bool _liveBackground = false;

  /// Top-left of the lens, in the view's coordinates.
  Offset _pos = const Offset(90, 300);

  final List<_Reveal> _log = <_Reveal>[];

  bool _armed = false;
  Duration _maxRaster = Duration.zero;
  Duration _maxBuild = Duration.zero;
  Timer? _closer;

  // ── Morph, on the switch's own springs ───────────────────────
  static const double _expandStiffness = 826, _expandDamping = 34.5;
  static const double _contractStiffness = 270, _contractDamping = 23;

  /// 0 = rest box, 1 = expanded box. Held at 1 when [_morphSize] is off,
  /// so the shadow (which rides it) is at full strength there.
  double _morph = 1;
  double _morphVel = 0;
  double _morphTarget = 1;
  Ticker? _ticker;
  Duration? _tickerLast;

  /// Advances while [_liveBackground] is on, to dirty the background
  /// boundary every frame the way the track does under the thumb.
  double _bgPhase = 0;

  /// The switch's thumb boxes, so the morph walks the same sizes.
  static const Size _restBox = Size(37, 24);
  static const Size _expandedBox = Size(58, 38.333);

  /// The fixed box used when [_morphSize] is off — the one that measured
  /// clean.
  static const Size _fixedBox = Size(210, 150);

  Size get _lensBox {
    if (!_morphSize) return _fixedBox;
    return Size(
      _restBox.width + (_expandedBox.width - _restBox.width) * _morph,
      _restBox.height + (_expandedBox.height - _restBox.height) * _morph,
    );
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker?.dispose();
    _closer?.cancel();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_armed) return;
    for (final FrameTiming t in timings) {
      if (t.rasterDuration > _maxRaster) _maxRaster = t.rasterDuration;
      if (t.buildDuration > _maxBuild) _maxBuild = t.buildDuration;
    }
  }

  void _onTick(Duration elapsed) {
    final Duration last = _tickerLast ?? elapsed;
    final double dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;
    if (dt <= 0) return;

    bool busy = false;

    if (_morphSize) {
      final bool expanding = _morphTarget > 0.5;
      final (double m, double v) = liquidGlassSpringStep(
        x: _morph,
        vel: _morphVel,
        target: _morphTarget,
        dt: dt,
        stiffness: expanding ? _expandStiffness : _contractStiffness,
        damping: expanding ? _expandDamping : _contractDamping,
      );
      _morph = m;
      _morphVel = v;
      if ((_morph - _morphTarget).abs() < 0.001 && _morphVel.abs() < 0.01) {
        _morph = _morphTarget;
        _morphVel = 0;
      } else {
        busy = true;
      }
    }

    // The background keeps moving for as long as the glass is up, which
    // is what forces a genuine re-rasterize on every capture.
    if (_liveBackground && _shown) {
      _bgPhase += dt;
      busy = true;
    }

    if (!busy) _ticker?.stop();
    if (mounted) setState(() {});
  }

  void _ensureTicking() {
    final Ticker? t = _ticker;
    if (t != null && !t.isActive) {
      _tickerLast = null;
      t.start();
    }
  }

  void _toggle() {
    final bool revealing = !_shown;
    setState(() {
      _shown = revealing;
      if (_morphSize) {
        _morphTarget = revealing ? 1 : 0;
        if (revealing) _morph = 0; // arrive from the rest box, like the thumb
      }
    });
    _ensureTicking();
    if (!revealing) return;
    _armed = true;
    _maxRaster = Duration.zero;
    _maxBuild = Duration.zero;
    _closer?.cancel();
    _closer = Timer(const Duration(milliseconds: 1200), _close);
  }

  void _close() {
    if (!_armed) return;
    _armed = false;
    final _Reveal r = _Reveal(
      index: _log.length + 1,
      raster: _maxRaster,
      build: _maxBuild,
    );
    setState(() => _log.add(r));
    debugPrint('[REVEAL] ${r.index}: raster ${_ms(r.raster)} ms, '
        'build ${_ms(r.build)} ms  |  ${_settings()}');
  }

  String _settings() => 'capture ${_gateCapture ? "gated" : "warm"}, '
      'shadow ${_shadow ? "on" : "off"}, '
      'morph ${_morphSize ? "on" : "off"}, '
      'liveBg ${_liveBackground ? "on" : "off"}';

  static String _ms(Duration d) =>
      (d.inMicroseconds / 1000).toStringAsFixed(1).padLeft(6);

  /// Changing a knob invalidates the log: the readings under it were
  /// taken in a different configuration, and the caches are already warm
  /// besides.
  void _setKnob(VoidCallback change) {
    setState(() {
      change();
      _log.clear();
    });
  }

  LiquidGlassStyle get _style {
    const LiquidGlassShape shape = LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 40,
      borderWidth: 1.5,
    );
    const LiquidGlassRefraction refraction = LiquidGlassRefraction(
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 24,
        depth: 0.7,
      ),
    );
    // The shadow rides the appearance, never a flat parameter — and it
    // fades in with the morph exactly as the thumb's does, so at rest it
    // is absent from the tree rather than merely transparent.
    final LiquidGlassShadow? shadow = (!_shadow || _morph <= 0.001)
        ? null
        : LiquidGlassShadow(inset: 3, opacity: 0.28 * _morph);
    return LiquidGlassStyle(
      shape: shape,
      appearance: LiquidGlassAppearance(
        color: const Color(0x14FFFFFF),
        saturation: 1.05,
        blur: const LiquidGlassBlur(sigmaX: 1, sigmaY: 1),
        shadow: shadow,
      ),
      refraction: refraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          LiquidGlassView(
            realTimeCapture: _gateCapture ? _shown : true,
            backgroundWidget: _Background(
              phase: _liveBackground ? _bgPhase : 0,
            ),
            child: _shown ? _lens() : const SizedBox.shrink(),
          ),
          // Controls and readout sit OUTSIDE the view, so nothing they
          // do lands in the capture or dirties the background boundary.
          Positioned(left: 0, right: 0, bottom: 0, child: _panel()),
        ],
      ),
    );
  }

  Widget _lens() {
    final Size box = _lensBox;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _pos.dx,
          top: _pos.dy,
          width: box.width,
          height: box.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (e) => setState(() => _pos += e.delta),
            child: LiquidGlassLens(
              style: _style,
              child: _morphSize
                  ? null
                  : const Center(
                      child: Text(
                        'drag me',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      decoration: const BoxDecoration(
        color: Color(0xE6101318),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _toggle,
              child: Text(_shown ? 'hide glass' : 'show glass'),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _knob('shadow', _shadow, (v) => _setKnob(() => _shadow = v)),
              _knob('morph size', _morphSize, (v) {
                _setKnob(() {
                  _morphSize = v;
                  _morph = v && !_shown ? 0 : 1;
                  _morphTarget = 1;
                });
              }),
              _knob('live bg', _liveBackground,
                  (v) => _setKnob(() => _liveBackground = v)),
              _knob('capture gated', _gateCapture,
                  (v) => _setKnob(() => _gateCapture = v)),
            ],
          ),
          const SizedBox(height: 12),
          if (_log.isEmpty)
            const Text(
              'peak raster / build per reveal — press show glass',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            for (final _Reveal r in _log) _revealRow(r),
          const SizedBox(height: 8),
          const Text(
            'Turn ON one knob, relaunch, reveal once, read row 1. '
            'Row 1 only counts on the first reveal since launch.',
            style: TextStyle(color: Color(0xFFF0B849), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _knob(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF2E6BE6) : const Color(0xFF1C212B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _revealRow(_Reveal r) {
    final bool first = r.index == 1;
    final TextStyle style = TextStyle(
      color: first ? const Color(0xFFF0B849) : Colors.white70,
      fontSize: 13,
      fontFamily: 'monospace',
      fontWeight: first ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${r.index}', style: style)),
          SizedBox(width: 78, child: Text('${_ms(r.raster)} ms', style: style)),
          Text('${_ms(r.build)} ms', style: style),
        ],
      ),
    );
  }
}

/// Busy, cheap, and entirely local — no image decode to muddy a jank
/// reading. [phase] shifts the grid so the boundary is genuinely dirty
/// every frame when `live bg` is on.
class _Background extends StatelessWidget {
  final double phase;
  const _Background({required this.phase});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
        ),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(phase: phase),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double phase;
  const _GridPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final double shift = (phase * 30) % 34;
    final Paint line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double x = shift - 34; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = shift - 34; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final Paint dot = Paint()..color = const Color(0x55000000);
    for (int i = 0; i < 26; i++) {
      final double a = i * 2.4 + phase * 0.6;
      canvas.drawCircle(
        Offset(
          size.width * (0.5 + 0.42 * math.cos(a)),
          size.height * (0.5 + 0.42 * math.sin(a * 1.3)),
        ),
        10 + (i % 5) * 6,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.phase != phase;
}
