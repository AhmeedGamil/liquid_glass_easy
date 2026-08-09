import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../glass_ui.dart';

/// **Bottom nav bar** — the bar itself, and its two selection tiers.
///
/// [LiquidGlassBottomNavBar] is the bar; [LiquidGlassScaffold] is what feeds
/// it a page to refract. That pairing is the normal one and it is what runs
/// here — a small static page in the scaffold's body, so the only thing
/// changing on screen is the bar.
///
/// ## The two tiers
///
/// * **highlight** — `pillStyle.mode: none`. One lens for the whole bar and a
///   translucent capsule that jumps to the selected tab, or slides there with
///   `animated: true`. Cheap everywhere.
/// * **glass pill** — `mode: both`. The selection becomes a second refracting
///   surface that morphs between tabs, bending the bar itself. It is a whole
///   second pipeline: on Impeller free, on Skia a second full capture, which
///   is why `impellerOnly` exists — the pill where it costs nothing, the
///   highlight everywhere else.
///
/// Switch between them below and watch what the selection does to the icons
/// underneath it.
class NavBarDemo extends StatefulWidget {
  const NavBarDemo({super.key});

  @override
  State<NavBarDemo> createState() => _NavBarDemoState();
}

enum _Tier {
  instant('instant'),
  sliding('sliding'),
  glassPill('glass pill');

  const _Tier(this.label);
  final String label;
}

class _NavBarDemoState extends State<NavBarDemo> {
  int _index = 0;
  _Tier _tier = _Tier.sliding;

  static const _items = [
    LiquidGlassTabBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.favorite_outline_rounded,
      selectedIcon: Icons.favorite_rounded,
      label: 'Likes',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'You',
    ),
  ];

  LiquidGlassNavPillStyle get _pillStyle => switch (_tier) {
        _Tier.instant => const LiquidGlassNavPillStyle(),
        _Tier.sliding => const LiquidGlassNavPillStyle(animated: true),
        // The dual-pipeline pill: a refracting surface of its own.
        _Tier.glassPill => const LiquidGlassNavPillStyle(
            mode: LiquidGlassPillMode.both,
            animated: true,
          ),
      };

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      pixelRatio: 1,
      body: _Body(
        index: _index,
        label: _items[_index].label ?? '',
        tier: _tier,
        onTier: (t) => setState(() => _tier = t),
      ),
      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        width: 310,
        margin: const EdgeInsets.only(bottom: 22),
        pillStyle: _pillStyle,
      ),
    );
  }
}

/// The scaffold's body — what the bar is refracting. Bands of colour and a
/// grid of hairlines, because a straight edge under glass is the only honest
/// way to see the bend.
class _Body extends StatelessWidget {
  final int index;
  final String label;
  final _Tier tier;
  final ValueChanged<_Tier> onTier;

  const _Body({
    required this.index,
    required this.label,
    required this.tier,
    required this.onTier,
  });

  static const List<Color> _accents = [
    Color(0xFF7C5CFF),
    Color(0xFF2DD4BF),
    Color(0xFFFF5C8A),
    Color(0xFFFFB020),
  ];

  @override
  Widget build(BuildContext context) {
    final Color accent = _accents[index % _accents.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.55),
            const Color(0xFF120B24),
            accent.withValues(alpha: 0.28),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAB ${index + 1}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              // Hairlines: the bar's refraction is visible as these bow.
              Expanded(
                child: CustomPaint(
                  painter: const _Rules(),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 12),
              const DemoHint('Switch the selection tier, then change tabs'),
              const SizedBox(height: 10),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final t in _Tier.values)
                      DemoChip(
                        label: t.label,
                        selected: tier == t,
                        onTap: () => onTier(t),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rules extends CustomPainter {
  const _Rules();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Rules oldDelegate) => false;
}
