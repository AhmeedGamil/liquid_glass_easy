import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';


// =============================================================
// Adaptivity — the default: every surface judges itself.
//
// A full-bleed photo feed under glass chrome, with NO coupling of any
// kind. Each surface carries the same palettes in its own
// `style.adaptivity` and samples the background directly behind ITSELF:
//
//  • the header's round back button and its ∨ / ∧ chevron pill,
//  • the centered title — bare text, adapting through
//    LiquidGlassAdaptiveContent because it has no glass to inherit from,
//  • the scroll-edge band that dims the feed under the header,
//  • the morph-pill bottom nav bar, in its own render pipeline.
//
// So they can disagree, and that is correct: the header sitting over a
// dark photo while the bar sits over light paper SHOULD wear different
// palettes. Scroll slowly and watch each flip on its own.
//
// To make them agree instead — one sampled region, one verdict, shared —
// see `adaptivity_advanced_page.dart`.
//
//   flutter run -t lib/adaptivity_page.dart   (standalone)
//   …or open it from the home menu.
// =============================================================

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const AdaptivityPage(),
    );
  }
}

/// Shared palettes: smoked glass + light content over dark photos,
/// milky glass + dark content over light ones.
///
/// Every glass surface on this page carries this in its own
/// `style.adaptivity` — the scaffold declares none, so nothing is
/// inherited and each component states what it wants.
///
/// No `initialBrightness`: an entry guess is resolved BEFORE the
/// fallback and would pin the page to one palette. Left off, the
/// verdict falls through to the app theme's brightness.
const _adapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0x33000000),
  contentColorOnDark: Colors.white,
  glassColorOnLight: Color(0x66FFFFFF),
  contentColorOnLight: Color(0xFF1C1C1E),
  duration: Duration(milliseconds: 300),
  // Narrow hysteresis: photo content often averages near mid-gray
  // (~0.51), which the default 0.45–0.55 band would keep latched on
  // the previous verdict.
  darkBelow: 0.6,
  lightAbove: 0.6,
);

/// The top scroll-edge band behind the header: a stronger fade tint
/// than the glass palettes, same verdict tuning as [_adapt].
const _edgeAdapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0xB3000000),
  contentColorOnDark: Colors.white,
  glassColorOnLight: Color(0xB3FFFFFF),
  contentColorOnLight: Color(0xFF1C1C1E),
  duration: Duration(milliseconds: 250),
  continuousGlassColor: true,
  darkBelow: 0.6,
  lightAbove: 0.6,
);

/// The page's flat background — what shows on overscroll, past the last
/// item and behind the journal entries. It follows the app's brightness:
/// iOS systemGray5 in the light, systemGray6-dark in the dark.
Color _pageBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFE5E5EA);

/// Journal text, sitting on [_pageBackground] — the inverse of it.
Color _pageInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE5E5EA)
        : const Color(0xFF1C1C1E);

/// Header geometry — compact, matching the iOS photo-memory chrome.
const double _headerHeight = 48;
const double _headerTopMargin = 4;

/// The nav bar capsule's continuous (Apple capsule-style) glass shape —
/// the same tuned rim as the Nav Jelly Tuner ships.
const LiquidGlassShape _navBarShape = LiquidGlassShape(
  cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
  cornerRadius: 50,
  //clipQuality: LiquidGlassClipQuality.exact,
  borderWidth: 0.8,
  lightIntensity: 1.1,
  lightDirection: 39,
    lightColor: Colors.grey,

  borderType: OpticalBorder(
    borderSaturation: 1.2,
    ambientIntensity: 1.0,
    borderSolidity: 1,
  ),
);

/// The moving glass pill's shape — continuous like the bar.
const LiquidGlassShape _navPillShape = LiquidGlassShape(
  cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
  cornerRadius: 59,
  //clipQuality: LiquidGlassClipQuality.exact,
  borderWidth: 0.8,
  lightIntensity: 1.1,
  lightDirection: 39,
  lightColor: Colors.grey,
  borderType: OpticalBorder(
    borderSaturation: 1.2,
    ambientIntensity: 1.0,
    borderSolidity: 1,
  ),
);

