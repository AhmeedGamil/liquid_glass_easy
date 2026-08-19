import 'package:flutter/material.dart';

/// Titled group of controls inside the tuning panel.
class TunerSection extends StatelessWidget {
  const TunerSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF6BE3FF),
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Labelled slider with a live value readout.
class TunerSlider extends StatelessWidget {
  const TunerSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(min, max);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: const Color(0xFF6BE3FF),
              inactiveTrackColor: const Color(0x334C5566),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: clamped,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _format(clamped),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  static String _format(double v) {
    final double a = v.abs();
    if (a >= 100) return v.toStringAsFixed(0);
    if (a >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

/// Single-choice chips laid out in a wrap.
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final T value in values)
            GestureDetector(
              onTap: () => onSelect(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: value == selected
                      ? const Color(0xFF6BE3FF)
                      : const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label(value),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: value == selected ? const Color(0xFF06121A) : Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Colour swatches; the alpha of the current tint is kept by the caller.
class SwatchRow extends StatelessWidget {
  const SwatchRow({
    super.key,
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          for (final Color color in colors)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onSelect(color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _sameHue(color, selected)
                          ? const Color(0xFF6BE3FF)
                          : const Color(0x33FFFFFF),
                      width: _sameHue(color, selected) ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static bool _sameHue(Color a, Color b) =>
      a.r == b.r && a.g == b.g && a.b == b.b;
}

/// Compact labelled switch.
class TunerSwitch extends StatelessWidget {
  const TunerSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        Switch(
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF6BE3FF),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
