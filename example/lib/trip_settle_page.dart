import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Thailand — Settle: the trip page, adapting ONLY when scrolling
// settles.
//
// Same photo feed and glass chrome as the Thailand Trip page, but the
// whole adaptive group hangs off one
// LiquidGlassAdaptivityController(enabled: false): while the feed
// moves fast, every palette stays frozen — no verdict flips mid-fling.
// "Settled" is judged by SPEED, not by touch: lifting the finger into
// a fling changes nothing; once the motion decays to a crawl,
// adaptOnce() takes exactly one look and every surface (header band,
// title, chevron pill, nav bar, OS icons) animates to the settled
// content together. One look on entry, one per settled scroll, zero
// captures in between.
//
//   flutter run -t lib/trip_settle_page.dart   (standalone)
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
      home: const TripSettlePage(),
    );
  }
}

/// Shared palettes: smoked glass + light content over dark photos,
/// milky glass + dark content over light ones. The feed opens on dark
/// jungle shots, so start dark for a motion-free first verdict.
const _adapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0x33000000),
  contentColorOnDark: Colors.white,
  glassColorOnLight: Color(0x66FFFFFF),
  contentColorOnLight: Color(0xFF1C1C1E),
  duration: Duration(milliseconds: 300),
  initialBrightness: Brightness.dark,
  // Narrow hysteresis: photo content often averages near mid-gray
  // (~0.51), which the default 0.45–0.55 band would keep latched on
  // the previous verdict.
  darkBelow: 0.50,
  lightAbove: 0.50,
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
  initialBrightness: Brightness.dark,
  darkBelow: 0.50,
  lightAbove: 0.50,
);

/// Header geometry — compact, matching the iOS photo-memory chrome.
const double _headerHeight = 48;
const double _headerTopMargin = 4;