class AdaptivityPage extends StatefulWidget {
  const AdaptivityPage({super.key});

  @override
  State<AdaptivityPage> createState() => _AdaptivityPageState();
}

class _AdaptivityPageState extends State<AdaptivityPage> {
  final ScrollController _scroll = ScrollController();
  int _index = 0;

  /// Sigma the scroll edge blurs with — the shipped look.
  ///
  /// At 3 the ladder and the shader are indistinguishable: the rungs
  /// land at 1.0/1.4/2.4 and the shader's 20 taps cover a disc a few
  /// pixels wide. Their differences (shader grain, ladder stepping)
  /// only separate once sigma is large, so raise this to compare them.
  static const double _edgeBlur = 5;

  static const LiquidGlassStyle _barStyle = LiquidGlassStyle(
    shape: _navBarShape,
    appearance: LiquidGlassAppearance(
      color: Color(0x16FFFFFF),
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.07,
      distortionWidth: 28,
      chromaticAberration: 0.002,
    ),
    // Adaptivity is added at the call site from [_adapt] — nothing on
    // this page inherits, so it cannot be baked in here.
  );

  /// Morph-pill tier on every renderer; travel/jelly stay at the
  /// on-device-tuned defaults.
  static const LiquidGlassTabPillStyle _pillStyle = LiquidGlassTabPillStyle(
    mode: LiquidGlassPillMode.both,
    animated: true,
    shape: _navPillShape,
    glassStyle: LiquidGlassStyle(
      appearance: LiquidGlassAppearance(color: Colors.transparent),
      refraction: LiquidGlassRefraction(
        distortion: 0.05,
        distortionWidth: 10,
      ),
    ),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Chevron paging: ∨ glides the feed forward, ∧ back — one near-full
  /// viewport per tap, clamped to the scrollable range.
  void _page(double direction) {
    if (!_scroll.hasClients) return;
    final double step = MediaQuery.sizeOf(context).height * 0.85;
    final double target = (_scroll.offset + direction * step)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    return LiquidGlassScaffold(
      // A bare config, carrying no palettes of its own: it is here to
      // open the adaptive sampler (the scaffold's `adaptivity` is the
      // only thing that does) and to drive both system bars. Nothing
      // inherits a palette from it — every glass surface below states
      // its own in `style.adaptivity`.
      appBarTopMargin: _headerTopMargin,
      adaptivity: const LiquidGlassScaffoldAdaptivity(
        LiquidGlassAdaptivity(),
        systemChrome: LiquidGlassSystemChrome.both,
      ),
      // No area, no link: the header's pieces each carry [_adapt] and
      // judge the band behind themselves.
      appBar: _TripHeader(
        adaptivity: _adapt,
        onBack: () => Navigator.maybePop(context),
        onDown: () => _page(1),
        onUp: () => _page(-1),
      ),
      body: _TripFeed(controller: _scroll),
      lenses: [
        // Scroll-edge dim band BEHIND the header (lenses render below
        // the appBar slot): content dims as it slides under the title,
        // keeping it readable — the top variant of iOS's scroll edge.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + _headerTopMargin + 70 + 24,
          // One `ImageFilter.blur` pass, feathered from the inside by a
          // `dstIn` ramp — same band on every backend.
          child: LiquidGlassScrollEdge(
            style: LiquidGlassScrollEdgeStyle.soft,
            edge: LiquidGlassEdge.top,
            blur: _edgeBlur,
            blurCurve: Curves.easeInQuart,
            adaptivity: _edgeAdapt,
          ),
        ),
      ],
      bottomNavigationBar: LiquidGlassTabBar(
        items: const [
          LiquidGlassTabBarItem(icon: Icons.photo_library_rounded, label: 'Photos'),
          LiquidGlassTabBarItem(icon: Icons.map_rounded, label: 'Map'),
          LiquidGlassTabBarItem(icon: Icons.person_rounded, label: 'You'),
        ],
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        // No distinct accent (selected == unselected) → the selected
        // item counts as plain content and adapts with the rest.
        itemStyle: const LiquidGlassTabItemStyle(
          selectedColor: Colors.white,
          unselectedColor: Colors.white,
        ),
        // The bar renders in its own pipeline, so it cannot sit inside
        // a scope — it takes the palettes (and, while linked, the link)
        // through its own style like every other surface here.
        style: _barStyle.copyWith(adaptivity: _adapt),
        pillStyle: _pillStyle,
      ),
    );
  }
}

