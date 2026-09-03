import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'backdrop.dart';
import 'common.dart';
import 'data.dart';
import 'pages/browse_page.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/player_page.dart';
import 'pages/profile_page.dart';
import 'pages/search_page.dart';
import 'theme.dart';

// =============================================================
// The shell: one LiquidGlassScaffold, five tabs through it.
//
// The scaffold's `body` is the captured layer — here, nothing but the
// page's light. Everything else (the scrolling content, the fade bands,
// the mini player) is handed to `lenses`, the overlay stack that sits
// on top of that capture. That is the arrangement worth copying: put
// the art in the body and the UI in the overlay, and a glass card in
// the content refracts the light behind it without ever capturing
// itself.
//
// The chrome — app bar, mini player, tab bar — is owned here rather
// than by the pages, so it survives a tab change. The selection pill
// travels between tabs because the bar it lives in is never rebuilt.
// =============================================================

class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aurora',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF06060B),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const AuroraShell(),
    );
  }
}

class AuroraShell extends StatefulWidget {
  const AuroraShell({super.key});

  @override
  State<AuroraShell> createState() => _AuroraShellState();
}

class _AuroraShellState extends State<AuroraShell> {
  static const List<AuroraTab> _tabs = <AuroraTab>[
    HomeTab(),
    BrowseTab(),
    SearchTab(),
    LibraryTab(),
    ProfileTab(),
  ];

  static const double _barHeight = 62;
  static const double _barBottomMargin = 18;

  int _index = 0;

  /// Whether the mini player is on the current tab. It follows the
  /// music, not the page — only Search hides it, because a keyboard and
  /// a floating capsule want the same corner of the screen.
  bool get _showMiniPlayer => _index != 2;

  void _openPlayer() {
    Navigator.of(context).push(auroraRoute<void>(const PlayerPage()));
  }

  @override
  Widget build(BuildContext context) {
    final AuroraTab tab = _tabs[_index];
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final double screen = MediaQuery.sizeOf(context).width;
    final double barWidth = (screen - 32).clamp(280.0, 520.0);

    return LiquidGlassBatch(
      child: LiquidGlassScaffold(
        pixelRatio: 1,
        useSync: true,
        
        // The captured layer: the room's light, and the page standing in
        // it. Both go in `body` because that is what the chrome captures
        // — put the scrolling content up in `lenses` instead and it would
        // paint OVER the tab bar rather than sliding under it.
        body: Stack(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              child: AuroraBackdrop(
                key: ValueKey<String>(tab.label),
                palette: tab.palette,
                seed: tab.label,
              ),
            ),
            // The page. Keyed, so switching tabs cross-fades rather than
            // reusing the outgoing page's scroll position and state.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 340),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey<String>(tab.label),
                child: tab.content(context),
              ),
            ),
        
            // Content dims and softens into the bottom edge — inside the
            // body, so the bar and the mini player float ABOVE the band
            // and refract it, instead of the band covering them.
            // Positioned(
            //   bottom: 0,
            //   left: 0,
            //   right: 0,
            //   height: pad.bottom + 152,
            //   child: const IgnorePointer(
            //     child: LiquidGlassScrollEdge(
            //       blur: 6,
            //       color: Color(0xB306060B),
            //     ),
            //   ),
            // ),
          ],
        ),
      
        // The floating layer, back to front.
        lenses: <Widget>[
          // Content dims and softens as it passes under the app bar: one
          // BackdropFilter, feathered so the band never lands on a
          // visible line.
          //
          // Only at the top. With a glass selection pill the tab bar owns
          // the whole pipeline and paints BENEATH these overlay slots, so
          // a matching band at the bottom would blur the bar itself out
          // of existence — and it is not needed there, since the bar and
          // the mini player are lenses and already blur and bend what
          // passes behind them.
          // Positioned(
          //   top: 0,
          //   left: 0,
          //   right: 0,
          //   height: pad.top + 66,
          //   child: const IgnorePointer(
          //     child: LiquidGlassScrollEdge(
          //       edge: LiquidGlassEdge.top,
          //       blur: 6,
          //       color: Color(0x9E06060B),
          //     ),
          //   ),
          // ),
      
          // The mini player rides above that band, under the bar.
          if (_showMiniPlayer)
            Positioned(
              left: 16,
              right: 16,
              bottom: pad.bottom + _barBottomMargin + _barHeight + 12,
              child: _MiniPlayer(accent: tab.palette.accent, onTap: _openPlayer),
            ),
        ],
      
        appBar: LiquidGlassAppBar(
          width: barWidth,
          height: 54,
          centerTitle: false,
          horizontalPadding: 18,
          style: auroraChrome(radius: 27),
          foregroundColor: const Color(0xFFF4F3F8),
          title: Row(
            children: <Widget>[
              Text(
                tab.title,
                style: kTitle.copyWith(fontSize: 17.5, letterSpacing: -0.3),
              ),
            ],
          ),
          actions: tab.actions(context),
        ),
      
        bottomNavigationBar: LiquidGlassTabBar(
          items: <LiquidGlassTabBarItem>[
            for (final AuroraTab t in _tabs)
              LiquidGlassTabBarItem(icon: t.icon, label: t.label),
          ],
          selectedIndex: _index,
          onChanged: (int i) => setState(() => _index = i),
          width: barWidth,
          height: _barHeight,
          itemPadding: 4,
          margin: const EdgeInsets.only(bottom: _barBottomMargin),
          style: auroraChrome(radius: _barHeight / 2),
      
          // The selected colour is the PAGE's accent, so the bar picks up
          // the room it is standing in — the one place in the app where
          // chrome and content share a colour.
          itemStyle: LiquidGlassTabItemStyle(
            selectedColor: tab.palette.accent,
            unselectedColor: const Color(0x8AEDECF5),
            iconSize: 21,
            underGlassIconSize: 23,
            labelFontSize: 9.5,
            iconLabelGap: 3,
            selectedFontWeight: FontWeight.w700,
            unselectedFontWeight: FontWeight.w500,
          ),
      
          // The glass-refracting pill, on both renderers. What it comes
          // to rest in is a barely-there patch: the accent glyph already
          // says which tab is selected, so the pill only has to say where
          // it travelled.
          pillStyle: LiquidGlassTabPillStyle(
            mode: LiquidGlassPillMode.both,
            rest: LiquidGlassStyle(
              shape: const LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: 24,
                borderWidth: 0.6,
              ),
              appearance: LiquidGlassAppearance(
                color: tab.palette.accent.withValues(alpha: 0.14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The capsule above the tab bar: art, what is playing, one control.
///
/// It is glass rather than a filled bar because it spends its life over
/// scrolling content — the thing a lens is for.
class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    const Album album = kNowPlaying;
    return Pressable(
      onTap: widget.onTap,
      scale: 0.98,
      child: LiquidGlassLens(
        style: auroraChrome(radius: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: <Widget>[
              CoverArt(seed: album.seed, size: 40, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      album.tracks.first.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kBody.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => setState(() => _playing = !_playing),
                scale: 0.9,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 26,
                    color: widget.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
