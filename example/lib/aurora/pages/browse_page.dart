import 'package:flutter/material.dart';

import '../backdrop.dart';
import '../common.dart';
import '../data.dart';
import '../theme.dart';
import 'album_page.dart';

// =============================================================
// Browse — the page that argues for the painted rim.
//
// Seven lit surfaces on one screen: a featured card and a grid of six.
// As lenses that is seven reads of the backdrop, and the grid would
// have needed a `LiquidGlassBatch` to bring it down to two. As
// `LiquidGlassLite`s it is zero — the rims are triangle meshes, so
// the count stops mattering and the layout is free to do whatever it
// likes, including overlapping, which batched lenses may not.
//
// The tiles keep their gaps here anyway. That is spacing, not a rule.
// =============================================================

class BrowseTab extends AuroraTab {
  const BrowseTab();

  @override
  String get title => 'Browse';

  @override
  String get label => 'Browse';

  @override
  IconData get icon => Icons.grid_view_rounded;

  @override
  AuroraPalette get palette => AuroraPalette.ember;

  @override
  List<Widget> actions(BuildContext context) => <Widget>[
        const Icon(Icons.tune_rounded, size: 20),
      ];

  @override
  Widget content(BuildContext context) => const _BrowseContent();
}

class _BrowseContent extends StatelessWidget {
  const _BrowseContent();

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFFFFB067);
    const Album featured = kSlowAurora;

    return AuroraList(
      children: <Widget>[
        const SizedBox(height: 8),
        Text('Every record on the network.', style: kEyebrow),
        const SizedBox(height: 10),
        Text('Sorted by\nthe hour it suits.',
            style: kDisplay.copyWith(fontSize: 34)),
        const SizedBox(height: 24),

        // ── Featured ─────────────────────────────────────────
        GlassPanel(
          radius: 28,
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.of(context)
              .push(auroraRoute<void>(const AlbumPage(album: featured))),
          child: Row(
            children: <Widget>[
              CoverArt(seed: featured.seed, size: 76, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('ALBUM OF THE WEEK',
                        style: kEyebrow.copyWith(fontSize: 9.5, color: accent)),
                    const SizedBox(height: 8),
                    Text(featured.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTitle.copyWith(fontSize: 19)),
                    const SizedBox(height: 3),
                    Text(featured.artist, style: kBody),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),

        const SizedBox(height: 30),
        const SectionHeader('Genres', eyebrow: 'Six ways in', accent: accent),

        // ── The grid ─────────────────────────────────────────
        Column(
          children: <Widget>[
            for (int row = 0; row < kGenres.length ~/ 2; row++) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                      child:
                          _GenreTile(genre: kGenres[row * 2], accent: accent)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _GenreTile(
                          genre: kGenres[row * 2 + 1], accent: accent)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),

        const SizedBox(height: 22),
        const SectionHeader('Stations', eyebrow: 'On air now', accent: accent),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: kMixes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int i) {
              final Mix m = kMixes[i];
              return SizedBox(
                width: 210,
                child: FrostPanel(
                  onTap: () {},
                  radius: 22,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CoverArt(seed: m.seed, size: 42, radius: 12),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('LIVE',
                                style: kEyebrow.copyWith(
                                    fontSize: 9, color: accent)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(m.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kTitle.copyWith(fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(m.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kBody.copyWith(fontSize: 11.5)),
                        ],
                      ),
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

/// One tile in the grid.
class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.genre, required this.accent});

  final Genre genre;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(11),
      onTap: () => showAuroraToast(context, 'Browsing ${genre.name}'),
      child: Row(
        children: <Widget>[
          CoverArt(
            seed: genre.seed,
            size: 40,
            radius: 13,
            scrim: true,
            child: Center(child: Icon(genre.icon, size: 18, color: accent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(genre.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kTitle.copyWith(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
