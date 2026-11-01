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
/// artwork, artists and stations, a mini player floating above the tab
/// bar, and the tab bar with search on a glass circle beside it.
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

// ---------------------------------------------------------------------------
// Artwork.
// ---------------------------------------------------------------------------

/// How a cover is drawn.
enum _Look { glow, rings, stripes, waves, type, photo }

/// One album, mix, artist or station: its look, colours and words.
class _Art {
  const _Art(
    this.look,
    this.colors, {
    this.title = '',
    this.subtitle = '',
    this.photo,
    this.mark,
  });

  final _Look look;
  final List<Color> colors;
  final String title;
  final String subtitle;

  /// For [_Look.photo]: the image under the tint.
  final String? photo;

  /// For [_Look.type]: the word set large on the cover.
  final String? mark;
}

/// A cover: one of the [_Look]s, rounded to [radius].
class _Cover extends StatelessWidget {
  const _Cover(this.art, {this.radius = 8});

  final _Art art;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final List<Color> c = art.colors;
    Widget body;
    switch (art.look) {
      case _Look.photo:
        body = Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(art.photo!, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.first.withValues(alpha: 0.15),
                    c.last.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ],
        );
      case _Look.type:
        body = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Padding(
              padding: EdgeInsets.all(box.maxWidth * 0.08),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  art.mark ?? art.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: box.maxWidth * 0.2,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -box.maxWidth * 0.008,
                  ),
                ),
              ),
            ),
          ),
        );
      default:
        body = CustomPaint(painter: _CoverPainter(art.look, c));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: body,
    );
  }
}

