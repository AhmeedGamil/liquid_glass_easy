import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../theme.dart';
import 'album_page.dart';

// =============================================================
// Library — the shelf.
//
// A filter row, a card of numbers, and everything you own. The rim
// here is doing the least showy job in the app: it draws the summary
// card at the top, the one thing that stays while the list under it
// changes, and it is what says that card is not another row.
// =============================================================

class LibraryTab extends AuroraTab {
  const LibraryTab();

  @override
  String get title => 'Library';

  @override
  String get label => 'Library';

  @override
  IconData get icon => Icons.library_music_rounded;

  @override
  AuroraPalette get palette => AuroraPalette.moss;

  @override
  List<Widget> actions(BuildContext context) => <Widget>[
        const Icon(Icons.sort_rounded, size: 20),
      ];

  @override
  Widget content(BuildContext context) => const _LibraryContent();
}

enum _Filter { all, albums, downloads }

class _LibraryContent extends StatefulWidget {
  const _LibraryContent();

  @override
  State<_LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends State<_LibraryContent> {
  static const Color _accent = Color(0xFF7BE8B0);

  _Filter _filter = _Filter.all;

  List<Album> get _shown => switch (_filter) {
        _Filter.all => kAlbums,
        _Filter.albums => kAlbums.take(4).toList(),
        _Filter.downloads =>
          kAlbums.where((Album a) => a.year != '2023').toList(),
      };

  @override
  Widget build(BuildContext context) {
    final List<Album> shown = _shown;

    return AuroraList(
      children: <Widget>[
        const SizedBox(height: 8),
        Text('Kept', style: kEyebrow),
        const SizedBox(height: 10),
        Text('Six records,\nall of them offline.',
            style: kDisplay.copyWith(fontSize: 32)),
        const SizedBox(height: 22),

        // ── The summary card ─────────────────────────────────
        GlassPanel(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          // Four columns sharing the width evenly — on a narrow phone
          // the row is only as wide as the card, so each one takes a
          // quarter of it rather than its natural width.
          child: const Row(
            children: <Widget>[
              Expanded(child: StatColumn('6', 'Albums', accent: _accent)),
              Expanded(child: StatColumn('27', 'Tracks')),
              Expanded(child: StatColumn('1.9', 'Hours')),
              Expanded(child: StatColumn('412', 'MB')),
            ],
          ),
        ),

        const SizedBox(height: 20),
        // Wrapped rather than in a Row: three chips plus an icon do not
        // fit a small phone on one line, and a second line is a better
        // answer than a clipped third chip.
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: <Widget>[
            AuroraChip(
              label: 'All',
              accent: _accent,
              selected: _filter == _Filter.all,
              onTap: () => setState(() => _filter = _Filter.all),
            ),
            AuroraChip(
              label: 'Albums',
              accent: _accent,
              selected: _filter == _Filter.albums,
              onTap: () => setState(() => _filter = _Filter.albums),
            ),
            AuroraChip(
              label: 'Downloaded',
              accent: _accent,
              icon: Icons.download_done_rounded,
              selected: _filter == _Filter.downloads,
              onTap: () => setState(() => _filter = _Filter.downloads),
            ),
          ],
        ),
        const SizedBox(height: 18),

        for (final Album a in shown) ...<Widget>[
          AlbumRow(
            album: a,
            artSize: 58,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.download_done_rounded,
                  size: 18, color: _accent.withValues(alpha: 0.8)),
            ),
            onTap: () => Navigator.of(context)
                .push(auroraRoute<void>(AlbumPage(album: a))),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),
        Center(
          child: Text('Everything here plays without a connection.',
              style: kBody.copyWith(fontSize: 12)),
        ),
      ],
    );
  }
}
