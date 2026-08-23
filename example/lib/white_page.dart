import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// White Room — the Thailand Trip chrome over a plain white page.
//
// Same components (photo-memory header, top scroll edge, the
// Separated/Shared toggle, glass-pill bottom nav bar) with NO content
// and an off-white
// body: everything should resolve to the light verdict — milky glass,
// dark glyphs — making it a clean reference for the light palette.
//
//   flutter run -t lib/white_page.dart   (standalone)
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
      home: const WhitePage(),
    );
  }
}

/// Same palettes/tuning as the trip page — including the dark initial
/// guess, so the first sample visibly corrects to the light palette.
const _adapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0x33000000),
  contentColorOnDark: Colors.white,
  glassColorOnLight: Color(0x66FFFFFF),
  contentColorOnLight: Color(0xFF1C1C1E),
  duration: Duration(milliseconds: 400),
  initialBrightness: Brightness.dark,
  darkBelow: 0.45,
  lightAbove: 0.55,
);

/// The top scroll-edge band behind the header.
const _edgeAdapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0xB3000000),
  contentColorOnDark: Colors.white,
  glassColorOnLight: Color(0xB3FFFFFF),
  contentColorOnLight: Color(0xFF1C1C1E),
  duration: Duration(milliseconds: 400),
  initialBrightness: Brightness.dark,
  darkBelow: 0.45,
  lightAbove: 0.55,
);

/// Header geometry — same as the trip page.
const double _headerHeight = 48;
const double _headerTopMargin = 4;

/// Nav bar capsule / pill shapes — same tuned continuous rims.
const LiquidGlassShape _navBarShape = LiquidGlassShape(
  cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
  cornerRadius: 50,
  borderWidth: 0.8,
  lightIntensity: 1.1,
  lightDirection: 39,
  borderType: OpticalBorder(
    borderSaturation: 1.2,
    ambientIntensity: 1.0,
    borderSolidity: 1,
  ),
);

const LiquidGlassShape _navPillShape = LiquidGlassShape(
  cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
  cornerRadius: 59,
  borderWidth: 0.8,
  lightIntensity: 1.1,
  lightDirection: 39,
  borderType: OpticalBorder(
    borderSaturation: 1.2,
    ambientIntensity: 1.0,
    borderSolidity: 1,
  ),
);

class WhitePage extends StatefulWidget {
  const WhitePage({super.key});

  @override
  State<WhitePage> createState() => _WhitePageState();
}

class _WhitePageState extends State<WhitePage> {
  int _index = 0;

  /// `false` → every glass surface judges the background behind
  /// ITSELF: the header and the bar can legitimately disagree.
  /// `true` → both follow the bottom strip's link, so they flip
  /// together in lockstep. The floating glass button flips this
  /// live; the link is the only thing that couples them.
  bool _linked = false;

  /// The channel the bottom strip publishes on while [_linked].
  final LiquidGlassAdaptivityLink _link = LiquidGlassAdaptivityLink();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
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
    // group (edges bottom band / whole) automatically.
  );

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
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    return LiquidGlassScaffold(
      // The strips only ever judge the SYSTEM bars. Linked: the top
      // strip FOLLOWS the header's area, so the OS status bar mirrors
      // the same verdict — no height to configure.
      adaptivity: LiquidGlassScaffoldAdaptivity(
        _adapt,
        topFollowLink: _linked ? _link : null,
      ),
      systemChrome: LiquidGlassSystemChrome.both,
      appBarTopMargin: _headerTopMargin,
      // Linked: the header becomes the group's one PUBLISHER — it
      // samples its own band and broadcasts on _link, which the bar and
      // the status-bar strip both follow.
      appBar: _linked
          ? LiquidGlassAdaptiveArea(
              adaptivity: _adapt.copyWith(link: _link),
              child: _WhiteHeader(onBack: () => Navigator.maybePop(context)),
            )
          : _WhiteHeader(onBack: () => Navigator.maybePop(context)),
      // The whole point: a contentless light page. Light gray (iOS
      // systemGray5) instead of pure white, so the glass and its milky
      // tint stay visible against the body.
      body: const ColoredBox(color: Color(0xFFE5E5EA)),
      lenses: [
        // Scroll-edge dim band behind the header.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + _headerTopMargin + _headerHeight + 24,
          child: const LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.top,
            blur: 2,
            adaptivity: _edgeAdapt,
          ),
        ),
        // The adaptivity-mode switch.
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
          LiquidGlassTabBarItem(icon: Icons.photo_library_rounded, label: 'Photos'),
          LiquidGlassTabBarItem(icon: Icons.map_rounded, label: 'Map'),
          LiquidGlassTabBarItem(icon: Icons.person_rounded, label: 'You'),
        ],
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        // No distinct accent → the selected item adapts with the rest.
        itemStyle: const LiquidGlassTabItemStyle(
          selectedColor: Colors.white,
          unselectedColor: Colors.white,
        ),
        // The bar renders in its own pipeline, so it cannot sit inside
        // a scope — it takes the same link through its own style.
        style: _linked
            ? _barStyle.copyWith(adaptivity: _adapt.copyWith(link: _link))
            : _barStyle,
        pillStyle: _pillStyle,
      ),
    );
  }
}

/// Same header as the trip page: round glass back button, adaptive bare
/// title, and the ∨ / ∧ chevron pill (inert here — no feed to page).
class _WhiteHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _WhiteHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: LiquidGlassAdaptiveContent(
                child: Text(
                  'White Room',
                  style: TextStyle(
                    fontSize: 21,
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
              ),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: _ChevronPill(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ∨ / ∧ capsule — one glass pill, two (inert) tap targets.
class _ChevronPill extends StatelessWidget {
  const _ChevronPill();

  static const LiquidGlassStyle _style = LiquidGlassStyle(
    shape: LiquidGlassShape(
      cornerRadius: 24,
      borderWidth: 1.1,
      lightIntensity: 1.2,
      lightDirection: 80,
      borderType: OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 1.0,
        borderSolidity: 0.35,
      ),
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x14FFFFFF),
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.07,
      distortionWidth: 24,
      chromaticAberration: 0.002,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _headerHeight * 2,
      height: _headerHeight,
      child: LiquidGlassLens(
        style: _style,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: _headerHeight * 0.46),
              ),
            ),
            Expanded(
              child: Center(
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    size: _headerHeight * 0.46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
