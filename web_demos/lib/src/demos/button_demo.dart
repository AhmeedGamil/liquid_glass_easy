import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Button** — a lens shaped like a button, with a press that answers.
///
/// [LiquidGlassButton] is a single lens around an icon-and-label row, so it
/// refracts whatever is behind it. That is also its one requirement: on Skia
/// and the web it needs an ancestor [LiquidGlassView] to have something to
/// refract, which is why this page is wrapped in one. On Impeller it works
/// anywhere with no setup at all.
///
/// ## Press
///
/// Pass a `touch:` and the button becomes a soft body — it swells under the
/// finger and springs back on release, without its footprint in layout
/// changing, so nothing around it shifts. The bottom row leaves `touch` off
/// for the comparison.
///
/// ## Captured once
///
/// The backdrop is painted and static, so the view snapshots it a single time.
/// Buttons that only ever move by a few pixels of deformation do not need a
/// per-frame capture underneath them.
class ButtonDemo extends StatefulWidget {
  const ButtonDemo({super.key});

  @override
  State<ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<ButtonDemo> {
  int _taps = 0;
  String _last = 'nothing yet';

  void _tap(String what) => setState(() {
        _taps += 1;
        _last = what;
      });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassView(
      // Static backdrop: one snapshot is all these buttons will ever need.
      realTimeCapture: false,
      backgroundWidget: const GlassBackdrop.dusk(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            _Label('LABEL + ICON'),
            LiquidGlassButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              width: 220,
              touch: const LiquidGlassTouch(flex: LiquidGlassFlex.subtle()),
              onPressed: () => _tap('Continue'),
            ),
            const SizedBox(height: 10),
            LiquidGlassButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              width: 220,
              touch: const LiquidGlassTouch(flex: LiquidGlassFlex.subtle()),
              onPressed: () => _tap('Share'),
            ),

            const SizedBox(height: 26),
            _Label('CUSTOM CHILD'),
            LiquidGlassButton.custom(
              width: 260,
              height: 62,
              touch: const LiquidGlassTouch(flex: LiquidGlassFlex()),
              onPressed: () => _tap('Account'),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C5CFF), Color(0xFFFF5C8A)],
                      ),
                    ),
                    child: const Center(
                      child: Text('A',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ana Reyes',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                      Text('Switch account',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),
            _Label('SHAPE, AND NO TOUCH'),
            LiquidGlassButton(
              label: 'Rounded rectangle',
              width: 260,
              height: 52,
              style: const LiquidGlassStyle(
                shape: LiquidGlassShape.continuousRoundedRectangle(
                  cornerRadius: 16,
                  borderWidth: 1.2,
                ),
              ),
              onPressed: () => _tap('Rounded rectangle'),
            ),
            const SizedBox(height: 10),
            const LiquidGlassButton(
              label: 'Disabled',
              width: 200,
              // No onPressed: the button dims and stops taking a press.
              onPressed: null,
            ),

            const SizedBox(height: 24),
            DemoPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'last: $_last',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text(
                    '$_taps taps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const DemoHint('Press and hold one — the glass gives, then springs'),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
