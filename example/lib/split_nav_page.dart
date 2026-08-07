import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/split_nav_page.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const SplitNavPage(),
    ),
  );
}

// =============================================================
// A **split** bottom bar: the tabs live in one ink-dark capsule that
// stops short of the right edge, and search sits on its own detached
// circle beside it. Two separate pieces of glass at the same baseline —
// the layout you see on music and radio apps, where search is a
// destination-less action and does not belong in the tab row.
//
// Three things make the look:
//   • ink instead of frost — the capsule is tinted near-black, so the
//     refraction reads as a dark lens over the page, not a white haze;
//   • the red belongs to the selected state, not to one tab — whichever
//     tab the pill is on burns red and blooms, the rest stay white;
//   • the tab row and the action are sized to the same height, so the
//     circle reads as a piece broken off the capsule rather than a FAB.
//
// The pairing is a first-class scaffold slot: `bottomNavigationBar` for
// the capsule, `bottomNavigationBarAction` for the circle. The scaffold
// pins both to the same bottom line, safe area included.
// =============================================================

/// The red the selected tab burns in — the one saturated colour on the
/// page, so it is also the colour the surrounding glass picks up.
const Color _kBrand = Color(0xFFFF3B30);

/// The ink both pieces of glass are cut from: a near-black tint over a
/// soft optical rim. Shared by the capsule and the detached circle so
/// they read as the same material at two sizes.
LiquidGlassShape _inkShape(double cornerRadius) =>
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

LiquidGlassStyle _inkStyle(double cornerRadius) => LiquidGlassStyle(
      shape: _inkShape(cornerRadius),
      appearance: const LiquidGlassAppearance(
        // Dark enough to read as ink, translucent enough that the page
        // still bends through it.
        color: Color(0x9E0A0A0F),
        blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.06,
        distortionWidth: 26,
        //chromaticAberration: 0.002,
      ),
    );

class SplitNavPage extends StatefulWidget {
  const SplitNavPage({super.key});

  @override
  State<SplitNavPage> createState() => _SplitNavPageState();
}

class _SplitNavPageState extends State<SplitNavPage> {
  int _index = 1;

  // Bar height and the action's diameter are the same number: the circle
  // is the capsule's end cap, moved away from it.
  static const double _barHeight = 60;
  static const double _edge = 16;
  static const double _gap = 10;

  /// One tab. Every one of them goes through the glyph builder — not
  /// because the art is custom, but because a selected icon **blooms**,
  /// and the built-in [Icon] path has no shadow to give it.
  ///
  /// The builder never names a colour: it paints `i.color`, the colour
  /// the bar already resolved for the layer it is drawing, and blooms in
  /// that same colour. So the selected look lives in exactly one place —
  /// `itemStyle.selectedColor` — and moving it repaints icon, glow and
  /// label together, on all four tabs alike.
  ///
  /// It is also what makes the pill reveal work: the glass pill draws
  /// every tab twice per frame, once forced unselected outside the pill
  /// and once forced selected inside it, so the red is wiped on as the
  /// pill arrives instead of switching under it.
  ///
  /// The builder's output is boxed to `itemStyle.iconSize` and scaled
  /// *down* to fit, never up. That box is what keeps the inside- and
  /// outside-the-pill copies laid out identically so the reveal cuts
  /// cleanly between them.
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

  /// The glyph's size — and therefore `itemStyle.iconSize`, the box
  /// every glyph is fitted into.
  static const double _iconRest = 24;

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

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      actionMargin: _edge,
      body: _OnAirFeed(title: _titles[_index]),

      // ── the tab capsule, held off the right edge ───────────────
      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        width: barWidth,
        height: _barHeight,
        itemPadding: 5,
        // Left-anchored: a centred bar would drift under the circle as
        // the screen widens.
        alignment: Alignment.bottomLeft,
        margin: const EdgeInsets.only(left: _edge, bottom: 22),
        style: _inkStyle(_barHeight / 2),
        itemStyle: const LiquidGlassNavItemStyle(
          // The one place the selected look is decided — icon, bloom and
          // label all read it, on every tab.
          selectedColor: _kBrand,
          unselectedColor: Color(0xD9FFFFFF),
          iconSize: 24,
          labelFontSize: 10,
          iconLabelGap: 2,
          selectedFontWeight: FontWeight.w700,
          unselectedFontWeight: FontWeight.w600,
        ),
        pillStyle: LiquidGlassNavPillStyle(
          mode: LiquidGlassPillMode.both,
          animated: true,
          growHeight: 9,
          shape: _inkShape(28),blur: LiquidGlassBlur(sigmaX: 0, sigmaY: 0),
          // The moving pill carries no tint of its own — over ink, a
          // fill would only mud the capsule. It is pure refraction.
          glassStyle: LiquidGlassStyle(
            shape: _inkShape(40),
            
            appearance: const LiquidGlassAppearance(color: Colors.transparent,blur: LiquidGlassBlur(sigmaX: 0, sigmaY: 0)),
            refraction: const LiquidGlassRefraction(
              distortion: 0.05,
              distortionWidth: 12,
              chromaticAberration: 0.0015,
              magnification: 0.9,
            ),

          ),
          // Where it comes to rest: the lighter capsule of the reference,
          // a lift of white over the dark bar.
          rest: LiquidGlassStyle(
            shape: _inkShape(28),
            
            appearance: const LiquidGlassAppearance(color: Colors.transparent,blur: LiquidGlassBlur(sigmaX: 0, sigmaY: 0)),
          ),
        ),
      ),

      // ── search, on its own glass ───────────────────────────────
      bottomNavigationBarAction: LiquidGlassTabBarAction(
        icon: Icons.search_rounded,
        size: _barHeight,
        onTap: _search,
        style: _inkStyle(_barHeight / 2),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The page behind the glass — a red-lit radio station, so both
//  pieces of glass have real colour to bend.
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
                  colors: [Color(0xFF1A0C0E), Color(0xFF0B0A0C), Color(0xFF060608)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          // Two red glows — the colour the ink glass picks up as you scroll.
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
                        BoxShadow(color: _kBrand, blurRadius: 8, spreadRadius: 1),
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
                  color: Colors.white,
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.4),
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
                        style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 13.5),
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
                      BoxShadow(color: Color(0x80FF3B30), blurRadius: 22, spreadRadius: 1),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 31),
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
                    color: Colors.white,
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
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.5),
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
          color: Colors.white,
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

/// A soft red bloom behind the feed, so the ink glass has colour to bend.
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
            colors: [_kBrand.withValues(alpha: 0.34), Colors.transparent],
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
