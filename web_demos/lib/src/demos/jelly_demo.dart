import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Jelly** — the soft-body spring the controls are built on, on its own.
///
/// [LiquidGlassJelly] takes a `value` from 0 to 1 and deforms its child from
/// how that value *moves*, not from what it is: push the slider fast and the
/// box elongates along the travel and pinches across it, then recoils past
/// rest and settles. Hold it still at any value and the box is exactly its
/// declared size again.
///
/// This is the same spring inside the slider's thumb and the nav bar's pill.
/// It deforms anything — a solid pill, an icon, a lens — so it is worth
/// knowing on its own before meeting it inside a component.
///
/// ## The two styles
///
/// `pinchExtrude` extrudes along the axis of travel and pinches the cross
/// axis; `squashStretch` is the classic uniform-volume squash. Everything
/// else is spring tuning: stiffness and damping decide how it settles,
/// `stretchWidth` and `squashHeight` how far it is allowed to go.
class JellyDemo extends StatefulWidget {
  const JellyDemo({super.key});

  @override
  State<JellyDemo> createState() => _JellyDemoState();
}

enum _Preset {
  standard('default', LiquidGlassJellyConfig()),
  loose('loose', LiquidGlassJellyConfig(
    stiffness: 180,
    damping: 14,
    stretchWidth: 26,
    squashHeight: 10,
  )),
  stiff('stiff', LiquidGlassJellyConfig(
    stiffness: 520,
    damping: 30,
    stretchWidth: 8,
    squashHeight: 3,
  )),
  squash('squashStretch', LiquidGlassJellyConfig(
    style: LiquidGlassJellyStyle.squashStretch,
  ));

  const _Preset(this.label, this.config);
  final String label;
  final LiquidGlassJellyConfig config;
}

class _JellyDemoState extends State<JellyDemo> {
  _Preset _preset = _Preset.standard;
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackdrop.dusk(),
        SafeArea(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  const SizedBox(height: 26),
                  Text(
                    'VALUE ${_value.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 42),
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          Align(
                            alignment: Alignment(-1 + 2 * _value, 0),
                            child: LiquidGlassJelly(
                              value: _value,
                              width: 84,
                              height: 84,
                              config: _preset.config,
                              child: _Box(value: _value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DemoHint(
                          'Throw the slider across and let go — the box '
                          'stretches into the travel and recoils on settle',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in _Preset.values)
                              DemoChip(
                                label: p.label,
                                selected: _preset == p,
                                onTap: () => setState(() => _preset = p),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DemoPanel(
                          child: DemoSlider(
                            label: 'value',
                            value: _value,
                            min: 0,
                            max: 1,
                            readout: _value.toStringAsFixed(2),
                            onChanged: (v) => setState(() => _value = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The thing being deformed. Deliberately solid and square-ish: an edge and a
/// corner make the squash legible in a way a blurred blob never does.
class _Box extends StatelessWidget {
  final double value;
  const _Box({required this.value});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF7C5CFF), const Color(0xFF2DD4BF),
                value)!,
            Color.lerp(const Color(0xFFFF5C8A), const Color(0xFF4FB3FF),
                value)!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.blur_on_rounded, color: Colors.white70, size: 26),
      ),
    );
  }
}
