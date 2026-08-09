import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Slider** — the control on its own, with the knobs that shape it.
///
/// [LiquidGlassSlider] is self-contained: it owns its background and refracts
/// its own track, so there is no [LiquidGlassView] on this page and no capture
/// anywhere. It works exactly like this on both engines.
///
/// ## What the presets change
///
/// Everything about the geometry lives in [LiquidGlassSliderLayout] — track
/// height, thumb size, and how far the thumb is allowed to stretch and squeeze
/// past that size while it moves. The chips swap the whole descriptor on the
/// same slider, so the feel is the only variable.
///
/// ## Live value vs committed value
///
/// `onChanged` fires on every pixel of the drag; `onChangeEnd` fires once, on
/// release. The readout shows both, because the difference is the whole reason
/// the second callback exists: commit expensive work — a network write, a
/// rebuild of something big — to the value you land on, not to the six hundred
/// you passed on the way.
class SliderDemo extends StatefulWidget {
  const SliderDemo({super.key});

  @override
  State<SliderDemo> createState() => _SliderDemoState();
}

enum _Size {
  compact('compact', LiquidGlassSliderLayout(
    width: 240,
    trackHeight: 6,
    thumbWidth: 26,
    thumbHeight: 18,
  )),
  standard('default', LiquidGlassSliderLayout(width: 280)),
  chunky('chunky', LiquidGlassSliderLayout(
    width: 300,
    trackHeight: 14,
    thumbWidth: 46,
    thumbHeight: 32,
    thumbExtraWidth: 18,
    thumbExtraHeight: 12,
  ));

  const _Size(this.label, this.layout);
  final String label;
  final LiquidGlassSliderLayout layout;
}

class _SliderDemoState extends State<SliderDemo> {
  _Size _size = _Size.standard;

  double _live = 0.62;
  double _committed = 0.62;

  double _warmth = 0.4;
  double _mix = 0.25;

  Color get _accent =>
      Color.lerp(const Color(0xFF4FB3FF), const Color(0xFFFFB020), _warmth)!;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackdrop.dusk(),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                'VALUE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${(_live * 100).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w300,
                      height: 1,
                    ),
                  ),
                  const Text('%',
                      style: TextStyle(color: Colors.white54, fontSize: 18)),
                  const Spacer(),
                  Text(
                    'committed ${(_committed * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Center(
                child: LiquidGlassSlider(
                  value: _live,
                  onChanged: (v) => setState(() => _live = v),
                  onChangeEnd: (v) => setState(() => _committed = v),
                  activeColor: Colors.white,
                  layout: _size.layout,
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in _Size.values)
                      DemoChip(
                        label: s.label,
                        selected: _size == s,
                        onTap: () => setState(() => _size = s),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 26),
              _Row(
                label: 'activeColor',
                readout: _warmth < 0.5 ? 'cool' : 'warm',
                child: LiquidGlassSlider(
                  value: _warmth,
                  onChanged: (v) => setState(() => _warmth = v),
                  activeColor: _accent,
                  layout: const LiquidGlassSliderLayout(width: 250),
                ),
              ),
              _Row(
                label: 'inactiveColor',
                readout: '${(_mix * 100).round()}%',
                child: LiquidGlassSlider(
                  value: _mix,
                  onChanged: (v) => setState(() => _mix = v),
                  activeColor: const Color(0xFF34D399),
                  inactiveColor: const Color(0x1FFFFFFF),
                  layout: const LiquidGlassSliderLayout(width: 250),
                ),
              ),

              const SizedBox(height: 16),
              const DemoHint(
                'Throw a thumb and let go — it stretches toward the travel, '
                'then recoils on the side it came from',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One labelled slider row. Plain chrome, so the glass is the only glass.
class _Row extends StatelessWidget {
  final String label;
  final String readout;
  final Widget child;

  const _Row({required this.label, required this.readout, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                readout,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(child: child),
        ],
      ),
    );
  }
}
