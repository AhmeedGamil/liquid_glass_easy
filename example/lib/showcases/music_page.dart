import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: const MusicPage(),
    ));

/// The iOS 26 Music app's Home screen: a large title over carousels of
/// artwork, a mini player floating above the tab bar, and the tab bar with
/// search on a glass circle beside it.
///
/// The bar's capsule and the search circle share one blender, so they flow
/// together; the bar's moving glass pill stays out of it.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

/// Music's accent.
const Color _accent = Color(0xFFFA2D48);

/// An SF Symbols SVG from `assets/sf/`, [size] square, in [color].
Widget _sf(String symbol, double size, Color color) => SvgPicture.asset(
      'assets/sf/$symbol.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

LiquidGlassTabBarItem _sfTab(String symbol, String label) =>
    LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, g) => _sf(symbol, g.size, g.color),
    );

/// Artwork: a two-colour gradient with a soft disc, standing in for a
/// cover.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.colors, this.radius = 8});

  final List<Color> colors;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned(
                right: -c.maxWidth * 0.25,
                bottom: -c.maxWidth * 0.25,
                width: c.maxWidth * 0.8,
                height: c.maxWidth * 0.8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
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

class _MusicPageState extends State<MusicPage> {
  int _tab = 0;

  /// How far the capsule and the search circle flow into each other.
  static const double _smoothness = 15;

  static const double _edge = 16;
  static const double _barHeight = 62;
  /// The least gap under the bar, for screens that report no inset.
  static const double _minBottom = 12;
  static const double _playerHeight = 48;

  static final List<LiquidGlassTabBarItem> _tabs = [
    _sfTab('house.fill', 'Home'),
    _sfTab('square.grid.2x2.fill', 'New'),
    _sfTab('dot.radiowaves.left.and.right', 'Radio'),
    _sfTab('play.square.stack.fill', 'Library'),
  ];

  static const List<String> _titles = ['Home', 'New', 'Radio', 'Library'];

  static const List<List<Color>> _covers = [
    [Color(0xFFFF375F), Color(0xFFFF9F0A)],
    [Color(0xFF5E5CE6), Color(0xFF64D2FF)],
    [Color(0xFF30D158), Color(0xFF0A84FF)],
    [Color(0xFFBF5AF2), Color(0xFFFF375F)],
    [Color(0xFFFFD60A), Color(0xFFFF9F0A)],
    [Color(0xFF1C1C1E), Color(0xFF8E8E93)],
    [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
    [Color(0xFFFF9F0A), Color(0xFFFF375F)],
  ];

  static const List<(String, String)> _picks = [
    ('Made for You', 'Favourites Mix'),
    ('Made for You', 'New Music Mix'),
    ('Featuring Your Artists', 'Chill Mix'),
    ('Made for You', 'Get Up! Mix'),
  ];

  static const List<(String, String)> _recent = [
    ('Midnight Drive', 'The Weekends'),
    ('Golden Hour', 'Lumen'),
    ('Ocean Eyes', 'Blue Haze'),
    ('Paper Planes', 'Northbound'),
    ('Afterglow', 'Neon Coast'),
    ('Wildflowers', 'Juniper'),
  ];

  static const List<(String, String)> _releases = [
    ('Low Tide', 'Saltwater'),
    ('Signals', 'Mono Lake'),
    ('Fever Dream', 'Palms'),
    ('Satellites', 'Echo Park'),
    ('Velvet', 'Rosa'),
    ('Northern Lights', 'Aurora Bay'),
  ];

  Widget _sectionHeader(String title, Color ink, {bool more = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          if (more) ...[
            const SizedBox(width: 4),
            _sf('chevron.right', 15, ink.withValues(alpha: 0.45)),
          ],
        ],
      ),
    );
  }

  /// A horizontal row of square covers with a title and artist under each.
  Widget _albumRow(List<(String, String)> albums, int seed, Color ink) {
    const double size = 170;
    return SizedBox(
      height: size + 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (String title, String artist) = albums[i];
          return SizedBox(
            width: size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: _Artwork(
                    colors: _covers[(i + seed) % _covers.length],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, fontSize: 13),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The tall "Top Picks" cards: a kicker above, the cover filling the
  /// card, the mix's name on a band of its colour.
  Widget _picksRow(Color ink) {
    const double width = 250;
    const double height = 330;
    return SizedBox(
      height: height + 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (String kicker, String title) = _picks[i];
          final List<Color> colors = _covers[(i * 3) % _covers.length];
          return SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: width,
                  height: height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Expanded(
                          child: _Artwork(colors: colors, radius: 0),
                        ),
                        Container(
                          width: width,
                          height: 84,
                          color: Color.lerp(colors.last, Colors.black, 0.35),
                          padding: const EdgeInsets.all(14),
                          alignment: Alignment.topLeft,
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final MediaQueryData mq = MediaQuery.of(context);
    final Color ink = dark ? Colors.white : Colors.black;
    final LiquidGlassStyle glass =
        dark ? LiquidGlassTabBar.defaultDarkStyle : LiquidGlassTabBar.defaultStyle;
    final double barWidth =
        mq.size.width - 2 * _edge - _barHeight - 12; // room for search
    // On the home indicator's inset, as iOS sits it, never on the edge.
    final double barBottom = math.max(mq.padding.bottom, _minBottom);

    final LiquidGlassTabBar bar = LiquidGlassTabBar(
      items: _tabs,
      selectedIndex: _tab,
      onChanged: (i) => setState(() => _tab = i),
      width: barWidth,
      // Left-anchored: the right end of the line is search's.
      alignment: Alignment.bottomLeft,
      // The bar adds the inset itself; this is what it lacks of the gap.
      margin: EdgeInsets.only(
        left: _edge,
        bottom: barBottom - mq.padding.bottom,
      ),
      itemStyle: const LiquidGlassTabItemStyle(selectedColor: _accent),
    );

    final Widget page = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, mq.padding.top + 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _titles[_tab],
                    style: TextStyle(
                      color: ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                // The profile picture.
                _sf(
                  'person.crop.circle.fill',
                  34,
                  ink.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _sectionHeader('Top Picks for You', ink, more: false),
        ),
        SliverToBoxAdapter(child: _picksRow(ink)),
        SliverToBoxAdapter(child: _sectionHeader('Recently Played', ink)),
        SliverToBoxAdapter(child: _albumRow(_recent, 1, ink)),
        SliverToBoxAdapter(child: _sectionHeader('New Releases', ink)),
        SliverToBoxAdapter(child: _albumRow(_releases, 4, ink)),
        SliverToBoxAdapter(
          child: _sectionHeader('Made for You', ink),
        ),
        SliverToBoxAdapter(child: _albumRow(_recent.reversed.toList(), 6, ink)),
        // Clear of the mini player and the bar.
        SliverToBoxAdapter(
          child: SizedBox(
            height: barBottom + _barHeight + _playerHeight + 40,
          ),
        ),
      ],
    );

    return LiquidGlassView(
      backgroundWidget: ColoredBox(
        color: dark ? Colors.black : Colors.white,
        child: Material(type: MaterialType.transparency, child: page),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The mini player, floating above the bar on its own glass.
            Positioned(
              left: _edge,
              right: _edge,
              bottom: barBottom + _barHeight + 8,
              height: _playerHeight,
              child: LiquidGlassLens(
                style: glass,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                  child: Row(
                    children: [
                      const AspectRatio(
                        aspectRatio: 1,
                        child: _Artwork(
                          colors: [Color(0xFFFF375F), Color(0xFFFF9F0A)],
                          radius: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Midnight Drive',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _sf('play.fill', 20, ink),
                      const SizedBox(width: 22),
                      _sf('forward.fill', 22, ink),
                    ],
                  ),
                ),
              ),
            ),
            // One material for the capsule and the circle: the bar's own.
            LiquidGlassBlender(
              smoothness: _smoothness,
              style: glass,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // With a live backdrop the bar is a full-screen overlay
                  // that places itself; otherwise it is the bare capsule.
                  if (ui.ImageFilter.isShaderFilterSupported)
                    bar
                  else
                    Positioned(
                      left: _edge,
                      bottom: barBottom,
                      child: bar,
                    ),
                  Positioned(
                    right: _edge,
                    bottom: barBottom,
                    child: LiquidGlassTabBarAction(
                      size: _barHeight,
                      onTap: () {},
                      child: _sf('magnifyingglass', 24, ink),
                    ),
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
