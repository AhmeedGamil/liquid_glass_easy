import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'app_settings.dart';

// =============================================================
// Settings — the gallery's own preferences page.
//
// Two glass switches, each bound to a notifier the gallery listens to:
//
//   • Dark mode → app_settings.dart's `darkMode`, which picks the
//     MaterialApp's themeMode. Every demo opened from the menu reads it
//     back through `Theme.of(context).brightness`.
//
// The setting is not persisted; it resets on restart.
//
//   flutter run -t lib/gallery.dart   → gear icon, top right
// =============================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : const Color(0xFF11131A);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: galleryBackground(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: ink.withValues(alpha: 0.8),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Appearance'),
              const SizedBox(height: 12),
              _Card(
                children: [
                  // Rebuilt from the notifier rather than page state: the
                  // MaterialApp above listens to the same one, so the
                  // switch and the whole app flip off a single source.
                  ValueListenableBuilder<bool>(
                    valueListenable: darkMode,
                    builder: (context, value, _) => _SwitchRow(
                      icon: value
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: 'Dark mode',
                      detail: value
                          ? 'Glass over a dark backdrop'
                          : 'Glass over a light backdrop',
                      value: value,
                      onChanged: (v) => darkMode.value = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: (dark ? Colors.white : const Color(0xFF11131A))
            .withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// The rounded panel the rows sit on — a translucent white in both
/// brightnesses, only at different strengths.
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dark ? 0.05 : 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }
}

/// One settings row: icon, label + detail, and the glass switch.
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : const Color(0xFF11131A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 21, color: ink.withValues(alpha: 0.75)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Shipped defaults throughout — the clear glass thumb, its
          // inset contact shadow and the pinched slice behind the glass
          // all come from LiquidGlassSwitch.defaultStyle.
          LiquidGlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
