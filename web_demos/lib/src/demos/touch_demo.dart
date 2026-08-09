import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Touch** — a card that answers your finger.
///
/// Press and it swells; drag and it elongates along the pull, pinches in the
/// cross axis, leans after your thumb, then springs back. The card never
/// *moves*: its footprint in layout is unchanged, so the rows inside it and
/// everything around it stay put.
///
/// ## Why a preset picker
///
/// `LiquidGlassFlex` ships four looks and the only honest way to choose one is
/// to feel them against each other. The chips swap the spec on the **same**
/// card, so the difference is the only variable — subtle barely moves,
/// pronounced is loose and rubbery, uniform ignores where you grabbed it.
///
/// ## Captured once
///
/// The backdrop is painted and static, so `realTimeCapture: false` snapshots
/// it once and the lens refracts that forever. The deformation is geometry —
/// it re-runs the shader every frame regardless — but nothing needs to
/// re-rasterize the page behind it.
class TouchDemo extends StatefulWidget {
  const TouchDemo({super.key});

  @override
  State<TouchDemo> createState() => _TouchDemoState();
}

enum _Preset {
  subtle('subtle', LiquidGlassFlex.subtle()),
  standard('default', LiquidGlassFlex()),
  pronounced('pronounced', LiquidGlassFlex.pronounced()),
  uniform('uniform', LiquidGlassFlex.uniform());

  const _Preset(this.label, this.flex);
  final String label;
  final LiquidGlassFlex flex;
}

class _TouchDemoState extends State<TouchDemo> {
  _Preset _preset = _Preset.standard;

  /// Set once a slider is touched: the card is no longer any named preset,
  /// so no chip should claim it.
  LiquidGlassFlex? _custom;

  LiquidGlassFlex get _flex => _custom ?? _preset.flex;

  void _pick(_Preset p) => setState(() {
        _preset = p;
        _custom = null;
      });

  void _tune(LiquidGlassFlex next) => setState(() => _custom = next);

  static const List<(IconData, String, String)> _rows = [
    (Icons.wb_sunny_rounded, 'Daylight', '6h 12m'),
    (Icons.water_drop_rounded, 'Humidity', '48%'),
    (Icons.air_rounded, 'Wind', '11 km/h'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = _flex;

    return LiquidGlassView(
      // Static backdrop: one snapshot is all the lens will ever need.
      realTimeCapture: false,
      backgroundWidget: const GlassBackdrop.ember(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;
          final double cardW = (w * 0.74).clamp(220.0, 320.0);

          return Stack(
            children: [
              Center(
                child: Padding(
                  // Leaves room for the controls pinned at the bottom.
                  padding: const EdgeInsets.only(bottom: 96),
                  child: SizedBox(
                    width: cardW,
                    height: 214,
                    child: LiquidGlassLens(
                      touch: LiquidGlassTouch(flex: s),
                      style: const LiquidGlassStyle(
                        shape: LiquidGlassShape.continuousRoundedRectangle(
                          cornerRadius: 30,
                          borderWidth: 1.2,
                          lightIntensity: 1.15,
                          lightDirection: 42,
                        ),
                        appearance: LiquidGlassAppearance(
                          color: Color(0x14FFFFFF),
                          blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
                        ),
                        refraction: LiquidGlassRefraction(
                          distortion: 0.07,
                          distortionWidth: 26,
                        ),
                      ),
                      child: const _CardBody(rows: _rows),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DemoHint('Press the card, or drag it and let go'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in _Preset.values)
                              DemoChip(
                                label: p.label,
                                selected: _custom == null && _preset == p,
                                onTap: () => _pick(p),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DemoPanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DemoSlider(
                                label: 'stretch',
                                value: s.stretch,
                                min: 0,
                                max: 60,
                                readout: s.stretch.toStringAsFixed(0),
                                onChanged: (v) =>
                                    _tune(s.copyWith(stretch: v)),
                              ),
                              DemoSlider(
                                label: 'grip',
                                value: s.grip,
                                min: 0,
                                max: 1,
                                readout: s.grip.toStringAsFixed(2),
                                onChanged: (v) => _tune(s.copyWith(grip: v)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The card's contents — ordinary widgets. They are the lens's child, so the
/// deformation carries them along instead of each one deforming on its own.
/// That is `childFollow`, and it is why the text never re-wraps mid-gesture.
class _CardBody extends StatelessWidget {
  final List<(IconData, String, String)> rows;
  const _CardBody({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '21°',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
          const Spacer(),
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(icon,
                      color: Colors.white.withValues(alpha: 0.85), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
