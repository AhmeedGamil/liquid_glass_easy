import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Accent used across the tuner / demo chrome.
const Color kTunerAccent = Color(0xFFB79CFF);

/// The shared purple gradient backdrop for the tuner pages.
class TunerGradientBackground extends StatelessWidget {
  final Widget child;
  const TunerGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12082B), Color(0xFF2A1B5E), Color(0xFF4B2D7A)],
        ),
      ),
      child: child,
    );
  }
}

/// Small uppercase-ish panel heading.
class TunerPanelTitle extends StatelessWidget {
  final String text;
  const TunerPanelTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 14,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      );
}

/// A green/pink status badge ("SETTLES" / "BOUNCES").
class TunerBadge extends StatelessWidget {
  final String text;
  final bool good;
  const TunerBadge({super.key, required this.text, required this.good});

  @override
  Widget build(BuildContext context) {
    final base = good ? const Color(0xFF34C759) : const Color(0xFFFF5E8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: good ? const Color(0xFF6FE08A) : const Color(0xFFFF8FB0))),
    );
  }
}

/// A plain frosted card grouping a set of controls. Deliberately **not** a
/// glass lens — the live glass is the slider / nav pill itself; nesting
/// capturing controls inside lenses (inside a scrollable) is what we avoid.
class TunerCard extends StatelessWidget {
  final Widget child;
  const TunerCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: child,
      ),
    );
  }
}

/// One labelled Material slider with a live numeric readout — the tuner's
/// editing control (not to be confused with `LiquidGlassSlider`).
class TunerParamSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const TunerParamSlider(
    this.label,
    this.value,
    this.min,
    this.max,
    this.display,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ),
        SizedBox(
          width: 42,
          child: Text(display,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: kTunerAccent)),
        ),
        Expanded(
          child: SizedBox(
            height: 32,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: kTunerAccent,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// The "Current values" card: the live code snippet plus Copy + Reset.
class TunerCodeCard extends StatelessWidget {
  final String snippet;
  final VoidCallback onReset;

  const TunerCodeCard({super.key, required this.snippet, required this.onReset});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: snippet));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return TunerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TunerPanelTitle('Current values'),
              const Spacer(),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: FilledButton.styleFrom(
                  backgroundColor: kTunerAccent,
                  foregroundColor: const Color(0xFF1A1030),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            snippet,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
