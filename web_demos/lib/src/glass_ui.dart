import 'package:flutter/material.dart';

/// Small shared chrome for the demos — hints, panels, sliders, preset chips.
///
/// Deliberately **not** glass. Every one of these sits on top of the thing
/// being demonstrated, and a control made of the same material as the subject
/// competes with it. Plain translucent panels keep the glass the only glass on
/// screen.

/// A muted one-liner telling you what to do with the demo.
class DemoHint extends StatelessWidget {
  final String text;
  const DemoHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 13,
          height: 1.35,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// The floating control surface the sliders and chips sit on.
class DemoPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DemoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 6, 14, 6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB30B0B12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 20, spreadRadius: -6),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Label · track · value, sized so the readout never shifts the track as the
/// number changes (tabular figures + a fixed column).
class DemoSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String readout;
  final ValueChanged<double> onChanged;

  const DemoSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.readout,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12.5,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            readout,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// A selectable pill. Used to switch between named presets, where the whole
/// point is comparing one against another.
class DemoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DemoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0 : 0.16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF120B24) : Colors.white70,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
