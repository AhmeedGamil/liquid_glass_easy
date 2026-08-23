import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Scroll-edge blur A/B — shader vs ladder, same backdrop, one frame.
//
// Split mode puts the progressive-blur SHADER on the left half and the
// feathered LADDER on the right, both reading the same scrolling
// content, so the two routes can be judged against each other instead
// of against a memory of the other one.
//
// What to look for as `blur` climbs:
//   - shader → grain. 20 taps spread over a 2.54·sigma disc; the noise
//     field is fixed in screen space while content scrolls through it.
//   - ladder → a ghost at the INNER boundary. Its finest rung is
//     0.34·blur, so at blur 20 a 6.8px blur cross-fades against a sharp
//     page and the crisp copy survives the mix.
//
//   flutter run -t lib/blur_compare.dart
// =============================================================

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const BlurComparePage(),
      );
}

/// Which route(s) the band under test uses.
enum _Mode { split, shader, ladder }

class BlurComparePage extends StatefulWidget {
  const BlurComparePage({super.key});

  @override
  State<BlurComparePage> createState() => _BlurComparePageState();
}

class _BlurComparePageState extends State<BlurComparePage> {
  _Mode _mode = _Mode.split;
  double _blur = 20;
  bool _dim = false;
  bool _top = false;

  /// Band depth. Deep enough that the falloff has room to be a falloff
  /// rather than a step.
  static const double _bandHeight = 240;

  Widget _band(bool shader) => LiquidGlassScrollEdge(
        edge: _top ? LiquidGlassEdge.top : LiquidGlassEdge.bottom,
        blur: _blur,
        useShaderBlur: shader,
        // Transparent by default so the BLUR is what gets judged, not
        // the dim sitting on top of it.
        color: _dim ? const Color(0x8A000000) : Colors.transparent,
      );

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    final Widget under = switch (_mode) {
      _Mode.shader => _band(true),
      _Mode.ladder => _band(false),
      _Mode.split => Row(
          children: <Widget>[
            Expanded(child: _band(true)),
            Expanded(child: _band(false)),
          ],
        ),
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          const _TestContent(),

          // The band under test.
          Positioned(
            left: 0,
            right: 0,
            top: _top ? 0 : null,
            bottom: _top ? null : 0,
            height: _bandHeight,
            child: under,
          ),

          // Which half is which — outside the band, never over it.
          if (_mode == _Mode.split)
            Positioned(
              left: 0,
              right: 0,
              top: _top ? _bandHeight + 4 : null,
              bottom: _top ? null : _bandHeight + 4,
              child: const Row(
                children: <Widget>[
                  Expanded(child: _Tag('SHADER', Alignment.center)),
                  Expanded(child: _Tag('LADDER', Alignment.center)),
                ],
              ),
            ),

          // The seam between the two halves, so the eye has a reference
          // line to compare across.
          if (_mode == _Mode.split)
            Positioned(
              top: _top ? 0 : null,
              bottom: _top ? null : 0,
              height: _bandHeight,
              left: MediaQuery.sizeOf(context).width / 2 - 0.5,
              width: 1,
              child: const ColoredBox(color: Color(0x33FF3B30)),
            ),

          Positioned(
            left: 0,
            right: 0,
            top: _top ? null : pad.top,
            bottom: _top ? pad.bottom : null,
            child: _controls(),
          ),
        ],
      ),
    );
  }

  Widget _controls() => Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        decoration: BoxDecoration(
          color: const Color(0xE6141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<_Mode>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const <ButtonSegment<_Mode>>[
                      ButtonSegment<_Mode>(value: _Mode.split, label: Text('Split')),
                      ButtonSegment<_Mode>(value: _Mode.shader, label: Text('Shader')),
                      ButtonSegment<_Mode>(value: _Mode.ladder, label: Text('Ladder')),
                    ],
                    selected: <_Mode>{_mode},
                    onSelectionChanged: (Set<_Mode> s) =>
                        setState(() => _mode = s.first),
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 74,
                  child: Text('blur ${_blur.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 12, fontFeatures: <ui.FontFeature>[
                        ui.FontFeature.tabularFigures()
                      ])),
                ),
                Expanded(
                  child: Slider(
                    value: _blur,
                    max: 40,
                    onChanged: (double v) => setState(() => _blur = v),
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                _Toggle(
                    label: 'dim',
                    value: _dim,
                    onChanged: (bool v) => setState(() => _dim = v)),
                const SizedBox(width: 12),
                _Toggle(
                    label: 'top edge',
                    value: _top,
                    onChanged: (bool v) => setState(() => _top = v)),
                const Spacer(),
                // If this is false the shader half silently renders the
                // ladder and the split looks identical on both sides.
                Text(
                  ui.ImageFilter.isShaderFilterSupported
                      ? 'shader filter: ON'
                      : 'shader filter: OFF (both = ladder)',
                  style: TextStyle(
                    fontSize: 11,
                    color: ui.ImageFilter.isShaderFilterSupported
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF453A),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Transform.scale(
            scale: 0.7,
            child: Switch(value: value, onChanged: onChanged),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final Alignment align;

  const _Tag(this.text, this.align);

  @override
  Widget build(BuildContext context) => Align(
        alignment: align,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xCCFF3B30),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ),
      );
}

/// Deliberately hostile backdrop: the three things that expose blur
/// quality are hard mono edges (ghosting), fine text (grain), and a
/// smooth colour field (banding).
class _TestContent extends StatelessWidget {
  const _TestContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 40,
      itemBuilder: (BuildContext context, int i) {
        return switch (i % 4) {
          0 => const _Bars(),
          1 => const _FineText(),
          2 => const _Gradient(),
          _ => const _Headline(),
        };
      },
    );
  }
}

/// Hard black/white bars — the worst case for the ladder's inner
/// cross-fade, where a crisp copy can survive inside the halo.
class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 90,
        child: Row(
          children: List<Widget>.generate(
            16,
            (int i) => Expanded(
              child: ColoredBox(
                color: i.isEven ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      );
}

/// Small high-contrast text — where 20-tap grain shows first.
class _FineText extends StatelessWidget {
  const _FineText();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: const Text(
          'The tap radius alone carries the falloff, riding the curve from '
          'full blur at the hugged edge down to zero at the inner boundary. '
          'At zero the pass samples each fragment own pixel, so it lands on '
          'the sharp page exactly and no alpha ramp is needed to hide a seam.',
          style: TextStyle(
              color: Colors.black, fontSize: 11, height: 1.3),
        ),
      );
}

/// A smooth field — nothing for either route to ghost, so any structure
/// visible here is the route's own artifact.
class _Gradient extends StatelessWidget {
  const _Gradient();

  @override
  Widget build(BuildContext context) => Container(
        height: 110,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFF0A84FF),
              Color(0xFFBF5AF2),
              Color(0xFFFF375F),
              Color(0xFFFF9F0A),
            ],
          ),
        ),
      );
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: const Text(
          'SHARP EDGES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      );
}
