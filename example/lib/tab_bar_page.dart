import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/tab_bar_page.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const TabBarPage(),
    ),
  );
}

// =============================================================
// The glass-pill nav bar on a LIGHT page: one wide, centred frosted-white
// capsule holding all four tabs, with the red belonging to the selected
// STATE rather than to one tab.
//
// A drop-in pairing — `LiquidGlassScaffold` for the page,
// `LiquidGlassTabBar` for the bar — with the selection pill turned up to
// the glass-refracting tier (`pillStyle.mode`). Everything the pill does
// is configured through `LiquidGlassTabPillStyle`: its glass look, its
// resting look, its contact shadow and its motion.
//
// The chips under the header swap `pillStyle.mode` through all three of
// its values — `both`, `impellerOnly`, `none` — on the same bar, so the
// only thing that changes between them is that one line.
//
// Tapping a tab moves the pill and swaps the feed's title. `onChanged` is
// an ordinary callback, so the bar drives a body swap — or a `Navigator`,
// if a host wants one — with the same one line.
//
// The pill's deformation comes from acceleration: its drawn position is
// sampled every frame in pixels, differentiated twice, and the averaged
// acceleration scales it oppositely on the two axes — stretching wide and
// flat as it launches off a tab, squashing narrow and tall as it brakes
// into the next, and sitting undeformed at constant speed.
// =============================================================

/// The red the selected tab burns in — the one saturated colour on the
/// page, so it is also the colour the surrounding glass picks up.
const Color _kBrand = Color(0xFFFF3B30);

/// Type and hairlines on the light page — near-black rather than black,
/// so nothing on the page is a pure endpoint.
const Color _kInk = Color(0xFF121215);

/// The frosted-white capsule material over a soft optical rim.
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

/// One tab: what the bar draws for it, and what the page behind it opens
/// with. Both live on the same row so a fifth tab is one line, not four
/// lists to keep in step.
class _Tab {
  const _Tab(this.icon, this.label, this.title, this.blurb, this.seed);

  final IconData icon;
  final String label;

  /// The page heading — the bar's own label is too short to be a title.
  final String title;
  final String blurb;

  /// Artwork seed, so every pushed page arrives with its own image.
  final String seed;
}

const List<_Tab> _kTabs = [
  _Tab(
      Icons.home_rounded,
      'Home',
      'For you',
      'Cut from what you played this week, and the shows either side of it.',
      'ta'),
  _Tab(Icons.grid_view_rounded, 'Browse', 'Browse',
      'Every station on the network, sorted by the hour it goes out.', 'tb'),
  _Tab(Icons.podcasts_rounded, 'Radio', 'On air',
      'Live right now on 88.6 and the two sister feeds.', 'tc'),
  _Tab(Icons.library_music_outlined, 'Library', 'Your library',
      'Saved shows, finished downloads, and whatever is still queued.', 'td'),
];

class TabBarPage extends StatefulWidget {
  const TabBarPage({super.key});

  @override
  State<TabBarPage> createState() => _TabBarPageState();
}

class _TabBarPageState extends State<TabBarPage> {
  int _index = 1;

  /// Which tier the selection pill runs at. `LiquidGlassPillMode` has
  /// exactly these three values and the chips under the header walk
  /// through all of them, so the difference is something you look at
  /// rather than read about.
  LiquidGlassPillMode _mode = LiquidGlassPillMode.both;

