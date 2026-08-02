import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Flex Tuner — a live playground for LiquidGlassFlex.
//
//   flutter run -t lib/flex_tuner.dart   (standalone)
//   …or open it from the home menu.
//
// Press and drag any of the three lenses below. None of them move: the
// glass deforms in place, its four edges sprung independently and
// anchored wherever your finger landed, and the content stretches with
// it as pixels instead of re-flowing.
//
// Grab a corner and pull to see what a plain scale transform can't do —
// the near edge travels much further than the far one.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _FlexTunerApp());
}

class _FlexTunerApp extends StatelessWidget {
  const _FlexTunerApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const FlexTunerPage(),
    );
  }
}

/// Live tuner for [LiquidGlassFlex] — the touch-driven soft-body
/// deformation on [LiquidGlassLens].
class FlexTunerPage extends StatefulWidget {
  const FlexTunerPage({super.key});

  @override
  State<FlexTunerPage> createState() => _FlexTunerPageState();
}

class _FlexTunerPageState extends State<FlexTunerPage> {
  LiquidGlassFlex _flex = const LiquidGlassFlex();

  void _set(LiquidGlassFlex next) => setState(() => _flex = next);

  @override
  Widget build(BuildContext context) {
    return TunerGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Flex Tuner'),
        ),
        body: SafeArea(
          top: false,
          // Android's stretch overscroll lifts the scrollable's content into
          // its own compositing layer while it plays, and a BackdropFilter
          // lens inside that layer can no longer see the real backdrop — the
          // glass turns black at both scroll edges. The lenses below live in
          // this list, so the indicator has to go.
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              overscroll: false,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const _Hint(),
                const SizedBox(height: 20),
                _Stage(flex: _flex),
                const SizedBox(height: 24),
                _presets(),
                const SizedBox(height: 16),
                _shapeCard(),
                const SizedBox(height: 12),
                _contentCard(),
                const SizedBox(height: 12),
                _physicsCard(),
                const SizedBox(height: 16),
                TunerCodeCard(
                  snippet: _snippet(),
                  onReset: () => _set(const LiquidGlassFlex()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presets() {
    Widget chip(String label, LiquidGlassFlex value) {
      final bool active = _flex == value;
      return OutlinedButton(
        onPressed: () => _set(value),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: active ? Colors.white : Colors.white70,
          backgroundColor: active ? Colors.white.withValues(alpha: 0.16) : null,
          side: BorderSide(
            color: Colors.white.withValues(alpha: active ? 0.7 : 0.25),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('subtle', const LiquidGlassFlex.subtle()),
        chip('default', const LiquidGlassFlex()),
        chip('uniform', const LiquidGlassFlex.uniform()),
        chip('pronounced', const LiquidGlassFlex.pronounced()),
      ],
    );
  }

  Widget _shapeCard() {
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TunerPanelTitle('SHAPE'),
          const SizedBox(height: 8),
          TunerParamSlider(
            'stretch',
            _flex.stretch,
            0,
            80,
            _flex.stretch.toStringAsFixed(0),
            (v) => _set(_flex.copyWith(stretch: v)),
          ),
          TunerParamSlider(
            'squeeze',
            _flex.squeeze,
            0,
            1,
            _flex.squeeze.toStringAsFixed(2),
            (v) => _set(_flex.copyWith(squeeze: v)),
          ),
          TunerParamSlider(
            'lean',
            _flex.lean,
            0,
            1,
            _flex.lean.toStringAsFixed(2),
            (v) => _set(_flex.copyWith(lean: v)),
          ),
          TunerParamSlider(
            'grip',
            _flex.grip,
            0,
            1,
            _flex.grip.toStringAsFixed(2),
            (v) => _set(_flex.copyWith(grip: v)),
          ),
          // Both signed: right of zero the glass swells on touch, left of
          // zero it yields inward. Fractions, so they read the same on the
          // tiny square as on the wide card.
          //
          // holdScale lasts as long as the finger is down; tapScale is the
          // one-shot pop on a completed tap. Tap the lens to feel the
          // second one on its own.
          TunerParamSlider(
            'holdScale',
            _flex.holdScale,
            -0.4,
            0.4,
            _flex.holdScale.toStringAsFixed(3),
            (v) => _set(_flex.copyWith(holdScale: v)),
          ),
          TunerParamSlider(
            'tapScale',
            _flex.tapScale,
            -0.4,
            0.4,
            _flex.tapScale.toStringAsFixed(3),
            (v) => _set(_flex.copyWith(tapScale: v)),
          ),
          TunerParamSlider(
            'maxPull',
            _flex.maxPull,
            10,
            300,
            _flex.maxPull.toStringAsFixed(0),
            (v) => _set(_flex.copyWith(maxPull: v)),
          ),
          const SizedBox(height: 6),
          // Pull an edge away from the middle and the body stretches either
          // way. The switch is about the OTHER direction: driving that edge
          // inward. On, the far side lags and the body squashes (and squeeze
          // bulges the cross axis); off is the original response, where the
          // pull's magnitude alone drove it and the shape grew whichever way
          // it was pushed.
          SwitchListTile.adaptive(
            value: _flex.compressInward,
            onChanged: (v) => _set(_flex.copyWith(compressInward: v)),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('compressInward',
                style: TextStyle(fontSize: 13)),
            subtitle: Text(
              _flex.compressInward
                  ? 'pushing an edge inward squashes the body'
                  : 'magnitude only — it grows whichever way you push',
              style: const TextStyle(fontSize: 10.5, color: Colors.white38),
            ),
          ),
          // A/B for the stretched outline. The rim is one logical pixel, so
          // the only way to judge it is to flip this WHILE dragging.
          //
          //   legacy  fixed pixel radius on the deformed box -- a stretched
          //           circle grows flat runs and reads as a stadium.
          //   shader  the shader stretches the outline but the clips stay
          //           circular, so they cross it and shave the rim off at a
          //           cap apex. The broken middle state.
          //   full    both stretch. Shipped.
          Row(
            children: [
              const SizedBox(
                width: 92,
                child: Text('outline',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ),
              Expanded(
                child: SegmentedButton<LiquidGlassFlexOutline>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                  ),
                  segments: const [
                    ButtonSegment(
                        value: LiquidGlassFlexOutline.legacy,
                        label: Text('legacy')),
                    ButtonSegment(
                        value: LiquidGlassFlexOutline.shaderOnly,
                        label: Text('shader')),
                    ButtonSegment(
                        value: LiquidGlassFlexOutline.full,
                        label: Text('full')),
                  ],
                  selected: {debugLiquidGlassFlexOutline},
                  onSelectionChanged: (v) => setState(
                      () => debugLiquidGlassFlexOutline = v.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Not a slider: the lock is a choice of three, and `copyWith`
          // cannot put a null back, so each option rebuilds the spec.
          Row(
            children: [
              const SizedBox(
                width: 92,
                child: Text('lockAxis',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ),
              Expanded(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                  ),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('free')),
                    ButtonSegment(value: 1, label: Text('horiz')),
                    ButtonSegment(value: 2, label: Text('vert')),
                  ],
                  selected: {
                    switch (_flex.lockAxis) {
                      null => 0,
                      Axis.horizontal => 1,
                      Axis.vertical => 2,
                    }
                  },
                  onSelectionChanged: (s) => _set(_withLock(switch (s.first) {
                    1 => Axis.horizontal,
                    2 => Axis.vertical,
                    _ => null,
                  })),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rebuilds the spec with an explicit [axis], which `copyWith` cannot do
  /// for the `null` ("free") case — a null argument there means "keep".
  LiquidGlassFlex _withLock(Axis? axis) => LiquidGlassFlex(
        stretch: _flex.stretch,
        squeeze: _flex.squeeze,
        lean: _flex.lean,
        grip: _flex.grip,
        holdScale: _flex.holdScale,
        tapScale: _flex.tapScale,
        maxPull: _flex.maxPull,
        lockAxis: axis,
        tuning: _flex.tuning,
      );

  Widget _contentCard() {
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TunerPanelTitle('CONTENT & OPTICS'),
          const SizedBox(height: 8),
          TunerParamSlider(
            'childFollow',
            _flex.childFollow,
            0,
            1,
            _flex.childFollow.toStringAsFixed(2),
            (v) => _set(_tune(childFollow: v)),
          ),
          TunerParamSlider(
            'refraction',
            _flex.refractionBoost,
            0,
            0.6,
            _flex.refractionBoost.toStringAsFixed(2),
            (v) => _set(_tune(refractionBoost: v)),
          ),
          // Off at 0. Watch the BACKDROP, not the outline — this zooms what
          // is behind the glass rather than bending it.
          TunerParamSlider(
            'magnification',
            _flex.magnificationBoost,
            0,
            0.6,
            _flex.magnificationBoost.toStringAsFixed(2),
            (v) => _set(_tune(magnificationBoost: v)),
          ),
        ],
      ),
    );
  }

  Widget _physicsCard() {
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TunerPanelTitle('SPRINGS'),
          const SizedBox(height: 8),
          TunerParamSlider(
            'stiffness',
            _flex.stiffness,
            80,
            700,
            _flex.stiffness.toStringAsFixed(0),
            (v) => _set(_tune(stiffness: v)),
          ),
          TunerParamSlider(
            'damping',
            _flex.damping,
            6,
            50,
            _flex.damping.toStringAsFixed(0),
            (v) => _set(_tune(damping: v)),
          ),
          TunerParamSlider(
            'release',
            _flex.releaseDamping,
            4,
            50,
            _flex.releaseDamping.toStringAsFixed(0),
            (v) => _set(_tune(releaseDamping: v)),
          ),
        ],
      ),
    );
  }

  /// The set-once knobs live in a group, so tweaking one goes through the
  /// group's own copyWith rather than the spec's.
  LiquidGlassFlex _tune({
    double? childFollow,
    double? refractionBoost,
    double? magnificationBoost,
    double? stiffness,
    double? damping,
    double? releaseDamping,
  }) {
    return _flex.copyWith(
      tuning: _flex.tuning.copyWith(
        childFollow: childFollow,
        refractionBoost: refractionBoost,
        magnificationBoost: magnificationBoost,
        stiffness: stiffness,
        damping: damping,
        releaseDamping: releaseDamping,
      ),
    );
  }

  String _snippet() {
    final p = _flex;
    return 'LiquidGlassLens(\n'
        '  touch: const LiquidGlassTouch.flexing(\n'
        '    LiquidGlassFlex(\n'
        '      stretch: ${p.stretch.toStringAsFixed(0)},\n'
        '      squeeze: ${p.squeeze.toStringAsFixed(2)},\n'
        '      lean: ${p.lean.toStringAsFixed(2)},\n'
        '      grip: ${p.grip.toStringAsFixed(2)},\n'
        '      holdScale: ${p.holdScale.toStringAsFixed(3)},\n'
        '      tapScale: ${p.tapScale.toStringAsFixed(3)},\n'
        '      maxPull: ${p.maxPull.toStringAsFixed(0)},\n'
        '${p.lockAxis == null ? '' : '      lockAxis: ${p.lockAxis},\n'}'
        '      tuning: LiquidGlassFlexTuning(\n'
        '        childFollow: ${p.childFollow.toStringAsFixed(2)},\n'
        '        refractionBoost: ${p.refractionBoost.toStringAsFixed(2)},\n'
        '${p.magnificationBoost == 0 ? '' : '        magnificationBoost: ${p.magnificationBoost.toStringAsFixed(2)},\n'}'
        '        stiffness: ${p.stiffness.toStringAsFixed(0)},\n'
        '        damping: ${p.damping.toStringAsFixed(0)},\n'
        '        releaseDamping: ${p.releaseDamping.toStringAsFixed(0)},\n'
        '      ),\n'
        '    ),\n'
        '  ),\n'
        '  child: ...,\n'
        ')';
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Press and drag the glass — it deforms in place. Grab an edge and '
      'pull: the near edge travels further than the far one. That is what '
      '"grip" controls.',
      style: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: Colors.white.withValues(alpha: 0.72),
      ),
    );
  }
}

/// The three test subjects: a wide card (watch the volume pinch), a
/// capsule (watch the radius stay valid) and a small square (watch the
/// grab-point asymmetry).
class _Stage extends StatelessWidget {
  final LiquidGlassFlex flex;
  const _Stage({required this.flex});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: LiquidGlassLens(
            touch: LiquidGlassTouch.flexing(flex),
            style: const LiquidGlassStyle(
              shape: LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: 34,
                borderWidth: 1.2,
              ),
              appearance: LiquidGlassAppearance(
                color: Color(0x1FFFFFFF),
                blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 34, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'drag me',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 62,
                child: LiquidGlassLens(
                  touch: LiquidGlassTouch.flexing(flex),
                  style: const LiquidGlassStyle(
                    // Radius > half-height on purpose: the press path caps
                    // it against the deformed size, so a squeezed capsule
                    // stays a capsule instead of self-intersecting.
                    shape: LiquidGlassShape.roundedRectangle(
                      cornerRadius: 999,
                      borderWidth: 1,
                    ),
                    appearance: LiquidGlassAppearance(
                      color: Color(0x1AFFFFFF),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'capsule',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 82,
              height: 82,
              child: LiquidGlassLens(
                touch: LiquidGlassTouch.flexing(flex),
                style: const LiquidGlassStyle(
                  shape: LiquidGlassShape.continuousRoundedRectangle(
                    cornerRadius: 24,
                    borderWidth: 1,
                  ),
                  appearance: LiquidGlassAppearance(
                    color: Color(0x1AFFFFFF),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.favorite_rounded,
                      size: 30, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