/// The photo-memory header: a round glass back button on the left, the
/// trip title dead-center, and a glass chevron pill on the right — all
/// [_headerHeight] tall.
class _TripHeader extends StatelessWidget {
  /// Handed to each piece's own style rather than inherited from a
  /// scaffold. While the page is linked this header sits inside a
  /// publishing [LiquidGlassAdaptiveArea], and a consumer inside an area
  /// picks the area's link up on its own — so this stays link-free and
  /// works either way.
  final LiquidGlassAdaptivity adaptivity;

  final VoidCallback onBack;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _TripHeader({
    required this.adaptivity,
    required this.onBack,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // A Stack (not a Row) so the title centers on the screen even
        // though the back button and the pill have different widths.
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Bare text over the photo — no glass behind it, so it
            // adapts through LiquidGlassAdaptiveContent, carrying the
            // palettes itself.
            Center(
              child: LiquidGlassAdaptiveContent(
                adaptivity: adaptivity,
                child: const Text(
                  'Adaptivity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidGlassTabBarAction(
                icon: Icons.arrow_back_ios_new_rounded,
                size: _headerHeight,
                onTap: onBack,
                style: LiquidGlassStyle(
                  adaptivity: adaptivity,
                  refraction: const LiquidGlassRefraction(
                    distortion: 0.07,
                    distortionWidth: 24,
                    chromaticAberration: 0.002,
                  ),
                  appearance: const LiquidGlassAppearance(
                    saturation: 1.2,
                    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
                  ),
                  shape: const LiquidGlassShape(
                    lightColor: Colors.grey,
                    borderWidth: 0.5,
                    lightDirection: 100,
                    lightIntensity: 1.5,
                    borderType: OpticalBorder(
                      ambientIntensity: 1.0,
                      lightSpread: 0.4,
                      borderSolidity: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _ChevronPill(
                adaptivity: adaptivity,
                onDown: onDown,
                onUp: onUp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ∨ / ∧ capsule from the header — one glass pill, two tap targets.
/// Icon colors are left unset so they follow the header band's verdict.
class _ChevronPill extends StatelessWidget {
  final LiquidGlassAdaptivity adaptivity;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _ChevronPill({
    required this.adaptivity,
    required this.onDown,
    required this.onUp,
  });

  static const LiquidGlassStyle _style = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      clipQuality: LiquidGlassClipQuality.exact,
      cornerRadius: 24,
      borderWidth: 0.5,
      lightIntensity: 1.5,
      lightDirection: 90,
        lightColor: Colors.grey,

      borderType: OpticalBorder(
        //borderSaturation: 1.2,
        //ambientIntensity: 5.0,
        //lightSpread: 0.5,
        borderSolidity: 0.5,
      ),
    ),
    appearance: LiquidGlassAppearance(
      //color: Color(0x14FFFFFF),
      saturation: 1.2,
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.07,
      distortionWidth: 24,
      chromaticAberration: 0.002,
    ),
  );

  Widget _tap(IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Same glyph scale as the round back button (0.46 × diameter),
        // so all three header pieces read as one set.
        child: Center(child: Icon(icon, size: _headerHeight * 0.6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Exactly two back-buttons wide — the pill reads as a pair of
      // fused circular buttons.
      width: _headerHeight * 1.7,
      height: _headerHeight,
      child: LiquidGlassLens(
        style: _style.copyWith(adaptivity: adaptivity),
        child: Row(
          children: [
            _tap(Icons.keyboard_arrow_down_rounded, onDown),
            _tap(Icons.keyboard_arrow_up_rounded, onUp),
          ],
        ),
      ),
    );
  }
}

/// The background: a travel journal — an edge-to-edge photo, then a
/// light text entry, then the next photo, and so on. The alternating
/// dark frames / light paper is exactly what the adaptive bands feed
/// on: every surface flips as a section scrolls beneath it.
class _TripFeed extends StatelessWidget {
  final ScrollController controller;

  const _TripFeed({required this.controller});

  static const List<String> _journal = [
    'We started in the south, island-hopping out of Krabi. The longtail '
        'boats drop you straight onto sandbars that disappear at high '
        'tide — water so clear the boats look like they are floating on '
        'glass.',
    'After that, we headed up north near Chiang Mai and spent a day at '
        'an elephant sanctuary. Feeding them bananas was definitely a '
        'highlight — they\'re so gentle (and so hungry). We got to hang '
        'out with them in this beautiful green forest and just take it '
        'all in.',
    'Back in the city we basically ate our way through the night '
        'markets. Mango sticky rice from a cart, boat noodles for '
        'pennies, and the best pad kra pao of the whole trip from a '
        'stall with three plastic stools.',
    'The temples deserve a slow morning. We caught Wat Arun right at '
        'sunrise before the crowds, all gold and porcelain in the early '
        'light, then drifted down the river on the public ferry like '
        'locals.',
    'Last stop was a quiet beach town where nothing happened, which was '
        'exactly the point. Hammocks, coconut shakes, and one final '
        'sunset that made the whole trip feel like a dream.',
  ];

  static const int _photoCount = 20;

  @override
  Widget build(BuildContext context) {
    // Interleaved: even slots are photos, odd slots journal entries —
    // photo, text, photo, text, …, ending on a photo. The journal
    // entries cycle once the five originals run out.
    final List<Widget> items = [
      for (int i = 0; i < _photoCount * 2 - 1; i++)
        i.isEven
            ? _TripPhoto(index: i ~/ 2)
            : _TripJournal(text: _journal[(i ~/ 2) % _journal.length]),
    ];
    return ColoredBox(
      // Visible on overscroll and past the last item, so it follows the
      // app's brightness rather than staying light under a dark theme.
      color: _pageBackground(context),
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) => items[i],
      ),
    );
  }
}

/// One journal entry — dark text on light paper under a light theme,
/// inverted under a dark one. The photos are what the adaptive bands
/// mostly feed on either way: picsum hands back light and dark frames.
class _TripJournal extends StatelessWidget {
  final String text;

  const _TripJournal({required this.text});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // The paper between photos, on the same brightness-driven pair as
      // the page behind it.
      color: _pageBackground(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Text(
          text,
          style: TextStyle(
            color: _pageInk(context),
            fontSize: 17,
            height: 1.45,
            letterSpacing: -0.2,
            // The body renders outside any Material, so clear the
            // fallback style's debug decoration explicitly.
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TripPhoto extends StatefulWidget {
  final int index;

  const _TripPhoto({required this.index});

  @override
  State<_TripPhoto> createState() => _TripPhotoState();
}

/// Keep-alive: a decoded photo stays mounted while scrolled far away,
/// so it never vanishes and re-downloads on the way back (the list was
/// disposing off-screen items and the image cache wasn't guaranteed to
/// still hold the bytes when they returned).
class _TripPhotoState extends State<_TripPhoto>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// One seed per slot, themed to the journal stops. A new seed = a new
  /// (stable) photo, so editing a string here swaps that slot's image.
  static const List<String> _seeds = [
    'krabi-longtail',
    'chiangmai-elephant',
    'bangkok-alley',
    'wat-arun',
    'beach-town',
    'last-sunset',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Seeded picsum URL: random photo per slot, stable across rebuilds.
    // Past the first six slots the themed seeds cycle with a round
    // number appended, so every slot still gets a DIFFERENT photo.
    final int round = widget.index ~/ _seeds.length;
    final String base = _seeds[widget.index % _seeds.length];
    final String seed = round == 0 ? base : '$base-$round';
    final String url = 'https://picsum.photos/seed/$seed/720/720';

    return AspectRatio(
      aspectRatio: 1,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: Color(0xFF1C222B),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.index.isEven
                  ? const [Color(0xFF2F5249), Color(0xFF0E3B33)]
                  : const [Color(0xFF5B4B2A), Color(0xFF23301C)],
            ),
          ),
          child: const Center(
            child: Icon(Icons.landscape_rounded, color: Colors.white38, size: 48),
          ),
        ),
      ),
    );
  }
}
