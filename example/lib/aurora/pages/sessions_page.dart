import 'package:flutter/material.dart';

import '../data/aurora_data.dart';
import '../theme/aurora_theme.dart';
import '../widgets/aurora_gooey.dart';
import '../widgets/aurora_motion.dart';
import '../widgets/aurora_page.dart';
import '../widgets/aurora_surface.dart';
import 'session_player_page.dart';

/// The library.
///
/// No glass here on purpose: this page's job is to hand you off to the
/// player, and the player is where the hero lens lives. A browse list
/// that competes with its own destination is a worse list.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  /// `null` = everything.
  SessionKind? _filter;

  List<AuroraSession> get _visible => _filter == null
      ? kSessions
      : kSessions.where((s) => s.kind == _filter).toList();

  void _open(AuroraSession session) => Navigator.of(context).push(
        AuroraPageRoute(builder: (_) => SessionPlayerPage(session: session)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = _visible;

    return ListView(
      padding: auroraPagePadding(context),
      children: [
        const PageTitle(overline: 'LIBRARY', title: 'Sessions'),
        const SizedBox(height: 20),

        Reveal(
          index: 1,
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AuroraChip(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final kind in SessionKind.values) ...[
                  const SizedBox(width: 9),
                  AuroraChip(
                    label: kind.label,
                    icon: kind.icon,
                    selected: _filter == kind,
                    onTap: () => setState(() => _filter = kind),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        Reveal(
            index: 2, child: _Featured(onTap: () => _open(kFeaturedSession))),
        const SizedBox(height: 28),

        SectionHeader(
          title:
              _filter == null ? 'All sessions' : '${_filter!.label} sessions',
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        ),

        // Keyed on the filter so the rows re-stagger when the list changes
        // — otherwise a filter tap swaps content with no motion at all.
        for (var i = 0; i < visible.length; i++)
          Padding(
            key: ValueKey('${_filter?.name}-${visible[i].title}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Reveal(
              index: i,
              offsetY: 16,
              child: _SessionRow(
                session: visible[i],
                onTap: () => _open(visible[i]),
              ),
            ),
          ),

        const SizedBox(height: 8),
        Center(
          child: Text(
            '${kSessions.length} sessions · $kStreakDays day streak',
            style: AuroraText.label(p),
          ),
        ),
      ],
    );
  }
}

/// The one card that gets to be big, with the app's mark breathing in it.
class _Featured extends StatelessWidget {
  final VoidCallback onTap;

  const _Featured({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = p.series[kFeaturedSession.slot % p.series.length];

    return AuroraSurface(
      padding: EdgeInsets.zero,
      radius: 28,
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c.withValues(alpha: p.isDark ? 0.34 : 0.24),
          p.accent.withValues(alpha: p.isDark ? 0.16 : 0.12),
        ],
      ),
      child: SizedBox(
        height: 196,
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -18,
              child: BlobMorph(size: 168, wobble: 0.14, colors: [c, p.accent]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TONIGHT', style: AuroraText.caps(p)),
                  const Spacer(),
                  Text(kFeaturedSession.title, style: AuroraText.title(p)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 210,
                    child: Text(
                      kFeaturedSession.subtitle,
                      style: AuroraText.body(p),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.play_circle_fill_rounded, color: c, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${kFeaturedSession.minutes} min',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final AuroraSession session;
  final VoidCallback onTap;

  const _SessionRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = p.series[session.slot % p.series.length];

    return AuroraSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(session.kind.icon, color: c, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title, style: AuroraText.section(p)),
                const SizedBox(height: 3),
                Text(
                  session.subtitle,
                  style: AuroraText.body(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${session.minutes}m', style: AuroraText.label(p)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: p.textFaint),
        ],
      ),
    );
  }
}
