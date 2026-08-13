import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'nav_bar_tuning.dart';
import 'tuning_store.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/scaffold_demo.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const ScaffoldDemo(),
    ),
  );
}

/// A polished, app-store-quality showcase of [LiquidGlassScaffold]: a rich,
/// colorful "Aurora" music feed scrolls behind a floating glass bottom nav
/// bar — no app bar, just content + glass.
///
/// The vivid gradients, glows and artwork in the body are deliberate: they
/// are the background every glass surface refracts, so the floating nav bar
/// picks up real colour as you scroll.
class ScaffoldDemo extends StatefulWidget {
  const ScaffoldDemo({super.key});

  @override
  State<ScaffoldDemo> createState() => _ScaffoldDemoState();
}

class _ScaffoldDemoState extends State<ScaffoldDemo> {
  int _index = 0;

  // The nav bar reads its motion / travel / grow / background / light
  // direction live from the shared store (tuned in the Nav Motion Tuner).
  // Rebuild whenever those change — the bar widget must be reconstructed
  // (not wrapped in a builder) so LiquidGlassScaffold re-detects the
  // glass-pill bar.
  ValueNotifier<NavTuning> get _navTuning => TuningStore.instance.nav;

  @override
  void initState() {
    super.initState();
    _navTuning.addListener(_onTuningChanged);
  }

  @override
  void dispose() {
    _navTuning.removeListener(_onTuningChanged);
    super.dispose();
  }

  void _onTuningChanged() {
    if (mounted) setState(() {});
  }

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
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
      label: 'Search',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.favorite_outline_rounded,
      selectedIcon: Icons.favorite_rounded,
      label: 'You',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  /// Per-tab accent — recolours the whole page so switching tabs feels alive
  /// and the refracting glass picks up a different hue.
  static const _accents = [
    Color(0xFF7C5CFF), // Home    — violet
    Color(0xFFFF5C8A), // Explore — pink
    Color(0xFF4FB3FF), // Search  — blue
    Color(0xFF2DD4BF), // You     — teal
    Color(0xFFFFB020), // Profile — amber
  ];

  static const _overlines = ['TUESDAY · JUNE 16', 'TRENDING NOW', 'BROWSE ALL', 'YOUR LIBRARY', 'YOUR ACCOUNT'];
  static const _greetings = ['Good evening', 'Discover', 'Search', 'Your music', 'Profile'];

  Color get _accent => _accents[_index];

  @override
  Widget build(BuildContext context) {
    final navTuning = _navTuning.value;
    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,

      // ── the colourful feed = the captured, refracted background ──
      // Every tab shows the SAME feed page (only the accent/theme shifts),
      // so tapping a tab moves the selection pill without navigating away.
      body: AuroraFeed(
        accent: _accent,
        overline: _overlines[_index],
        greeting: _greetings[_index],
      ),

      // ── floating glass bottom nav bar (no app bar) ──────────────
      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        alignment: Alignment.bottomCenter,
        // Centered bar — only the bottom gap matters (symmetric side insets
        // are a no-op on a fixed-width centered bar).
        margin: const EdgeInsets.only(bottom: 24),
        // Bar look + pill motion come from the shared store, so the values
        // dialled in the Nav Motion Tuner show up here for the GIF. Default
        // is a dark frost with light direction 39.
        style: navBarStyle(navTuning),
        pillStyle: navPillStyle(navTuning),
        width: 320,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The beautiful scrolling feed.
// ════════════════════════════════════════════════════════════════

/// The colourful "Aurora" music feed used by [ScaffoldDemo] — exposed so
/// other demos can reuse the EXACT same scrolling background. Pass a
/// [controller] to drive behaviour off its scroll position.
class AuroraFeed extends StatelessWidget {
  const AuroraFeed({
    super.key,
    required this.accent,
    required this.overline,
    required this.greeting,
    this.controller,
  });

  final Color accent;
  final String overline;
  final String greeting;

  /// Optional scroll controller for the feed's `ListView`.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    // A transparent Material gives the feed's Text widgets a Material
    // ancestor (no yellow debug underlines) without painting a background.
    return Material(
      type: MaterialType.transparency,
      child: _content(),
    );
  }

  Widget _content() {
    return Stack(
      children: [
        // Deep space base gradient.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF14101F), Color(0xFF0B0A12), Color(0xFF050509)],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        ),
        // Two soft accent glows so the glass has real colour to bend.
        Positioned(
          top: -120,
          right: -90,
          child: _Glow(color: accent, size: 360),
        ),
        Positioned(
          top: 280,
          left: -120,
          child: _Glow(color: accent.withValues(alpha: 0.7), size: 300),
        ),

        // The scrolling content.
        ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 150),
          children: [
            _header(),
            const SizedBox(height: 28),
            _hero(),
            const SizedBox(height: 32),
            _sectionTitle('Trending now', 'See all'),
            const SizedBox(height: 16),
            _trendingRow(),
            const SizedBox(height: 32),
            _sectionTitle('Made for you', null),
            const SizedBox(height: 16),
            for (int i = 0; i < _madeForYou.length; i++) ...[
              _listRow(_madeForYou[i], i),
              if (i != _madeForYou.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 28),
            _promoBanner(),
          ],
        ),
      ],
    );
  }

  // ── header: overline + big greeting + avatar ──────────────────
  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                greeting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            image: const DecorationImage(
              image: NetworkImage('https://picsum.photos/seed/avatar/120/120'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  // ── hero "featured" card with artwork + scrim + play CTA ───────
  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Image.network(
            'https://picsum.photos/seed/aurora/900/640',
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    accent.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 20,
            child: _pill('FEATURED', accent),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Midnight Aurora',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lo-fi · 48 tracks · 2h 51m',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── horizontal "trending" carousel ────────────────────────────
  Widget _trendingRow() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: _trending.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => _trendingCard(_trending[i], i),
      ),
    );
  }

  Widget _trendingCard(_Card c, int i) {
    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.network(
                  'https://picsum.photos/seed/${c.seed}/320/320',
                  height: 156,
                  width: 156,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            c.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── vertical "made for you" list rows ─────────────────────────
  Widget _listRow(_Card c, int i) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://picsum.photos/seed/${c.seed}/120/120',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  c.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.play_circle_fill_rounded, color: accent, size: 34),
        ],
      ),
    );
  }

  // ── colourful promo banner at the bottom ──────────────────────
  Widget _promoBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.55), const Color(0xFF1A1430)],
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Go Premium',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lossless audio, no ads,\noffline everywhere.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.3),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Try free',
              style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── small shared bits ─────────────────────────────────────────
  Widget _sectionTitle(String title, String? action) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        const Spacer(),
        if (action != null)
          Text(
            action,
            style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
      ),
    );
  }

  static const _trending = [
    _Card('Neon Dreams', 'Synthwave', 'a'),
    _Card('Deep Focus', 'Ambient', 'b'),
    _Card('Sunset Drive', 'Chillhop', 'c'),
    _Card('Rainy Days', 'Lo-fi', 'd'),
    _Card('City Lights', 'Electronic', 'e'),
  ];

  static const _madeForYou = [
    _Card('Daily Mix 1', 'Based on your evenings', 'f'),
    _Card('On Repeat', '32 songs you love', 'g'),
    _Card('Discover Weekly', 'Fresh picks every Monday', 'h'),
    _Card('Chill Vibes', 'Wind-down essentials', 'i'),
  ];
}

/// A soft radial colour glow painted behind the feed so glass has real
/// colour to refract.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.45), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _Card {
  const _Card(this.title, this.subtitle, this.seed);
  final String title;
  final String subtitle;
  final String seed;
}
