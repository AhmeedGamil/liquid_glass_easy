import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Press Tuner — a live playground for LiquidGlassPress.
//
//   flutter run -t lib/press_tuner.dart   (standalone)
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
  runApp(const _PressTunerApp());
}

class _PressTunerApp extends StatelessWidget {
  const _PressTunerApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const PressTunerPage(),
    );
  }
}

/// Live tuner for [LiquidGlassPress] — the touch-driven soft-body
/// deformation on [LiquidGlassLens].
class PressTunerPage extends StatefulWidget {
  const PressTunerPage({super.key});

  @override
  State<PressTunerPage> createState() => _PressTunerPageState();
}

class _PressTunerPageState extends State<PressTunerPage> {
  LiquidGlassPress _press = const LiquidGlassPress();

  void _set(LiquidGlassPress next) => setState(() => _press = next);

  @override
  Widget build(BuildContext context) {
    return TunerGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Press Tuner'),
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
                _Stage(press: _press),
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
                  onReset: () => _set(const LiquidGlassPress()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presets() {
    Widget chip(String label, LiquidGlassPress value) {
      final bool active = _press == value;
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
        chip('subtle', const LiquidGlassPress.subtle()),
        chip('default', const LiquidGlassPress()),
        chip('uniform', const LiquidGlassPress.uniform()),
        chip('pronounced', const LiquidGlassPress.pronounced()),
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
            _press.stretch,
            0,
            40,
            _press.stretch.toStringAsFixed(0),
            (v) => _set(_press.copyWith(stretch: v)),
          ),
          TunerParamSlider(
            'squeeze',
            _press.squeeze,
            0,
            1,
            _press.squeeze.toStringAsFixed(2),
            (v) => _set(_press.copyWith(squeeze: v)),
          ),
          TunerParamSlider(
            'lean',
            _press.lean,
            0,
            1,
            _press.lean.toStringAsFixed(2),
            (v) => _set(_press.copyWith(lean: v)),
          ),
          TunerParamSlider(
            'grip',
            _press.grip,
            0,
            1,
            _press.grip.toStringAsFixed(2),
            (v) => _set(_press.copyWith(grip: v)),
          ),
          TunerParamSlider(
            'press',
            _press.press,
            0,
            10,
            _press.press.toStringAsFixed(1),
            (v) => _set(_press.copyWith(press: v)),
          ),
          TunerParamSlider(
            'maxPull',
            _press.maxPull,
            10,
            160,
            _press.maxPull.toStringAsFixed(0),
            (v) => _set(_press.copyWith(maxPull: v)),
          ),
        ],
      ),
    );
  }

  Widget _contentCard() {
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TunerPanelTitle('CONTENT & OPTICS'),
          const SizedBox(height: 8),
          TunerParamSlider(
            'childFollow',
            _press.childFollow,
            0,
            1,
            _press.childFollow.toStringAsFixed(2),
            (v) => _set(_press.copyWith(childFollow: v)),
          ),
          TunerParamSlider(
            'refraction',
            _press.refractionBoost,
            0,
            0.6,
            _press.refractionBoost.toStringAsFixed(2),
            (v) => _set(_press.copyWith(refractionBoost: v)),
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
            _press.stiffness,
            80,
            700,
            _press.stiffness.toStringAsFixed(0),
            (v) => _set(_press.copyWith(stiffness: v)),
          ),
          TunerParamSlider(
            'damping',
            _press.damping,
            6,
            50,
            _press.damping.toStringAsFixed(0),
            (v) => _set(_press.copyWith(damping: v)),
          ),
          TunerParamSlider(
            'release',
            _press.releaseDamping,
            4,
            50,
            _press.releaseDamping.toStringAsFixed(0),
            (v) => _set(_press.copyWith(releaseDamping: v)),
          ),
        ],
      ),
    );
  }

  String _snippet() {
    final p = _press;
    return 'LiquidGlassLens(\n'
        '  press: const LiquidGlassPress(\n'
        '    stretch: ${p.stretch.toStringAsFixed(0)},\n'
        '    squeeze: ${p.squeeze.toStringAsFixed(2)},\n'
        '    lean: ${p.lean.toStringAsFixed(2)},\n'
        '    grip: ${p.grip.toStringAsFixed(2)},\n'
        '    press: ${p.press.toStringAsFixed(1)},\n'
        '    maxPull: ${p.maxPull.toStringAsFixed(0)},\n'
        '    childFollow: ${p.childFollow.toStringAsFixed(2)},\n'
        '    refractionBoost: ${p.refractionBoost.toStringAsFixed(2)},\n'
        '    stiffness: ${p.stiffness.toStringAsFixed(0)},\n'
        '    damping: ${p.damping.toStringAsFixed(0)},\n'
        '    releaseDamping: ${p.releaseDamping.toStringAsFixed(0)},\n'
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
  final LiquidGlassPress press;
  const _Stage({required this.press});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: LiquidGlassLens(
            press: press,
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
                  press: press,
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
                press: press,
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
