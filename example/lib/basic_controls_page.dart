import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// The slider's own default active colour, restated so the readout
/// percentage can be tinted to match the fill.
const Color _kSliderBlue = Color(0xFF0A84FF);

/// The resting tone both controls share: the switch's off track and the
/// slider's unfilled stretch.
///
/// Between white and the iOS off-gray rather than at either end — the
/// shipped defaults (`0x4C787880` and `0x14000000`) land near `#CFCFD3`
/// and `#E1E1E2` once composited on this page's card, so the two did not
/// match and the switch read as a solid grey. Opaque, so both sit at the
/// same tone instead of each picking up whatever is behind it.
const Color _kRestTrackColor = Color(0xFFDEDEE3);

// -------------------------------------------------------------
// The size of each control. Both take `width` and `height` directly, so
// this page never opens a layout descriptor — change these four numbers
// and nothing else has to move.
// -------------------------------------------------------------

/// The slider, end to end. Capped by the available width at build time,
/// so a narrow screen shrinks it rather than overflowing.
const double _kSliderWidth = 320;

/// The slider's total vertical footprint.
///
/// Room, not thumb size: it is clamped to at least the lifted thumb and
/// wants headroom above that for the squash at the end of a throw —
/// below roughly 42 the deformation starts to clip. Leave it off
/// entirely and the control derives its own, which is the safe choice;
/// it is set here only to show the knob.
const double _kSliderHeight = 48;

/// The toggle's track — the capsule the thumb rides along.
///
/// The thumb is a separate tuned pair and does not scale with these; a
/// switch that grows in proportion wants
/// `LiquidGlassSwitchLayout().scaled(…)` instead.
const double _kToggleWidth = 63;
const double _kToggleHeight = 28;

// =============================================================
// One toggle, one slider — the two glass controls on their own, with
// nothing else on the page to read them against.
//
//   flutter run -t lib/basic_controls_page.dart
//
// The fuller demos live in `switch_page.dart` and
// `slider_page.dart`; this page is the pair at their plainest.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BasicControlsApp());
}

class _BasicControlsApp extends StatelessWidget {
  const _BasicControlsApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const BasicControlsPage(),
    );
  }
}

class BasicControlsPage extends StatefulWidget {
  const BasicControlsPage({super.key});

  @override
  State<BasicControlsPage> createState() => _BasicControlsPageState();
}

class _BasicControlsPageState extends State<BasicControlsPage> {
  bool _enabled = true;
  double _level = 0.55;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A flat off-white behind the glass — dimmed rather than pure
          // white, so the thumb's rim and shadow still have something to
          // sit against.
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFE9E9EC)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              children: [
                const Text(
                  'Basic controls',
                  style: TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'A single switch and a single slider, side by side.',
                  style: TextStyle(color: Color(0x9911131A), fontSize: 14),
                ),
                const SizedBox(height: 26),
                _card([
                  _switchRow(),
                  _divider(),
                  _sliderRow(),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: Colors.black.withValues(alpha: 0.07),
      );

  Widget _switchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded,
              size: 21, color: Colors.black.withValues(alpha: 0.75)),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Wi-Fi',
              style: TextStyle(
                color: Color(0xFF11131A),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          LiquidGlassSwitch(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            width: _kToggleWidth,
            height: _kToggleHeight,
            activeColor: const Color(0xFF34C759),
            inactiveColor: _kRestTrackColor,
          ),
        ],
      ),
    );
  }

  Widget _sliderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.light_mode_rounded,
                  size: 21, color: Colors.black.withValues(alpha: 0.75)),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Brightness',
                  style: TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${(_level * 100).round()}%',
                style: const TextStyle(
                  color: _kSliderBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              // Derive the width from constraints, never MediaQuery: a
              // MediaQuery dependency here rebuilds every LiquidGlassView
              // when it settles on the first frame, mid-capture. Clamp at 0
              // too — the warm-up frame can report a zero width, and a
              // negative SizedBox width takes the whole glass subtree down
              // with it.
              final double avail = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : _kSliderWidth;
              final double w = math.max(0.0, math.min(_kSliderWidth, avail));
              return Center(
                child: LiquidGlassSlider(
                  value: _level,
                  onChanged: (v) => setState(() => _level = v),
                  inactiveColor: _kRestTrackColor,
                  width: w,
                  height: _kSliderHeight,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
