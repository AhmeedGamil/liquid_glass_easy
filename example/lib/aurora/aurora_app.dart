import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'pages/coach_page.dart';
import 'pages/insights_page.dart';
import 'pages/sessions_page.dart';
import 'pages/settings_page.dart';
import 'pages/today_page.dart';
import 'theme/aurora_palette.dart';
import 'theme/aurora_theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/aurora_motion.dart';

/// Aurora — a calm-tracking app, and the package's home turf.
///
/// The glass is deliberately rationed: the tab bar is glass on every
/// page, and each page is allowed exactly one glass control of its own.
/// Everything else is a frosted plate over the drifting field.
class AuroraApp extends StatefulWidget {
  const AuroraApp({super.key});

  @override
  State<AuroraApp> createState() => _AuroraAppState();
}

class _AuroraAppState extends State<AuroraApp> {
  final AuroraController _controller = AuroraController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onSettingsChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _controller.accent;
    return MaterialApp(
      title: 'Aurora',
      debugShowCheckedModeBanner: false,
      themeMode: _controller.mode,
      theme: auroraThemeData(AuroraPalette.light(accent)),
      darkTheme: auroraThemeData(AuroraPalette.dark(accent)),
      // The palette is resolved HERE, below the theme and above the
      // navigator: `system` mode means only Flutter knows which side we
      // landed on, and pushed routes have to inherit the same answer.
      builder: (context, child) => AuroraTheme(
        palette: AuroraPalette.resolve(Theme.of(context).brightness, accent),
        controller: _controller,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuroraShell(),
    );
  }
}

/// The five tabs, the glass bar that switches them, and the one drifting
/// background they all sit on.
class AuroraShell extends StatefulWidget {
  const AuroraShell({super.key});

  @override
  State<AuroraShell> createState() => _AuroraShellState();
}

class _AuroraShellState extends State<AuroraShell> {
  int _index = 0;
  int _previous = 0;

  /// The background lags the content by a fraction of this. Kept in a
  /// notifier so a scroll repaints the field WITHOUT rebuilding the page.
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);

  static const List<LiquidGlassTabBarItem> _items = [
    LiquidGlassTabBarItem(
      icon: Icons.wb_twilight_outlined,
      selectedIcon: Icons.wb_twilight_rounded,
      label: 'Today',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.self_improvement_outlined,
      selectedIcon: Icons.self_improvement_rounded,
      label: 'Sessions',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Insights',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      label: 'Coach',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
      label: 'You',
    ),
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _previous = _index;
      _index = i;
      // A new page starts at the top; carrying the old offset would snap
      // the field sideways on every tab change.
      _scroll.value = 0;
    });
  }

  Widget _page() => switch (_index) {
        0 => const TodayPage(),
        1 => const SessionsPage(),
        2 => const InsightsPage(),
        3 => const CoachPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // A transparent Material under every page: text fields and ink want a
    // Material ancestor, and LiquidGlassScaffold does not paint one.
    final pages = Material(
      type: MaterialType.transparency,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.depth == 0) {
            _scroll.value = n.metrics.pixels;
          }
          return false;
        },
        child: DirectionalSwitcher(
          index: _index,
          previousIndex: _previous,
          child: _page(),
        ),
      ),
    );

    return LiquidGlassScaffold(
      pixelRatio: 1,
      body: ValueListenableBuilder<double>(
        valueListenable: _scroll,
        builder: (context, offset, child) => AuroraBackground(
          parallax: offset,
          // The coach thread is dense with text; pull the field back so
          // the bubbles keep their contrast.
          intensity: _index == 3 ? 0.72 : 1,
          child: child,
        ),
        child: pages,
      ),
      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: _select,
        width: 340,
        // 5 items with icon + label: the cell is `height - 2·itemPadding`,
        // and 66 leaves the label 2px short of its own descender.
        height: 70,
        margin: const EdgeInsets.only(bottom: 22),
        style: p.glass(
          radius: 35,
          blur: 3,
          distortion: 0.09,
          lightDirection: 39,
        ),
        pillStyle: LiquidGlassNavPillStyle(
          color: p.accent.withValues(alpha: p.isDark ? 0.30 : 0.24),
        ),
        itemStyle: LiquidGlassNavItemStyle(
          selectedColor: p.textPrimary,
          unselectedColor: p.textSecondary,
        ),
      ),
    );
  }
}
