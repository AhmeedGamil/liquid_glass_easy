import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MusicPage(),
    ));

/// A Music-style screen: a grid of album tiles under the package's tab
/// bar on its defaults, four SF Symbols tabs, and search on a glass circle
/// beside it. The bar's capsule and the circle share one blender, so they
/// flow together; the bar's moving glass pill stays out of it.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

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

class _MusicPageState extends State<MusicPage> {
  int _tab = 0;

  static const double _edge = 16;
  static const double _barHeight = 62;
  static const double _bottom = 24;

  static final List<LiquidGlassTabBarItem> _tabs = [
    _sfTab('house.fill', 'Home'),
    _sfTab('square.grid.2x2.fill', 'New'),
    _sfTab('dot.radiowaves.left.and.right', 'Radio'),
    _sfTab('play.square.stack.fill', 'Library'),
  ];

  static const List<List<Color>> _albums = [
    [Color(0xFFFF375F), Color(0xFFFF9F0A)],
    [Color(0xFF5E5CE6), Color(0xFF64D2FF)],
    [Color(0xFF30D158), Color(0xFF0A84FF)],
    [Color(0xFFBF5AF2), Color(0xFFFF375F)],
    [Color(0xFFFFD60A), Color(0xFFFF9F0A)],
    [Color(0xFF1C1C1E), Color(0xFF8E8E93)],
  ];

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final MediaQueryData mq = MediaQuery.of(context);
    final Color ink = dark ? Colors.white : Colors.black;
    final double barWidth =
        mq.size.width - 2 * _edge - _barHeight - 12; // room for search
    final LiquidGlassTabBar bar = LiquidGlassTabBar(
      items: _tabs,
      selectedIndex: _tab,
      onChanged: (i) => setState(() => _tab = i),
      width: barWidth,
      // Left-anchored: the right end of the line is search's.
      alignment: Alignment.bottomLeft,
      margin: const EdgeInsets.only(left: _edge, bottom: _bottom),
    );
    return LiquidGlassView(
      backgroundWidget: ColoredBox(
        color: dark ? Colors.black : Colors.white,
        child: Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, mq.padding.top + 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Home',
                    style: TextStyle(
                      color: ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                sliver: SliverGrid.builder(
                  itemCount: 24,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, i) {
                    final List<Color> c = _albums[i % _albums.length];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: c,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Album ${i + 1}',
                          maxLines: 1,
                          style: TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Artist',
                          maxLines: 1,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        // One material for the capsule and the circle: the bar's own.
        child: LiquidGlassBlender(
          style: dark
              ? LiquidGlassTabBar.defaultDarkStyle
              : LiquidGlassTabBar.defaultStyle,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // With a live backdrop the bar is a full-screen overlay that
              // places itself; otherwise it is the bare capsule.
              if (ui.ImageFilter.isShaderFilterSupported)
                bar
              else
                Positioned(
                  left: _edge,
                  bottom: mq.padding.bottom + _bottom,
                  child: bar,
                ),
              Positioned(
                right: _edge,
                bottom: mq.padding.bottom + _bottom,
                child: LiquidGlassTabBarAction(
                  size: _barHeight,
                  onTap: () {},
                  touch: const LiquidGlassTouch.flexing(
                    LiquidGlassFlex.subtle(),
                  ),
                  child: _sf('magnifyingglass', 26, ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
