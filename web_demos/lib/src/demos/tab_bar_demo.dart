import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Tab bar** — a glass capsule of tabs over your own page.
///
/// [LiquidGlassTabBar] is the bar without a scaffold: you place it, you keep
/// the index, you decide what the page does with it. Like the app bar it is a
/// single lens, so on Skia and the web it wants an ancestor
/// [LiquidGlassView] whose background is the page it should refract.
///
/// ## The selection pill is not the morph pill
///
/// `showSelectionPill` draws a plain translucent capsule behind the selected
/// tab — one lens, no second pipeline. That is the difference from
/// [LiquidGlassBottomNavBar]'s glass morph pill, which is a whole extra
/// refracting surface and costs a second capture on Skia.
///
/// ## Custom glyphs
///
/// `LiquidGlassTabBarItem.custom` hands a builder the colour the bar resolved,
/// the glyph box size and whether this layer is the selected one — so an SVG
/// or a `CustomPaint` follows the palette exactly like an `IconData` would.
/// The last tab here is drawn that way.
class TabBarDemo extends StatefulWidget {
  const TabBarDemo({super.key});

  @override
  State<TabBarDemo> createState() => _TabBarDemoState();
}

class _TabBarDemoState extends State<TabBarDemo> {
  int _index = 0;
  bool _pill = true;

  static const List<(String, Color)> _pages = [
    ('Today', Color(0xFF7C5CFF)),
    ('Charts', Color(0xFF2DD4BF)),
    ('Radio', Color(0xFFFFB020)),
    ('You', Color(0xFFFF5C8A)),
  ];

  List<LiquidGlassTabBarItem> get _items => [
        const LiquidGlassTabBarItem(
          icon: Icons.today_outlined,
          selectedIcon: Icons.today_rounded,
          label: 'Today',
        ),
        const LiquidGlassTabBarItem(
          icon: Icons.bar_chart_rounded,
          label: 'Charts',
        ),
        const LiquidGlassTabBarItem(
          icon: Icons.radio_outlined,
          selectedIcon: Icons.radio_rounded,
          label: 'Radio',
        ),
        // Drawn by a builder rather than an IconData: the ring follows the
        // colour the bar already resolved for this layer.
        LiquidGlassTabBarItem.custom(
          label: 'You',
          iconBuilder: (context, g) => Container(
            width: g.size,
            height: g.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: g.color, width: g.selected ? 2.4 : 1.4),
            ),
            child: Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: g.color,
                  fontSize: g.size * 0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final (title, accent) = _pages[_index];

    return LiquidGlassView(
      pixelRatio: 1,
      // The page changes with the tab, so the capture has to keep up.
      backgroundWidget: _Page(title: title, accent: accent),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DemoHint('Switch tabs — the bar refracts the page it '
                      'is sitting on'),
                  const SizedBox(height: 10),
                  DemoChip(
                    label: 'selection pill',
                    selected: _pill,
                    onTap: () => setState(() => _pill = !_pill),
                  ),
                  const SizedBox(height: 14),
                  LiquidGlassTabBar(
                    items: _items,
                    selectedIndex: _index,
                    onChanged: (i) => setState(() => _index = i),
                    width: 330,
                    showSelectionPill: _pill,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The page behind the bar. One big number and a grid, so there is structure
/// for the glass to bend rather than a flat wash.
class _Page extends StatelessWidget {
  final String title;
  final Color accent;

  const _Page({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackdrop.ember(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      for (int i = 0; i < 6; i++)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13 + i * 0.045),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
