import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Slider + toggle** — the drop-in controls, wired to something real.
///
/// Every control on this page *does* what it says: brightness dims the wall,
/// warmth shifts its palette, the switches turn rows on and off and grey out
/// what they disable. A control panel where nothing is connected teaches you
/// what a widget looks like; this one lets you feel the jelly while watching
/// the value land.
///
/// ## No LiquidGlassView here
///
/// [LiquidGlassSlider] and [LiquidGlassToggle] are **self-contained**: each
/// supplies its own background and refracts its own track, so they work
/// anywhere on both engines with no capture pipeline around them. That is why
/// this page has no view and no per-frame capture at all — the backdrop is a
/// plain painted widget, not something being rasterized for a lens.
///
/// The thumb carries the shared jelly: it stretches toward its travel and
/// recoils on settle, with the squash weighted to the side it came from.
class ControlsDemo extends StatefulWidget {
  const ControlsDemo({super.key});

  @override
  State<ControlsDemo> createState() => _ControlsDemoState();
}

class _ControlsDemoState extends State<ControlsDemo> {
  double _brightness = 0.72;
  double _warmth = 0.35;
  double _volume = 0.5;

  bool _nightMode = false;
  bool _autoDim = true;
  bool _sounds = true;

  /// The wall the controls are dimming. Brightness drives its opacity and
  /// warmth blends the palette, so both sliders have visible consequences.
  Color get _wash => Color.lerp(
        const Color(0xFF4FB3FF),
        const Color(0xFFFFB020),
        _warmth,
      )!;

  @override
  Widget build(BuildContext context) {
    // Night mode caps the room and locks the sliders that would fight it —
    // a disabled control needs to *look* disabled, or the page is lying.
    final double lit = _nightMode ? 0.18 : _brightness;

    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackdrop.dusk(),

        // The lit wall. AnimatedContainer so a toggle reads as a transition
        // rather than a jump cut.
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.55),
              radius: 1.1,
              colors: [
                _wash.withValues(alpha: 0.55 * lit),
                _wash.withValues(alpha: 0.06 * lit),
                Colors.transparent,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),

        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The slider takes its width from its layout descriptor, so it
              // has to be told the room it has rather than filling it.
              final double sliderW =
                  (constraints.maxWidth - 72).clamp(180.0, 300.0);

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  _Header(lit: lit, nightMode: _nightMode),
                  const SizedBox(height: 22),

                  _Card(
                    title: 'ROOM',
                    children: [
                      _SliderRow(
                        icon: Icons.brightness_6_rounded,
                        label: 'Brightness',
                        value: _brightness,
                        width: sliderW,
                        enabled: !_nightMode,
                        readout: '${(_brightness * 100).round()}%',
                        onChanged: (v) => setState(() => _brightness = v),
                      ),
                      _SliderRow(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Warmth',
                        value: _warmth,
                        width: sliderW,
                        enabled: !_nightMode,
                        readout: _warmth < 0.34
                            ? 'Cool'
                            : (_warmth < 0.67 ? 'Neutral' : 'Warm'),
                        activeColor: _wash,
                        onChanged: (v) => setState(() => _warmth = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _Card(
                    title: 'AUDIO',
                    children: [
                      _SliderRow(
                        icon: _volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        label: 'Volume',
                        value: _volume,
                        width: sliderW,
                        enabled: _sounds,
                        readout: '${(_volume * 100).round()}',
                        onChanged: (v) => setState(() => _volume = v),
                      ),
                      _ToggleRow(
                        icon: Icons.graphic_eq_rounded,
                        label: 'Sound effects',
                        subtitle: _sounds ? 'On' : 'Muted',
                        value: _sounds,
                        onChanged: (v) => setState(() => _sounds = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _Card(
                    title: 'SCHEDULE',
                    children: [
                      _ToggleRow(
                        icon: Icons.nightlight_round,
                        label: 'Night mode',
                        subtitle: _nightMode
                            ? 'Dimmed — brightness locked'
                            : 'Off',
                        value: _nightMode,
                        activeColor: const Color(0xFF7C5CFF),
                        onChanged: (v) => setState(() => _nightMode = v),
                      ),
                      _ToggleRow(
                        icon: Icons.motion_photos_auto_rounded,
                        label: 'Auto dim at sunset',
                        subtitle: _autoDim ? 'Enabled' : 'Disabled',
                        value: _autoDim,
                        onChanged: (v) => setState(() => _autoDim = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const DemoHint(
                      'Drag a thumb quickly and let go — it stretches toward '
                      'the travel, then recoils'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final double lit;
  final bool nightMode;

  const _Header({required this.lit, required this.nightMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nightMode ? 'NIGHT' : 'LIVING ROOM',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${(lit * 100).round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
            const Text('%',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ],
    );
  }
}

/// A titled group of rows. Plain, not glass — the controls are the glass.
class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: const Color(0x59FFFFFF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double width;
  final bool enabled;
  final String readout;
  final Color? activeColor;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.width,
    required this.enabled,
    required this.readout,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: enabled ? 1 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500)),
                ),
                Text(readout,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: !enabled,
              child: LiquidGlassSlider(
                value: value,
                onChanged: onChanged,
                activeColor: activeColor ?? Colors.white,
                layout: LiquidGlassSliderLayout(width: width),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final Color? activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          LiquidGlassToggle(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor ?? const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }
}
