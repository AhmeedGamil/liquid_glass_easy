import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppStorePage(),
    ));

/// An App Store-style screen: a column of feature cards under the
/// package's tab bar on its defaults, with five SF Symbols tabs.
class AppStorePage extends StatefulWidget {
  const AppStorePage({super.key});

  @override
  State<AppStorePage> createState() => _AppStorePageState();
}

/// A tab drawn from an SF Symbols SVG in `assets/sf/`, in the colour the
/// bar resolves for it.
LiquidGlassTabBarItem _sfTab(String symbol, String label) =>
    LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, g) => SvgPicture.asset(
        'assets/sf/$symbol.svg',
        width: g.size,
        height: g.size,
        colorFilter: ColorFilter.mode(g.color, BlendMode.srcIn),
      ),
    );

class _AppStorePageState extends State<AppStorePage> {
  int _tab = 0;

  static final List<LiquidGlassTabBarItem> _tabs = [
    _sfTab('text.below.photo.fill', 'Today'),
    _sfTab('gamecontroller.fill', 'Games'),
    _sfTab('square.stack.3d.up.fill', 'Apps'),
    _sfTab('arcade.stick.console.fill', 'Arcade'),
    _sfTab('magnifyingglass', 'Search'),
  ];

  static const List<(String, String, List<Color>)> _cards = [
    ('APP OF THE DAY', 'Sketch your world', [Color(0xFFFF9F0A), Color(0xFFFF375F)]),
    ('GAME OF THE DAY', 'Into the deep', [Color(0xFF0A84FF), Color(0xFF30D158)]),
    ('OUR FAVOURITES', 'Top apps this week', [Color(0xFFBF5AF2), Color(0xFF5E5CE6)]),
    ('NOW AVAILABLE', 'Race the night', [Color(0xFF1C1C1E), Color(0xFF636366)]),
    ('MEET THE DEVELOPER', 'Small studio, big ideas', [Color(0xFF64D2FF), Color(0xFF0A84FF)]),
  ];

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final MediaQueryData mq = MediaQuery.of(context);
    final Color ink = dark ? Colors.white : Colors.black;
    return LiquidGlassScaffold(
      backgroundColor: dark ? Colors.black : const Color(0xFFF2F2F7),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, mq.padding.top + 16, 20, 140),
        children: [
          Text(
            'FRIDAY 31 OCTOBER',
            style: TextStyle(
              color: ink.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Today',
            style: TextStyle(
              color: ink,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (final (String kicker, String title, List<Color> colors)
              in _cards)
            Container(
              height: 380,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kicker,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        items: _tabs,
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
        width: (mq.size.width - 24).clamp(0.0, 400.0),
      ),
    );
  }
}
