import 'package:flutter/material.dart';

import '../backdrop.dart';
import '../common.dart';
import '../data.dart';
import '../theme.dart';
import 'album_page.dart';
import 'player_page.dart';

// =============================================================
// Tonight — the front page.
//
// One hero card with a rim, then everything else in plain frost. The
// restraint is the design and not the arithmetic: a painted rim costs
// nothing, so the page could have had twenty. It has one because the
// eye goes to the lit edge, and a page of lit edges has no first line.
// =============================================================

class HomeTab extends AuroraTab {
  const HomeTab();

  @override
  String get title => 'Tonight';

  @override
  String get label => 'Home';

  @override
  IconData get icon => Icons.auto_awesome_rounded;

  @override
  AuroraPalette get palette => AuroraPalette.nightfall;

  @override
  List<Widget> actions(BuildContext context) => <Widget>[
        const Icon(Icons.notifications_none_rounded, size: 21),
      ];

  @override
  Widget content(BuildContext context) => const _HomeContent();
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF9E8CFF);

    return AuroraList(
      children: <Widget>[
        const SizedBox(height: 8),
        Text('Good evening.', style: kEyebrow),
        const SizedBox(height: 10),
        Text(
          'Something quiet\nto finish on.',
          style: kDisplay.copyWith(fontSize: 36),
        ),
        const SizedBox(height: 26),

        // ── The one rimmed card on the page ──────────────────
        // Blended, so the rim is not white here: it is lit by the
        // violet lamp in the top-left corner of this page's backdrop,
        // and it changes colour with the page when the tab does.
        _ContinueCard(accent: accent),

        const SizedBox(height: 30),
        SectionHeader(
          'Your mixes',
          eyebrow: 'Made for you',
          action: 'See all',
          accent: accent,
          onAction: () {},
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: kMixes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) =>
                _MixCard(mix: kMixes[i], accent: accent),
          ),
        ),

        const SizedBox(height: 30),
        SectionHeader(
          'New this week',
          eyebrow: 'Fresh',
          accent: accent,
          action: 'All',
          onAction: () {},
        ),
        for (final Album a in kAlbums.take(3)) ...<Widget>[
          AlbumRow(
            album: a,
            trailing: const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.play_arrow_rounded,
                  size: 22, color: Color(0x99EDECF5)),
            ),
            onTap: () => Navigator.of(context)
                .push(auroraRoute<void>(AlbumPage(album: a))),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 20),
        SectionHeader('Because you played Sable Hours',
            eyebrow: 'Threads', accent: accent),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: kAlbums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) {
              final Album a = kAlbums[kAlbums.length - 1 - i];
              return Pressable(
                onTap: () => Navigator.of(context)
                    .push(auroraRoute<void>(AlbumPage(album: a))),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CoverArt(seed: a.seed, size: 120, radius: 20),
                      const SizedBox(height: 9),
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kTitle.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(a.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kBody.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The record you left half-finished, in a card you can pick up.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    const Album album = kNowPlaying;

    return GlassPanel(
      radius: 30,
      padding: const EdgeInsets.all(16),
      tint: const Color(0x1FFFFFFF),
      onTap: () => Navigator.of(context)
          .push(auroraRoute<void>(const AlbumPage(album: album))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CoverArt(seed: album.seed, size: 88, radius: 20),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 2),
                    Text('CONTINUE LISTENING',
                        style: kEyebrow.copyWith(fontSize: 9.5, color: accent)),
                    const SizedBox(height: 9),
                    Text(album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTitle.copyWith(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text('${album.artist} · ${album.year}', style: kBody),
                    const SizedBox(height: 10),
                    // Where you got to: a hairline, not a widget.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: 0.42,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              // A rim inside a rim: the buttons are the same material as
              // the card they sit on, and the accent fill under the
              // left one is the only thing separating them.
              Expanded(
                child: GlassButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  tint: accent.withValues(alpha: 0.34),
                  onPressed: () => Navigator.of(context)
                      .push(auroraRoute<void>(const PlayerPage())),
                ),
              ),
              const SizedBox(width: 10),
              GlassButton(
                icon: Icons.favorite_border_rounded,
                width: 52,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A mix: its artwork, its name, and the icon it is filed under.
class _MixCard extends StatelessWidget {
  const _MixCard({required this.mix, required this.accent});

  final Mix mix;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {},
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CoverArt(
              seed: mix.seed,
              size: 150,
              radius: 22,
              scrim: true,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(mix.icon,
                      size: 22, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(mix.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kTitle.copyWith(fontSize: 14.5)),
            const SizedBox(height: 3),
            Text(mix.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kBody.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
