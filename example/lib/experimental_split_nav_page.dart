import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/experimental/liquid_glass_animated_nav_bar_motion.dart';

import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/experimental_split_nav_page.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const ExperimentalSplitNavPage(),
    ),
  );
}

// =============================================================
// **Experimental.** `split_nav_page.dart`, running on the nav bar whose
// pill's JELLY has been replaced by the acceleration motion model —
// `LiquidGlassAnimatedNavBarMotion` (lib/experimental/), the copy of the
// shipped glass-pill engine. Nothing in lib/src is modified; everything
// the copy did not need to change is imported from it.
//
// Same split layout as the original, re-lit for a light page: the tabs
// in one frosted-white capsule held off the right edge, search on its own
// detached circle at the same baseline, and the red belonging to the
// selected STATE rather than to one tab.
//
// What changed is how the pill deforms while it travels. The jelly was a
// velocity-driven lean spring plus a direction-memory spring, pumped in
// tab fractions. The pill now runs the stretch slider's model: its drawn
// position is sampled every frame in pixels, differentiated twice, and
// the averaged ACCELERATION scales it oppositely on the two axes —
// stretching wide and flat as it launches off a tab, squashing narrow
// and tall as it brakes into the next, and sitting undeformed at
// constant speed. The model has no lean term at all.
//
// It is also drawn differently: the pill is a driven lens whose capsule
// is evaluated at its envelope size and stretched through the shader, so
// the end caps go elliptical instead of the capsule being re-rounded at
// every frame.
//
// Compare side by side with the original:
//   flutter run -t lib/split_nav_page.dart              (jelly)
//   flutter run -t lib/experimental_split_nav_page.dart (acceleration)
// =============================================================

/// The red the selected tab burns in — the one saturated colour on the
/// page, so it is also the colour the surrounding glass picks up.
const Color _kBrand = Color(0xFFFF3B30);

/// Type and hairlines on the light page — near-black rather than black,
/// so nothing on the page is a pure endpoint.
const Color _kInk = Color(0xFF121215);

/// The material both pieces of glass are cut from: a frosted white over
/// a soft optical rim. Shared by the capsule and the detached circle so
/// they read as the same material at two sizes.
LiquidGlassShape _glassShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.7,
      lightIntensity: 0.9,
      lightDirection: 62,
      borderType: const OpticalBorder(
        borderSaturation: 1.1,
        ambientIntensity: 0.85,
        borderSolidity: 0.95,
      ),
    );

LiquidGlassStyle _glassStyle(double cornerRadius) => LiquidGlassStyle(
      shape: _glassShape(cornerRadius),
      appearance: const LiquidGlassAppearance(
        // Thin enough that the page reads through it — the separation
        // comes from the page being greyer than the glass, not from the
        // glass being opaque.
        color: Color(0x8FFFFFFF),
        blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.06,
        distortionWidth: 26,
      ),
    );

class ExperimentalSplitNavPage extends StatefulWidget {
  const ExperimentalSplitNavPage({super.key});

  @override
  State<ExperimentalSplitNavPage> createState() =>
      _ExperimentalSplitNavPageState();
}

class _ExperimentalSplitNavPageState extends State<ExperimentalSplitNavPage> {
  int _index = 1;

  // Bar height and the action's diameter are the same number: the circle
  // is the capsule's end cap, moved away from it.
  static const double _barHeight = 60;
  static const double _edge = 16;
  static const double _gap = 10;
  static const double _bottom = 22;

  /// The glyph's size — and therefore `itemStyle.iconSize`, the box every
  /// glyph is fitted into.
  static const double _iconRest = 24;

  /// One tab. Every one of them goes through the glyph builder — not
  /// because the art is custom, but because a selected icon **blooms**,
  /// and the built-in [Icon] path has no shadow to give it.
  ///
  /// The builder never names a colour: it paints `i.color`, the colour
  /// the bar already resolved for the layer it is drawing. That is what
  /// makes the pill reveal work — the shell draws every tab twice per
  /// frame, once forced unselected outside the pill and once forced
  /// selected inside it, so the red is wiped on as the pill arrives
  /// instead of switching under it.
  static LiquidGlassTabBarItem _tab(IconData icon, String label) {
    return LiquidGlassTabBarItem.custom(
      label: label,
      iconBuilder: (context, i) => Icon(
        icon,
        size: _iconRest,
        color: i.color,
        shadows: i.selected
            ? [Shadow(color: i.color.withValues(alpha: 0.85), blurRadius: 14)]
            : null,
      ),
    );
  }

