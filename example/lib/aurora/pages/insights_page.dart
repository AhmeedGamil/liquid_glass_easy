import 'package:flutter/material.dart';

import '../data/aurora_data.dart';
import '../theme/aurora_theme.dart';
import '../widgets/aurora_charts.dart';
import '../widgets/aurora_motion.dart';
import '../widgets/aurora_page.dart';
import '../widgets/aurora_surface.dart';

/// Four charts, four different questions.
///
/// Nothing on this page is glass. Refraction moves what is behind it,
/// and a chart is a promise that the marks are where the data put them —
/// so the charts sit on flat plates and the glass stays in the bar.
class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  int _day = 5;
  int _range = 0; // 0 = week, 1 = month

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final weekTotal = kWeekMinutes.fold<double>(0, (a, b) => a + b);
    final average = weekTotal / kWeekMinutes.length;

    return ListView(
      padding: auroraPagePadding(context),
      children: [
        PageTitle(
          overline: 'LAST 7 DAYS',
          title: 'Insights',
          trailing: Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                AuroraChip(
                  label: i == 0 ? 'Week' : 'Month',
                  selected: _range == i,
                  onTap: () => setState(() => _range = i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Mindful minutes ──────────────────────────────────────
        Reveal(
          index: 1,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mindful minutes', style: AuroraText.section(p)),
                          const SizedBox(height: 4),
                          Text(
                            'Averaging ${average.round()} a day · target '
                            '${kWeekTarget.round()}',
                            style: AuroraText.body(p),
                          ),
                        ],
                      ),
                    ),
                    CountUp(
                      value: weekTotal,
                      suffix: 'm',
                      style: AuroraText.numeric(p, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AuroraBarChart(
                  values: kWeekMinutes,
                  labels: kWeekLabels,
                  selected: _day,
                  onSelect: (i) => setState(() => _day = i),
                  target: kWeekTarget,
                  unit: 'm',
                  color: p.series.first,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ── Sleep ────────────────────────────────────────────────
        Reveal(
          index: 2,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sleep depth', style: AuroraText.section(p)),
                const SizedBox(height: 4),
                Text(
                  'Seven nights, hour by hour. Wednesday and Saturday are '
                  'the two you woke up in.',
                  style: AuroraText.body(p),
                ),
                const SizedBox(height: 16),
                // 24 columns will not fit a phone, and squeezing the cells
                // to make them fit costs the grid its readability — so it
                // scrolls instead.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: AuroraHeatmap(
                    values: kSleepHeat,
                    rows: 7,
                    cell: 11,
                    gap: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ── Where the time went ──────────────────────────────────
        Reveal(
          index: 3,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where it went', style: AuroraText.section(p)),
                const SizedBox(height: 16),
                AuroraBreakdown(
                  slices: [
                    for (final row in kBreakdown)
                      BreakdownSlice(row.label, row.value),
                  ],
                  centerLabel: 'this week',
                  centerValue: '${weekTotal.round()}m',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ── Resting heart rate ───────────────────────────────────
        Reveal(
          index: 4,
          child: AuroraSurface(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AuroraStat(
                        label: 'RESTING HEART RATE',
                        value: kRestingHeartRate.round().toString(),
                        unit: 'bpm',
                        icon: Icons.favorite_rounded,
                        tint: p.series[3],
                        delta: '5 bpm since the 1st',
                        deltaUp: false,
                        deltaGood: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AuroraSparkline(
                  values: kHeartSeries,
                  color: p.series[3],
                  height: 76,
                  live: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