  static const double _barHeight = 60;
  static const double _edge = 16;
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
    return LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, i) => Icon(
        icon,
        // Under the glass the glyph is drawn at its own size; the bar
        // hands the builder the box, the builder only has to fill it.
        size: i.underGlass == true ? 24 : _iconRest,
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
    for (final _Tab t in _kTabs) _tab(t.icon, t.label),
  ];

  /// A tap selects the tab. Nothing else moves: the bar stays put and the
  /// feed re-titles under it, so the pill's travel is the whole event.
  void _openTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    // Fill the phone width with a small edge margin, while keeping the four
    // tabs comfortably grouped on tablets.
    final double screen = MediaQuery.sizeOf(context).width;
    final double barWidth = (screen - _edge * 2).clamp(280.0, 560.0);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: _OnAirFeed(
        title: _kTabs[_index].title,
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
      ),

      // ── the wide, centred tab capsule ────────────────────────────
      bottomNavigationBar: LiquidGlassTabBar(
        items: _items,
        selectedIndex: _index,
        onChanged: _openTab,
        width: barWidth,
        height: _barHeight,
        itemPadding: 3,
        // The scaffold adds the safe-area inset on top of this.
        margin: const EdgeInsets.only(bottom: _bottom),
        style: LiquidGlassStyle(
          shape: _glassShape(_barHeight / 2),
          appearance: const LiquidGlassAppearance(
            color: Color(0x8FFFFFFF),
            blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
            // The bar's contact shadow lives in the material, like any
            // lens's: the capsule wraps itself in this ring.
            shadow: LiquidGlassShadow(blur: 9, opacity: 0.13),
          ),
          refraction: const LiquidGlassRefraction(
            distortion: 0.06,
            distortionWidth: 26,
          ),
        ),
        itemStyle: const LiquidGlassTabItemStyle(
          // The one place the selected look is decided — icon, bloom and
          // label all read it, on every tab.
          selectedColor: _kBrand,
          unselectedColor: _kInk,
          iconSize: _iconRest,
          labelFontSize: 10,
          iconLabelGap: 2,
          underGlassIconSize: 30,
          underGlassLabelFontSize: 10,
          selectedFontWeight: FontWeight.w700,
          unselectedFontWeight: FontWeight.w600,
        ),

        // ── the moving pill ──────────────────────────────────────
        // The glass-refracting tier, its look, its motion and its
        // contact shadow are all the tuned defaults now — pure
        // refraction over a thin-rimmed capsule, ±12 % squash, a tight
        // tucked-in ring. The one thing this page decides is where the
        // pill comes to rest. A different pill shadow would be authored
        // where every lens's is — on the glass style's
        // `appearance.shadow`.
        pillStyle: LiquidGlassTabPillStyle(
          // The tier knob, driven by the chips on the page so all
          // three are one tap apart: `both` = the glass-refracting
          // pill on every renderer, `impellerOnly` = glass on
          // Impeller and a flat highlight on Skia/Web, `none` = the
          // flat tier everywhere. `both` is the default.
          mode: _mode,
          // Where it comes to rest: a barely-there grey. The bar is thin
          // glass now, so the resting patch only has to hint at which tab
          // is selected — the red glyph is already saying it.
          rest: LiquidGlassStyle(
            shape: _glassShape(28),
            appearance: const LiquidGlassAppearance(color: Color(0x2EAEAEB2)),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The page behind the glass — a red-lit radio station, so the bar
//  has real colour to bend.
// ════════════════════════════════════════════════════════════════

class _OnAirFeed extends StatelessWidget {
  const _OnAirFeed({
    required this.title,
    required this.mode,
    required this.onModeChanged,
  });

  final String title;

  /// The tier the bar's pill is running at, and the way back out — the
  /// picker lives in the feed rather than over the bar so it never sits
  /// in front of the thing it is switching.
  final LiquidGlassPillMode mode;
  final ValueChanged<LiquidGlassPillMode> onModeChanged;

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
              const SizedBox(height: 18),
              _PillModePicker(mode: mode, onChanged: onModeChanged),
              const SizedBox(height: 22),
              _liveCard(),
              const SizedBox(height: 30),
              _sectionTitle('Stations'),
              const SizedBox(height: 14),
              _stationRow(),
              const SizedBox(height: 30),
              _sectionTitle('Recently played'),
              const SizedBox(height: 14),
              for (int i = 0; i < _recent.length; i++) ...[
                _trackRow(_recent[i]),
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
            border:
                Border.all(color: _kInk.withValues(alpha: 0.12), width: 1.4),
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

/// The three tiers of [LiquidGlassPillMode], as three chips.
///
/// One line each, because the whole point is that the only thing that
/// changes between them is the `mode:` on `pillStyle` — same bar, same
/// items, same rest style.
class _PillModePicker extends StatelessWidget {
  const _PillModePicker({required this.mode, required this.onChanged});

  final LiquidGlassPillMode mode;
  final ValueChanged<LiquidGlassPillMode> onChanged;

  static const List<(LiquidGlassPillMode, String, String)> _tiers = [
    (
      LiquidGlassPillMode.both,
      'both',
      'A second refracting surface, on every renderer. Excellent on '
          'Impeller. On Skia and the web it is an experiment and heavy — '
          'a second full-page capture; do not ship it there.',
    ),
    (
      LiquidGlassPillMode.impellerOnly,
      'impellerOnly',
      'Glass on Impeller, flat highlight on Skia and the web.',
    ),
    (
      LiquidGlassPillMode.none,
      'none',
      'The flat sliding capsule everywhere. One lens, one read.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String note = _tiers.firstWhere((t) => t.$1 == mode).$3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PILL MODE',
          style: TextStyle(
            color: _kInk.withValues(alpha: 0.45),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (LiquidGlassPillMode m, String label, _) in _tiers)
              _Chip(
                label: label,
                selected: m == mode,
                onTap: () => onChanged(m),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          note,
          style: TextStyle(
            // `both` is the one tier that costs something on Skia, and the
            // web is always Skia: flag it there.
            color: kIsWeb && mode == LiquidGlassPillMode.both
                ? const Color(0xFFB45309)
                : _kInk.withValues(alpha: 0.55),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kBrand : Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color:
                  selected ? Colors.transparent : _kInk.withValues(alpha: 0.10),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _kInk.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
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

// ════════════════════════════════════════════════════════════════
//  Shared page furniture — the feed and the pushed page draw the same
//  row and the same heading, so a tab's page reads as part of the app
//  rather than as a demo stub.
// ════════════════════════════════════════════════════════════════

Widget _sectionTitle(String text) => Text(
      text,
      style: const TextStyle(
        color: _kInk,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );

Widget _trackRow(_Item item) {
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