/// Paints the generative [_Look]s.
class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.look, this.colors);

  final _Look look;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final double w = size.width;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.first, colors.last],
        ).createShader(r),
    );
    switch (look) {
      case _Look.glow:
        // Soft blobs of light drifting over the base.
        final List<(Offset, double, Color)> blobs = [
          (Offset(w * 0.25, w * 0.3), w * 0.42, colors[1]),
          (Offset(w * 0.8, w * 0.65), w * 0.38, colors[2 % colors.length]),
          (Offset(w * 0.4, w * 0.95), w * 0.3, Colors.white),
        ];
        for (final (Offset o, double rad, Color col) in blobs) {
          canvas.drawCircle(
            o,
            rad,
            Paint()
              ..color = col.withValues(alpha: 0.75)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
          );
        }
      case _Look.rings:
        final Paint ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..color = Colors.white.withValues(alpha: 0.55);
        final Offset c = Offset(w * 0.62, w * 0.42);
        for (int i = 1; i <= 7; i++) {
          canvas.drawCircle(c, w * 0.075 * i, ring);
        }
        canvas.drawCircle(
            c, w * 0.05, Paint()..color = colors[1 % colors.length]);
      case _Look.stripes:
        canvas.save();
        canvas.clipRect(r);
        canvas.rotate(-math.pi / 5);
        final Paint band = Paint();
        for (int i = -8; i < 12; i++) {
          band.color = (i.isEven ? Colors.white : colors[1 % colors.length])
              .withValues(alpha: i.isEven ? 0.18 : 0.55);
          canvas.drawRect(
              Rect.fromLTWH(-w, i * w * 0.12, w * 3, w * 0.06), band);
        }
        canvas.restore();
      case _Look.waves:
        final Paint line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02
          ..strokeCap = StrokeCap.round;
        for (int k = 0; k < 9; k++) {
          final Path p = Path();
          final double y0 = w * (0.18 + k * 0.085);
          for (double x = 0; x <= w; x += w / 40) {
            final double y = y0 +
                math.sin(x / w * math.pi * 2 + k * 0.6) * w * 0.05 * (1 + k / 6);
            x == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
          }
          line.color =
              Color.lerp(Colors.white, colors[1 % colors.length], k / 8)!
                  .withValues(alpha: 0.8);
          canvas.drawPath(p, line);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.look != look || old.colors != colors;
}

// ---------------------------------------------------------------------------
// Content.
// ---------------------------------------------------------------------------

const String _flower = 'assets/feed/flower.jpg';
const String _mountain = 'assets/feed/mountain.jpg';

const List<_Art> _topPicks = [
  _Art(_Look.glow, [Color(0xFF3A0CA3), Color(0xFFF72585), Color(0xFF4CC9F0)],
      title: 'Favourites Mix', subtitle: 'Made for You'),
  _Art(_Look.photo, [Color(0xFFFF9F0A), Color(0xFF8A1C00)],
      title: 'New Music Mix', subtitle: 'Made for You', photo: _flower),
  _Art(_Look.waves, [Color(0xFF0B3D91), Color(0xFF64D2FF)],
      title: 'Chill Mix', subtitle: 'Featuring Lumen, Juniper and more'),
  _Art(_Look.photo, [Color(0xFF5E5CE6), Color(0xFF101030)],
      title: 'Get Up! Mix', subtitle: 'Made for You', photo: _mountain),
];

const List<_Art> _recent = [
  _Art(_Look.type, [Color(0xFFFF375F), Color(0xFFFF9F0A)],
      title: 'Midnight Drive', subtitle: 'The Weekends', mark: 'MID\nNIGHT'),
  _Art(_Look.rings, [Color(0xFF1C1C1E), Color(0xFFFFD60A)],
      title: 'Golden Hour', subtitle: 'Lumen'),
  _Art(_Look.photo, [Color(0xFF64D2FF), Color(0xFF003049)],
      title: 'Ocean Eyes', subtitle: 'Blue Haze', photo: _mountain),
  _Art(_Look.stripes, [Color(0xFF30D158), Color(0xFF0A3D1F)],
      title: 'Paper Planes', subtitle: 'Northbound'),
  _Art(_Look.glow, [Color(0xFF240046), Color(0xFFFF6D00), Color(0xFFFFD60A)],
      title: 'Afterglow', subtitle: 'Neon Coast'),
  _Art(_Look.photo, [Color(0xFFFFB3C6), Color(0xFF7A0035)],
      title: 'Wildflowers', subtitle: 'Juniper', photo: _flower),
];

const List<_Art> _releases = [
  _Art(_Look.waves, [Color(0xFF14213D), Color(0xFFFCA311)],
      title: 'Low Tide', subtitle: 'Saltwater'),
  _Art(_Look.type, [Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
      title: 'Signals', subtitle: 'Mono Lake', mark: 'SIG\nNALS'),
  _Art(_Look.glow, [Color(0xFF00171F), Color(0xFF00A8E8), Color(0xFF7AE582)],
      title: 'Fever Dream', subtitle: 'Palms'),
  _Art(_Look.rings, [Color(0xFFD00000), Color(0xFFFFBA08)],
      title: 'Satellites', subtitle: 'Echo Park'),
  _Art(_Look.stripes, [Color(0xFF6A040F), Color(0xFFFFB4A2)],
      title: 'Velvet', subtitle: 'Rosa'),
  _Art(_Look.photo, [Color(0xFF80FFDB), Color(0xFF023E8A)],
      title: 'Northern Lights', subtitle: 'Aurora Bay', photo: _mountain),
];

const List<_Art> _artists = [
  _Art(_Look.photo, [Color(0xFFFF9F0A), Color(0xFF8A1C00)],
      title: 'Lumen', photo: _flower),
  _Art(_Look.glow, [Color(0xFF10002B), Color(0xFFC77DFF), Color(0xFF4CC9F0)],
      title: 'Neon Coast'),
  _Art(_Look.photo, [Color(0xFF64D2FF), Color(0xFF003049)],
      title: 'Blue Haze', photo: _mountain),
  _Art(_Look.rings, [Color(0xFF1B4332), Color(0xFF95D5B2)],
      title: 'Juniper'),
  _Art(_Look.waves, [Color(0xFF370617), Color(0xFFF48C06)],
      title: 'The Weekends'),
];

const List<_Art> _stations = [
  _Art(_Look.glow, [Color(0xFFFA2D48), Color(0xFFFF9F0A), Color(0xFFFFD60A)],
      title: 'Music Live', subtitle: 'The new music that matters'),
  _Art(_Look.waves, [Color(0xFF240046), Color(0xFF9D4EDD)],
      title: 'Chill Station', subtitle: 'Based on Golden Hour'),
  _Art(_Look.stripes, [Color(0xFF003566), Color(0xFF00B4D8)],
      title: 'Indie Radio', subtitle: 'Fresh finds, all day'),
];

class _MusicPageState extends State<MusicPage> {
  int _tab = 0;

  /// How far the capsule and the search circle flow into each other.
  static const double _smoothness = 15;

  static const double _edge = 16;
  static const double _barHeight = 62;
  static const double _playerHeight = 48;

  /// The least gap under the bar, for screens that report no inset.
  static const double _minBottom = 12;

  static final List<LiquidGlassTabBarItem> _tabs = [
    _sfTab('house.fill', 'Home'),
    _sfTab('square.grid.2x2.fill', 'New'),
    _sfTab('dot.radiowaves.left.and.right', 'Radio'),
    _sfTab('play.square.stack.fill', 'Library'),
  ];

  static const List<String> _titles = ['Home', 'New', 'Radio', 'Library'];

  Widget _header(String title, Color ink, {bool more = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 12),
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

  /// A horizontal carousel of [count] items [itemWidth] wide.
  Widget _row({
    required double height,
    required double itemWidth,
    required int count,
    required Widget Function(int) item,
    double gap = 12,
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: (context, i) => SizedBox(width: itemWidth, child: item(i)),
      ),
    );
  }

  /// Square covers with a title and artist under each.
  Widget _albums(List<_Art> albums, Color ink) {
    const double size = 168;
    return _row(
      height: size + 46,
      itemWidth: size,
      count: albums.length,
      item: (i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(dimension: size, child: _Cover(albums[i])),
          const SizedBox(height: 6),
          Text(
            albums[i].title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ink, fontSize: 13),
          ),
          Text(
            albums[i].subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ink.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// The tall "Top Picks" cards: a kicker above, the cover filling the
  /// card, the mix's name on a band of its own colour.
  Widget _picks(Color ink) {
    const double width = 250;
    const double coverHeight = 250;
    return _row(
      height: coverHeight + 96 + 22,
      itemWidth: width,
      count: _topPicks.length,
      item: (i) {
        final _Art a = _topPicks[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  SizedBox(
                    width: width,
                    height: coverHeight,
                    child: _Cover(a, radius: 0),
                  ),
                  Container(
                    width: width,
                    height: 96,
                    color: Color.lerp(a.colors.last, Colors.black, 0.3),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updated Friday',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Round artist portraits with their names.
  Widget _artistRow(Color ink) {
    const double size = 120;
    return _row(
      height: size + 30,
      itemWidth: size,
      count: _artists.length,
      gap: 16,
      item: (i) => Column(
        children: [
          SizedBox.square(
            dimension: size,
            child: _Cover(_artists[i], radius: size / 2),
          ),
          const SizedBox(height: 8),
          Text(
            _artists[i].title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ink, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Wide station cards: the cover with its name and a live mark on it.
  Widget _stationRow() {
    const double width = 300;
    const double height = 170;
    return _row(
      height: height,
      itemWidth: width,
      count: _stations.length,
      item: (i) {
        final _Art a = _stations[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            _Cover(a, radius: 12),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sf('dot.radiowaves.left.and.right', 16, Colors.white),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    a.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
                const SizedBox.square(
                  dimension: 34,
                  child: _Cover(
                    _Art(_Look.photo, [Color(0x00000000), Color(0x22000000)],
                        photo: _flower),
                    radius: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _header('Top Picks for You', ink, more: false),
        ),
        SliverToBoxAdapter(child: _picks(ink)),
        SliverToBoxAdapter(child: _header('Recently Played', ink)),
        SliverToBoxAdapter(child: _albums(_recent, ink)),
        SliverToBoxAdapter(child: _header('Your Favourite Artists', ink)),
        SliverToBoxAdapter(child: _artistRow(ink)),
        SliverToBoxAdapter(child: _header('Stations for You', ink)),
        SliverToBoxAdapter(child: _stationRow()),
        SliverToBoxAdapter(child: _header('New Releases', ink)),
        SliverToBoxAdapter(child: _albums(_releases, ink)),
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
                      AspectRatio(
                        aspectRatio: 1,
                        child: _Cover(_recent[0], radius: 8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _recent[0].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _recent[0].subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ink.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
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
