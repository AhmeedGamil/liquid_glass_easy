import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../common.dart';
import '../data.dart';
import '../theme.dart';
import 'player_page.dart';

// =============================================================
// A record.
//
// The page's light is generated from the same seed as the artwork on
// it, so every album arrives in its own colour — push two in a row and
// the whole room changes, glass included.
//
// This one runs its own `LiquidGlassScaffold` (no tab bar, an extended
// FAB instead), which is the second useful shape for the scaffold: art
// in the `body`, content in `lenses`, chrome in the named slots.
// =============================================================

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final AuroraPalette palette = AuroraPalette.fromSeed(album.seed);
    final Color accent = palette.accent;
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final double art =
        (MediaQuery.sizeOf(context).width - 130).clamp(160.0, 260.0);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: AuroraBackdrop(palette: palette, seed: album.seed),
      lenses: <Widget>[
        AuroraList(
          bottom: 128,
          children: <Widget>[
            const SizedBox(height: 6),

            // The cover, standing on its own shadow.
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  // Pulled well in and kept soft: on a near-black page a
                  // tight shadow stops reading as depth and starts
                  // reading as a second, darker rectangle.
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 60,
                      spreadRadius: -22,
                      offset: const Offset(0, 26),
                    ),
                  ],
                ),
                child: CoverArt(seed: album.seed, size: art, radius: 28),
              ),
            ),

            const SizedBox(height: 26),
            Text(album.title, style: kDisplay.copyWith(fontSize: 32)),
            const SizedBox(height: 8),
            // One paragraph, two styles: a Row of the same two pieces
            // cannot wrap, and the runtime string is long enough that
            // it would run off a narrow phone.
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: album.artist,
                    style: kTitle.copyWith(fontSize: 15, color: accent),
                  ),
                  TextSpan(
                      text: '  ·  ${album.year}  ·  ${album.runtime}',
                      style: kBody),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(album.blurb, style: kBody.copyWith(fontSize: 14)),
            const SizedBox(height: 20),

            // Three rimmed controls, side by side. Their light comes
            // from the page they are on rather than from the widget, so
            // on a record whose seed lands in the reds they are red —
            // the FAB below them, a real lens, agrees with them because
            // it is reading the same room.
            Row(
              children: <Widget>[
                Expanded(
                  child: GlassButton(
                    label: 'Shuffle',
                    icon: Icons.shuffle_rounded,
                    height: 46,
                    radius: 23,
                    onPressed: () => Navigator.of(context)
                        .push(auroraRoute<void>(const PlayerPage())),
                  ),
                ),
                const SizedBox(width: 10),
                GlassButton(
                  icon: Icons.add_rounded,
                  width: 56,
                  height: 46,
                  radius: 23,
                  onPressed: () =>
                      showAuroraToast(context, 'Added to your library'),
                ),
                const SizedBox(width: 10),
                GlassButton(
                  icon: Icons.download_rounded,
                  width: 56,
                  height: 46,
                  radius: 23,
                  onPressed: () => showAuroraToast(context, 'Downloading…'),
                ),
              ],
            ),

            const SizedBox(height: 26),
            SectionHeader('Tracks', eyebrow: album.runtime, accent: accent),
            for (int i = 0; i < album.tracks.length; i++)
              TrackRow(
                index: i,
                track: album.tracks[i],
                accent: accent,
                playing: i == 0,
                onTap: () => Navigator.of(context)
                    .push(auroraRoute<void>(const PlayerPage())),
              ),

            const SizedBox(height: 26),
            Text(
              '℗ ${album.year} Aurora Recordings. Mastered for the room '
              'it was recorded in.',
              style: kBody.copyWith(
                  fontSize: 11.5, color: const Color(0x66EDECF5)),
            ),
          ],
        ),

        // The fade the title passes under on its way out of view.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: pad.top + 66,
          child: const IgnorePointer(
            child: LiquidGlassScrollEdge(
              edge: LiquidGlassEdge.top,
              blur: 6,
              color: Color(0x9E000000),
            ),
          ),
        ),
      ],
      appBar: LiquidGlassAppBar(
        width: (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 520.0),
        height: 52,
        centerTitle: true,
        style: auroraChrome(radius: 26),
        foregroundColor: const Color(0xFFF4F3F8),
        leading: Pressable(
          onTap: () => Navigator.of(context).maybePop(),
          scale: 0.88,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
          ),
        ),
        title: Text('ALBUM', style: kEyebrow.copyWith(fontSize: 10)),
        actions: <Widget>[
          Pressable(
            onTap: () => showAuroraToast(context, 'Link copied'),
            scale: 0.88,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.ios_share_rounded, size: 18),
            ),
          ),
        ],
      ),
      floatingActionButton: LiquidGlassFab.extended(
        label: const Text('Play',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        icon: Icons.play_arrow_rounded,
        height: 52,
        foregroundColor: Colors.white,
        style: auroraGlass(
          radius: 26,
          tint: accent.withValues(alpha: 0.30),
          blur: 5,
          distortion: 0.09,
          shadow: const LiquidGlassShadow(blur: 12, opacity: 0.3),
        ),
        onPressed: () =>
            Navigator.of(context).push(auroraRoute<void>(const PlayerPage())),
      ),
      floatingActionButtonAlignment: Alignment.bottomCenter,
    );
  }
}
