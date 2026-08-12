import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../data/aurora_data.dart';
import '../theme/aurora_theme.dart';
import '../widgets/aurora_gooey.dart';
import '../widgets/aurora_motion.dart';
import '../widgets/aurora_page.dart';
import '../widgets/aurora_surface.dart';

/// The "You" tab: the profile, and the switches that repaint the app.
///
/// Two glass controls, both of which change something you can see the
/// moment you touch them — the toggle and the goal slider. The rows that
/// only lead somewhere stay flat, because a lens on a chevron is a lens
/// spent on nothing.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _goal = kBreatheGoal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = context.auroraController;

    return ListView(
      padding: auroraPagePadding(context),
      children: [
        const PageTitle(overline: 'YOU', title: kUserName),
        const SizedBox(height: 22),

        // ── Profile ──────────────────────────────────────────────
        Reveal(
          index: 1,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                BlobMorph(
                    size: 62, wobble: 0.13, colors: [p.accent, p.series[1]]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$kUserName Okafor', style: AuroraText.section(p)),
                      const SizedBox(height: 3),
                      Text(
                        'Member since March · $kStreakDays day streak',
                        style: AuroraText.body(p),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textFaint),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),

        // ── Appearance ───────────────────────────────────────────
        SectionHeader(
          title: 'Appearance',
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        ),
        Reveal(
          index: 2,
          child: AuroraSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THEME', style: AuroraText.caps(p)),
                const SizedBox(height: 12),
                // Wrap, not Row: these labels are localized eventually, and
                // three chips on one line is a coincidence, not a layout.
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final mode in ThemeMode.values)
                      AuroraChip(
                        label: switch (mode) {
                          ThemeMode.dark => 'Dark',
                          ThemeMode.light => 'Light',
                          ThemeMode.system => 'System',
                        },
                        selected: c.mode == mode,
                        onTap: () => c.mode = mode,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('ACCENT', style: AuroraText.caps(p)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final accent in AuroraController.accents)
                      _Swatch(
                        color: accent,
                        selected: c.accent == accent,
                        onTap: () => c.accent = accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),

        // ── The two glass controls ───────────────────────────────
        SectionHeader(
          title: 'Practice',
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        ),
        Reveal(
          index: 3,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reduce motion', style: AuroraText.section(p)),
                          const SizedBox(height: 3),
                          Text(
                            'Holds the drifting field and the ambient '
                            'animations still.',
                            style: AuroraText.body(p),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    LiquidGlassToggle(
                      value: c.reduceMotion,
                      onChanged: (v) => c.reduceMotion = v,
                      activeColor: p.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Divider(color: p.stroke, height: 1),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('Daily goal', style: AuroraText.section(p)),
                    ),
                    Text(
                      '${_goal.round()} min',
                      style: AuroraText.numeric(p, size: 17),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) => LiquidGlassSlider(
                    value: _goal,
                    minimumValue: 5,
                    maximumValue: 60,
                    onChanged: (v) => setState(() => _goal = v),
                    activeColor: p.accent,
                    inactiveColor: p.isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x2A101430),
                    layout: LiquidGlassSliderLayout(width: box.maxWidth),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),

        // ── Flat rows ────────────────────────────────────────────
        SectionHeader(
          title: 'More',
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        ),
        Reveal(
          index: 4,
          child: AuroraSurface(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Row(
                  icon: Icons.notifications_none_rounded,
                  label: 'Reminders',
                  value: 'Wind down · 21:30',
                ),
                _Divider(),
                _Row(
                  icon: Icons.favorite_border_rounded,
                  label: 'Health sources',
                  value: 'Watch, phone',
                ),
                _Divider(),
                _Row(
                  icon: Icons.lock_outline_rounded,
                  label: 'Privacy',
                  value: 'On device',
                ),
                _Divider(),
                _Row(
                  icon: Icons.info_outline_rounded,
                  label: 'About Aurora',
                  value: 'v1.0',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Built with liquid_glass_easy',
            style: AuroraText.caps(p),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? p.textPrimary : Colors.transparent,
            width: 2.4,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded,
                size: 16,
                color: ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black)
            : null,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: p.textSecondary),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: AuroraText.section(p))),
            Text(value, style: AuroraText.label(p)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.textFaint),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 46),
        child: Divider(color: context.palette.stroke, height: 1),
      );
}