/// The nav bar capsule's continuous (Apple capsule-style) glass shape.
const LiquidGlassShape _navBarShape = LiquidGlassShape(
  cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
  cornerRadius: 50,
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

class TripSettlePage extends StatefulWidget {
  const TripSettlePage({super.key});

  @override
  State<TripSettlePage> createState() => _TripSettlePageState();
}

class _TripSettlePageState extends State<TripSettlePage> {
  final ScrollController _scroll = ScrollController();
  int _index = 0;

  /// `false` → every glass surface judges the background behind
  /// ITSELF: the header and the bar can legitimately disagree.
  /// `true` → both follow the bottom strip's link, so they flip
  /// together in lockstep. The floating glass button flips this live;
  /// the link is the only thing that couples them.
  bool _linked = false;

  /// The channel the bottom strip publishes on while [_linked].
  final LiquidGlassAdaptivityLink _link = LiquidGlassAdaptivityLink();

  /// The settle switch: mounted DISABLED, so every adaptive surface
  /// holds its palette while the feed moves. adaptOnce() — fired when a
  /// scroll settles — is the only thing that ever re-judges the
  /// background.
  final LiquidGlassAdaptivityController _adaptCtrl =
      LiquidGlassAdaptivityController(enabled: false);

  // ── Settle detection ──────────────────────────────────────────
  // "Settled" = the scroll SPEED has decayed to a crawl — not merely
  // finger-up (a fling keeps the feed moving long after the touch
  // ends), and not only the dead stop (the last few px of a fling's
  // tail change nothing worth waiting for). Speed is measured from the
  // scroll updates; below [_settleSpeed] for a couple of frames the
  // look fires, and a burst back above [_fastSpeed] re-arms it.

  /// px/s under which the feed counts as settled ("very low").
  static const double _settleSpeed = 120;

  /// px/s above which a new burst of motion re-arms the next look.
  static const double _fastSpeed = 480;

  /// Consecutive slow updates required — one jittery frame can't fire.
  static const int _slowFramesToSettle = 2;

  double _lastPixels = 0;
  int _lastMoveUs = 0;
  int _slowFrames = 0;
  bool _settledThisScroll = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _lastPixels = n.metrics.pixels;
      _lastMoveUs = DateTime.now().microsecondsSinceEpoch;
      _slowFrames = 0;
      _settledThisScroll = false;
    } else if (n is ScrollUpdateNotification) {
      final int nowUs = DateTime.now().microsecondsSinceEpoch;
      final double dt = (nowUs - _lastMoveUs) / 1e6;
      final double speed =
          dt <= 0 ? double.infinity : (n.metrics.pixels - _lastPixels).abs() / dt;
      _lastPixels = n.metrics.pixels;
      _lastMoveUs = nowUs;
      if (speed >= _fastSpeed) {
        // Sped back up (a follow-up fling, a fast drag): the last look
        // is stale — arm the next one.
        _settledThisScroll = false;
        _slowFrames = 0;
      } else if (speed >= _settleSpeed) {
        _slowFrames = 0;
      } else if (!_settledThisScroll &&
          ++_slowFrames >= _slowFramesToSettle) {
        _settledThisScroll = true;
        _adaptCtrl.adaptOnce();
      }
    } else if (n is ScrollEndNotification && !_settledThisScroll) {
      // Stopped without ever crawling (an abrupt halt): fallback so a
      // scroll never ends unjudged.
      _settledThisScroll = true;
      _adaptCtrl.adaptOnce();
    }
    return false;
  }

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
    // No adaptivity here on purpose: the bar inherits the scaffold's
    // group (edges bottom band / whole) automatically — controller
    // included, so it settles with everything else.
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
  void initState() {
    super.initState();
    // The entry look: the page mounts frozen on the dark guess; one
    // post-frame adaptOnce() lands the real verdict, then the page is
    // silent until a scroll settles.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _adaptCtrl.adaptOnce());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _adaptCtrl.dispose();
    _link.dispose();
    super.dispose();
  }

  /// Chevron paging: ∨ glides the feed forward, ∧ back. The animation's
  /// end emits a ScrollEndNotification like any drag, so a page tap
  /// also finishes with one adaptation.
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

    // The shared palettes with THIS page's settle controller attached —
    // the scaffold spreads them over its edge strips, and every
    // inheriting surface (bar, title, pill, chrome) obeys the same hold.
    final LiquidGlassAdaptivity adapt =
        _adapt.copyWith(controller: _adaptCtrl);

    return LiquidGlassScaffold(
      // The strips only ever judge the SYSTEM bars. The toggle decides
      // whether the glass chrome rides the bottom strip's verdict
      // (linked) or judges its own backdrop (independent).
      // Linked: the top strip FOLLOWS the header's area, so the OS
      // status bar mirrors the same verdict — no height to configure.
      adaptivity: LiquidGlassScaffoldAdaptivity(
        adapt,
        topFollowLink: _linked ? _link : null,
      ),
      systemChrome: LiquidGlassSystemChrome.both,
      appBarTopMargin: _headerTopMargin,
      // Linked: the header becomes the group's one PUBLISHER — it
      // samples its own band and broadcasts on _link, which the bar
      // and the status-bar strip both follow.
      appBar: _linked
          ? LiquidGlassAdaptiveArea(
              adaptivity: adapt.copyWith(link: _link),
              child: _TripHeader(
                onBack: () => Navigator.maybePop(context),
                onDown: () => _page(1),
                onUp: () => _page(-1),
              ),
            )
          : _TripHeader(
              onBack: () => Navigator.maybePop(context),
              onDown: () => _page(1),
              onUp: () => _page(-1),
            ),
      // The settle hook: speed-based (see _onScroll) — the look fires
      // when the motion decays to a crawl, wherever the finger is.
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _TripFeed(controller: _scroll),
      ),
      lenses: [
        // Scroll-edge dim band BEHIND the header — its own adaptivity
        // samples itself, so it carries the same controller to hold and
        // settle in step with the group.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + _headerTopMargin + 80 + 24,
          child: LiquidGlassScrollEdge(
            style: LiquidGlassScrollEdgeStyle.soft,
            edge: LiquidGlassEdge.top,
            blur: 4,
            useShaderBlur: true,
            adaptivity: _edgeAdapt.copyWith(controller: _adaptCtrl),
          ),
        ),
        // The adaptivity-mode switch, floating just under the header.
        Positioned(
          top: pad.top + _headerTopMargin + _headerHeight + 10,
          right: 16,
          child: LiquidGlassButton(
            label: _linked ? 'Linked' : 'Independent',
            icon: _linked
                ? Icons.select_all_rounded
                : Icons.vertical_align_center_rounded,
            height: 34,
            fontSize: 12.5,
            iconSize: 15,
            onPressed: () => setState(() => _linked = !_linked),
          ),
        ),
      ],
      bottomNavigationBar: LiquidGlassTabBar(
        items: const [
          LiquidGlassTabBarItem(
              icon: Icons.photo_library_rounded, label: 'Photos'),
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
        // a scope — it takes the same link through its own style.
        style: _linked
            ? _barStyle.copyWith(adaptivity: adapt.copyWith(link: _link))
            : _barStyle,
        pillStyle: _pillStyle,
      ),
    );
  }
}