  // One icon per tab: no `selectedIcon` pair anywhere, so the art never
  // changes on selection — the pill and the colour carry the state.
  static final _items = <LiquidGlassTabBarItem>[
    _tab(Icons.home_rounded, 'Home'),
    _tab(Icons.grid_view_rounded, 'Browse'),
    _tab(Icons.podcasts_rounded, 'Radio'),
    _tab(Icons.library_music_outlined, 'Library'),
  ];

  static const _titles = ['For you', 'Browse', 'On air', 'Your library'];

  void _search() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Search — the detached action, not a tab'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The capsule takes the width the circle leaves it. Clamped so a
    // tablet does not stretch four tabs across the whole screen.
    final double screen = MediaQuery.sizeOf(context).width;
    final double barWidth =
        (screen - _edge * 2 - _barHeight - _gap).clamp(240.0, 420.0);
    final double bottom = _bottom + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: LiquidGlassAnimatedNavBarMotion(
        body: _OnAirFeed(title: _titles[_index]),
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        pixelRatio: 1,
        useSync: true,

        // ── the tab capsule, held off the right edge ───────────────
        layout: LiquidGlassBottomNavBarLayout(
          itemCount: _items.length,
          width: barWidth,
          height: _barHeight,
          bottomMargin: bottom,
          padding: 5,
          pillExtraHeight: 12,
        ),
        // Left-anchored: a centred bar would drift under the circle as
        // the screen widens.
        barPosition: LiquidGlassOffsetPosition(left: _edge, bottom: bottom),
        barShape: _glassShape(_barHeight / 2),
        barAppearance: const LiquidGlassAppearance(
          color: Color(0x8FFFFFFF),
          blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
        ),
        barRefraction: const LiquidGlassRefraction(
          distortion: 0.06,
          distortionWidth: 26,
        ),
        // Wider and softer than the default: a 340×60 capsule needs a
        // longer throw than a thumb before the drop reads as depth
        // rather than as a dark outline.
        barShadow: const LiquidGlassShadow(blur: 9, opacity: 0.13),
        itemStyle: const LiquidGlassNavItemStyle(
          // The one place the selected look is decided — icon, bloom and
          // label all read it, on every tab.
          selectedColor: _kBrand,
          unselectedColor: _kInk,
          iconSize: _iconRest,
          labelFontSize: 10,
          iconLabelGap: 2,
          selectedFontWeight: FontWeight.w700,
          unselectedFontWeight: FontWeight.w600,
        ),

        // ── the moving pill ────────────────────────────────────────
        // No tint of its own — over white glass a fill would only flatten
        // the capsule. It is pure refraction, as in the original.
        pillColor: Colors.transparent,
        pillGrowHeight: 9,pillShape: LiquidGlassShape(borderWidth: 0.5),
        pillRefraction: const LiquidGlassRefraction(
          distortion: 0.05,
          distortionWidth: 12,
          chromaticAberration: 0.0015,
          magnification: 1,
        ),
        // The squash/stretch replacing the jelly. ±12 % rather than the
        // slider thumb's ±30 %: this pill lives inside a 60 px capsule.
        motion: const LiquidGlassLensMotionSpec(maxDeviation: 0.12),
        // The pill's own contact, tucked in so the glass overhangs it —
        // it is only 76 px wide and a full-width halo reads as a glow.
        pillShadow: const LiquidGlassShadow(blur: 4, opacity: 0.16, inset: 2),
        // Where it comes to rest: a barely-there grey. The bar is thin
        // glass now, so the resting patch only has to hint at which tab
        // is selected — the red glyph is already saying it.
        restStyle: LiquidGlassStyle(
          shape: _glassShape(28),
          appearance: const LiquidGlassAppearance(color: Color(0x2EAEAEB2)),
        ),

        // ── search, on its own glass ───────────────────────────────
        // A lens in the outer view's `child:` slot, so the capture has to
        // keep running even when the pill is at rest.
        outerNeedsRealtime: true,
        outerChild: Stack(
          children: [
            Positioned(
              right: _edge,
              bottom: bottom,
              width: _barHeight,
              height: _barHeight,
              child: LiquidGlassLens(
                style: _glassStyle(_barHeight / 2),
                // A plain gesture, not an InkWell: the nearest Material
                // is the scaffold's, underneath the whole view, so a
                // splash would ripple somewhere behind the glass.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _search,
                  child: const Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: _kInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The page behind the glass — a red-lit radio station, so both
//  pieces of glass have real colour to bend. Copied verbatim from
//  split_nav_page.dart so the two read identically.
// ════════════════════════════════════════════════════════════════

class _OnAirFeed extends StatelessWidget {
  const _OnAirFeed({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // A soft grey, deliberately well below white: the bar
                  // is thin glass, so it can only read as a lifted
                  // surface if the page underneath is darker than it.
                  colors: [
                    Color(0xFFE7E5EB),
                    Color(0xFFDBD9E2),
                    Color(0xFFCFCDD8)
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          // Two red glows — the colour the glass picks up as you scroll.
          const Positioned(top: -110, right: -80, child: _Glow(size: 340)),
          const Positioned(bottom: 40, left: -130, child: _Glow(size: 320)),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 68, 20, 160),
            children: [
              _header(),
              const SizedBox(height: 24),
              _liveCard(),
              const SizedBox(height: 30),
              _sectionTitle('Stations'),
              const SizedBox(height: 14),
              _stationRow(),
              const SizedBox(height: 30),
              _sectionTitle('Recently played'),
              const SizedBox(height: 14),
              for (int i = 0; i < _recent.length; i++) ...[
                _row(_recent[i]),
                if (i != _recent.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kBrand,
                      boxShadow: [
                        BoxShadow(
                            color: _kBrand, blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ON AIR · 88.6',
                    style: TextStyle(
                      color: _kBrand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: _kInk.withValues(alpha: 0.12), width: 1.4),
            image: const DecorationImage(
              image: NetworkImage('https://picsum.photos/seed/dj/120/120'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _liveCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Image.network(
            'https://picsum.photos/seed/onair/900/620',
            height: 232,
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
                    _kBrand.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: _kBrand,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Midnight Signal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'with Nadia Rey · 2 hrs left',
                        style:
                            TextStyle(color: Color(0xBFFFFFFF), fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBrand,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x80FF3B30),
                          blurRadius: 22,
                          spreadRadius: 1),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 31),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationRow() {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: _stations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final (String name, String seed) = _stations[i];
          return SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    'https://picsum.photos/seed/$seed/260/260',
                    width: 118,
                    height: 118,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(_Item item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kInk.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://picsum.photos/seed/${item.seed}/120/120',
              width: 54,
              height: 54,
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
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kInk.withValues(alpha: 0.55),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill_rounded, color: _kBrand, size: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: _kInk,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      );

  /// Artwork-only cards — name + image seed, no second line.
  static const List<(String, String)> _stations = [
    ('Nightline', 'ra'),
    ('Static FM', 'rb'),
    ('Deep Cuts', 'rc'),
    ('Red Room', 'rd'),
    ('Low Tide', 're'),
  ];

  static const _recent = [
    _Item('Signal Lost', 'Kova · 4:12', 'r1'),
    _Item('Analog Heart', 'June Wilder · 3:38', 'r2'),
    _Item('Neon Rain', 'The Hours · 5:02', 'r3'),
    _Item('Slow Burn', 'Marisa Oak · 4:47', 'r4'),
  ];
}

/// A soft red bloom behind the feed, so the glass has colour to bend.
class _Glow extends StatelessWidget {
  const _Glow({required this.size});

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
            colors: [_kBrand.withValues(alpha: 0.16), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _Item {
  const _Item(this.title, this.subtitle, this.seed);
  final String title;
  final String subtitle;
  final String seed;
}
