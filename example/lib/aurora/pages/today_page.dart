import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../data/aurora_data.dart';
import '../theme/aurora_theme.dart';
import '../widgets/aurora_charts.dart';
import '../widgets/aurora_motion.dart';
import '../widgets/aurora_page.dart';
import '../widgets/aurora_surface.dart';
import 'session_player_page.dart';

/// The landing page: three rings, the calm score, and one glass button
/// pointing at the session you should probably do next.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final delta = kCalmScore - kCalmScoreYesterday;

    return ListView(
      padding: auroraPagePadding(context),
      children: [
        PageTitle(
          overline: kTodayLabel,
          title: 'Good evening,\n$kUserName',
          gradient: true,
          trailing: AuroraChip(
            label: '$kStreakDays days',
            icon: Icons.local_fire_department_rounded,
            color: p.warning,
          ),
        ),
        const SizedBox(height: 26),

        // ── The rings ────────────────────────────────────────────
        Reveal(
          index: 1,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              children: [
                ActivityRings(
                  data: const [
                    RingDatum(
                      label: 'Move',
                      value: kMoveMinutes,
                      goal: kMoveGoal,
                      unit: 'min',
                      icon: Icons.directions_walk_rounded,
                    ),
                    RingDatum(
                      label: 'Breathe',
                      value: kBreatheMinutes,
                      goal: kBreatheGoal,
                      unit: 'min',
                      icon: Icons.air_rounded,
                    ),
                    RingDatum(
                      label: 'Sleep',
                      value: kSleepHours,
                      goal: kSleepGoal,
                      unit: 'h',
                      icon: Icons.bedtime_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Divider(color: p.stroke, height: 1),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Calm score', style: AuroraText.label(p)),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              CountUp(
                                value: kCalmScore,
                                style: AuroraText.numeric(p, size: 34),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                delta >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                size: 16,
                                color: delta >= 0 ? p.success : p.danger,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${delta >= 0 ? '+' : ''}${delta.round()}',
                                style: TextStyle(
                                  color: delta >= 0 ? p.success : p.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 128,
                      child: AuroraSparkline(
                        values: kCalmSeries,
                        height: 56,
                        showDot: true,
                        color: p.series.first,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── The page's one glass control ─────────────────────────
        Reveal(index: 2, child: const _StartSessionButton()),
        const SizedBox(height: 30),

        SectionHeader(
          title: 'Pick up where you left off',
          action: 'Library',
          onAction: () {},
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
        ),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => Reveal(
              index: 3 + i,
              offsetY: 14,
              child: _SessionTile(session: kSessions[i]),
            ),
          ),
        ),
        const SizedBox(height: 26),

        Reveal(
          index: 6,
          child: AuroraSurface(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.info.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.nightlight_round, size: 19, color: p.info),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wind down at 21:30', style: AuroraText.section(p)),
                      const SizedBox(height: 3),
                      Text(
                        'You fall asleep 22 minutes faster on the nights you '
                        'do.',
                        style: AuroraText.body(p),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The hero: a real lens, sitting on the drifting field it refracts.
class _StartSessionButton extends StatelessWidget {
  const _StartSessionButton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = kFeaturedSession;

    // NOT PressableScale. An ancestor Transform scales the painted quad
    // without telling the shader, which is handed the lens's layout size —
    // so its outline overhangs the real geometry and the clip eats the rim
    // off the right and bottom edges. The lens deforms itself instead, on
    // the one path where the shader, the clip and the outline agree.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        AuroraPageRoute(
          builder: (_) => SessionPlayerPage(session: session),
        ),
      ),
      child: SizedBox(
        height: 84,
        child: LiquidGlassLens(
          style: p.glass(radius: 28, blur: 3, distortion: 0.13),
          // Press-only: `stretch: 0` keeps a drag from fighting the list
          // it sits in, and the negative scales yield inward, matching the
          // press physics every other Aurora surface uses.
          touch: const LiquidGlassTouch.flexing(
            LiquidGlassFlex(
              stretch: 0,
              lean: 0,
              holdScale: -0.030,
              tapScale: -0.020,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Breathe(
                  amount: 0.05,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [p.accent, p.series[1]],
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: p.onAccent,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('START NOW', style: AuroraText.caps(p)),
                      const SizedBox(height: 5),
                      Text(session.title, style: AuroraText.section(p)),
                      const SizedBox(height: 2),
                      Text(
                        '${session.minutes} min · brings the heart rate down',
                        style: AuroraText.label(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A session as a card in the horizontal strip.
class _SessionTile extends StatelessWidget {
  final AuroraSession session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = p.series[session.slot % p.series.length];

    return SizedBox(
      width: 168,
      child: AuroraSurface(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: p.isDark ? 0.30 : 0.20),
            c.withValues(alpha: p.isDark ? 0.10 : 0.07),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          AuroraPageRoute(builder: (_) => SessionPlayerPage(session: session)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(session.kind.icon, color: c, size: 22),
            const Spacer(),
            Text(
              session.title,
              style: AuroraText.section(p),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${session.kind.label} · ${session.minutes} min',
              style: AuroraText.label(p),
            ),
          ],
        ),
      ),
    );
  }
}