/// The photo-memory header: a round glass back button on the left, the
/// trip title dead-center, and a glass chevron pill on the right.
class _TripHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _TripHeader({
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
            // Bare text over the photo — adapts through
            // LiquidGlassAdaptiveContent (inherits the top band / whole
            // area, settle controller included).
            const Center(
              child: LiquidGlassAdaptiveContent(
                child: Text(
                  'Thailand — Settle',
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
                  refraction: LiquidGlassRefraction(
                    distortion: 0.07,
                    distortionWidth: 24,
                    chromaticAberration: 0.002,
                  ),
                  appearance: LiquidGlassAppearance(
                    saturation: 1.2,
                    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
                  ),
                  shape: LiquidGlassShape(
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
              child: _ChevronPill(onDown: onDown, onUp: onUp),
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
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _ChevronPill({required this.onDown, required this.onUp});

  static const LiquidGlassStyle _style = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      clipQuality: LiquidGlassClipQuality.exact,
      cornerRadius: 24,
      borderWidth: 0.5,
      lightIntensity: 1.5,
      lightDirection: 90,
      lightColor: Colors.grey,
      borderType: OpticalBorder(
        borderSolidity: 0.5,
      ),
    ),
    appearance: LiquidGlassAppearance(
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
        // Same glyph scale as the round back button (0.6 × diameter),
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
        style: _style,
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

/// The background: the same travel journal as the Thailand Trip page —
/// alternating edge-to-edge photos and light text entries, so a settled
/// scroll can land on either verdict.
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
    // photo, text, photo, text, …, ending on a photo.
    final List<Widget> items = [
      for (int i = 0; i < _photoCount * 2 - 1; i++)
        i.isEven
            ? _TripPhoto(index: i ~/ 2)
            : _TripJournal(text: _journal[(i ~/ 2) % _journal.length]),
    ];
    return ColoredBox(
      // Same light gray as the White Room page (iOS systemGray5) —
      // visible on overscroll and past the last item.
      color: const Color(0xFFE5E5EA),
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) => items[i],
      ),
    );
  }
}

/// One journal entry — dark text on light paper.
class _TripJournal extends StatelessWidget {
  final String text;

  const _TripJournal({required this.text});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Same light gray as the White Room body (iOS systemGray5).
      color: const Color(0xFFE5E5EA),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
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
/// so it never vanishes and re-downloads on the way back.
class _TripPhotoState extends State<_TripPhoto>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// One seed per slot, themed to the journal stops. A new seed = a new
  /// (stable) photo, so editing a string here swaps that slot's image.
  static const List<String> _seeds = [
    'krabi-longtail',
    'chiangmai-elephant',
    'night-market',
    'wat-arun',
    'beach-town',
    'last-sunset',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Seeded picsum URL: random photo per slot, stable across rebuilds.
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
            child: Icon(Icons.landscape_rounded,
                color: Colors.white38, size: 48),
          ),
        ),
      ),
    );
  }
}
