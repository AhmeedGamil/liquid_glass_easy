import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this showcase can be launched directly with:
///   flutter run -t lib/showcases/photos_library_page.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const PhotosLibraryPage(),
    ),
  );
}

// =============================================================
// A photo library: an edge-to-edge grid that runs under everything,
// with four pieces of glass floating over it — a filter circle and a
// Select pill at the top, a two-tab capsule and a detached search
// circle at the bottom.
//
// What makes the page:
//   • nothing is a bar — the grid starts at pixel row zero and scrolls
//     under the title, so every glass surface always has photographs
//     moving behind it rather than a solid header;
//   • one material at four sizes — the same white frost, rim and
//     refraction build the 44 px circle, the Select pill, the tab
//     capsule and the 58 px search circle, so they read as pieces of
//     the same sheet;
//   • the frost carries the content — a light material with ink
//     foreground, iOS-blue only for the selected tab, so the controls
//     stay legible as bright and dark photos scroll under them.
//
// The whole page is one `LiquidGlassScaffold`: the grid is the `body`
// every lens refracts, the header goes in `appBar`, the tab capsule in
// `bottomNavigationBar` and search in `bottomNavigationBarAction` —
// which pins the circle to the capsule's baseline, safe area included.
// =============================================================

/// The one saturated colour on the page: the selected tab, and the tick
/// on a picked photo.
const Color _kTint = Color(0xFF0A84FF);

/// Foreground on the glass. Near-black rather than black, so it sits in
/// the frost instead of punching through it.
const Color _kInk = Color(0xE61C1C1E);

/// The rim every piece of glass is cut with — a bright, tight optical
/// border, which is what keeps a white-on-white control visible when a
/// pale photo scrolls under it.
LiquidGlassShape _frostShape(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.7,
      lightIntensity: 1,
      lightDirection: 39,
      borderType: const OpticalBorder(
        borderSaturation: 1.0,
        ambientIntensity: 1.0,
        borderSolidity: 1,
      ),
    );

/// The shared material. The tint is heavy for glass on purpose: it is
/// what lets ink-coloured labels survive a black photograph passing
/// underneath, and the saturation lift puts the colour of the photo back
/// into the frost it just washed out.
LiquidGlassStyle _frost(double cornerRadius, {LiquidGlassShadow? shadow}) =>
    LiquidGlassStyle(
      adaptivity: LiquidGlassAdaptivity(),
      shape: _frostShape(cornerRadius),
      appearance: LiquidGlassAppearance(
        color: const Color(0x6EFFFFFF),
        blur: const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
        saturation: 1.2,
        shadow: shadow,
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.14,
        distortionWidth: 24,
        chromaticAberration: 0.002,
      ),
    );

/// What the frost does about the photograph under it. The material is
/// light on both verdicts — ink is the constant here, and the only
/// thing that reads over a black frame AND a blown-out sky — so the
/// tint is what adapts: it thins to the page's own frost over a dark
/// photo and thickens over a bright one, keeping the ink's contrast.
/// [continuousGlassColor] glides it rather than switching, so a scroll
/// through mixed frames never snaps.
const LiquidGlassAdaptivity _adapt = LiquidGlassAdaptivity(
  glassColorOnDark: Color(0x6EFFFFFF),
  contentColorOnDark: _kInk,
  glassColorOnLight: Color(0x99FFFFFF),
  contentColorOnLight: _kInk,
  duration: Duration(milliseconds: 300),
  initialBrightness: Brightness.dark,
  continuousGlassColor: true,
);

/// A press response light enough for controls this small — they swell
/// under the finger and spring back, without moving.
const LiquidGlassTouch _press = LiquidGlassTouch.flexing(
  LiquidGlassFlex.subtle(),
);

class PhotosLibraryPage extends StatefulWidget {
  const PhotosLibraryPage({super.key});

  @override
  State<PhotosLibraryPage> createState() => _PhotosLibraryPageState();
}

class _PhotosLibraryPageState extends State<PhotosLibraryPage> {
  /// Capsule height and the search circle's diameter are the same
  /// number: the circle reads as the capsule's end cap, moved away.
  static const double _barHeight = 58;
  static const double _edge = 20;

  int _tab = 0;
  int _filter = 0;
  bool _selecting = false;
  final Set<int> _picked = <int>{};

  /// What the filter circle cycles through. The count is the library's
  /// headline number; the `keep` predicate is what the grid actually
  /// shows, so the two agree as you cycle.
  static const List<(String, String, int)> _filters = [
    ('Items', '4,627', 1),
    ('Favorites', '318', 3),
    ('Videos', '96', 4),
    ('Screenshots', '211', 5),
  ];

  static final List<LiquidGlassTabBarItem> _tabs = [
    const LiquidGlassTabBarItem(
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library_rounded,
      label: 'Library',
    ),
    const LiquidGlassTabBarItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Collections',
    ),
  ];

  /// Photo indices surviving the active filter — every nth cell, so the
  /// grid visibly re-flows when the filter circle is tapped.
  List<int> get _photos {
    final int step = _filters[_filter].$3;
    return [for (int i = 0; i < 96; i += step) i];
  }

  String get _subtitle {
    if (_selecting) {
      return _picked.isEmpty
          ? 'Select Items'
          : '${_picked.length} Selected';
    }
    final (String name, String count, _) = _filters[_filter];
    return '$count $name';
  }

  void _cycleFilter() => setState(() {
        _filter = (_filter + 1) % _filters.length;
        _picked.clear();
      });

  void _toggleSelecting() => setState(() {
        _selecting = !_selecting;
        _picked.clear();
      });

  void _tapCell(int index) {
    if (!_selecting) return;
    setState(() {
      if (!_picked.remove(index)) _picked.add(index);
    });
  }

  void _search() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search — the detached action, not a tab'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(20, 0, 20, 108),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A plain Scaffold underneath, purely so the snack bar has somewhere
    // to land. It paints nothing — the glass scaffold fills it.
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: LiquidGlassScaffold(
        pixelRatio: 1,
        useSync: true,
        backgroundColor: Colors.black,
        actionMargin: _edge,
        // Every glass slot below — header controls, the tab capsule,
        // the search circle — inherits these palettes and judges the
        // photographs behind ITSELF, so nothing here has to be told
        // about the grid.
        adaptivity: const LiquidGlassScaffoldAdaptivity(_adapt,sampling: LiquidGlassAdaptiveSampling()),

        // ── the photographs, edge to edge and under everything ─────
        body: _PhotoGrid(
          photos: _photos,
          selecting: _selecting,
          picked: _picked,
          onTap: _tapCell,
          bottomInset: MediaQuery.of(context).padding.bottom,
        ),

        // ── title + the two top controls ───────────────────────────
        appBar: _LibraryHeader(
          subtitle: _subtitle,
          selecting: _selecting,
          onFilter: _cycleFilter,
          onSelect: _toggleSelecting,
        ),

        // ── the tab capsule, held off the left edge ────────────────
        bottomNavigationBar: LiquidGlassTabBar(
          items: _tabs,
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
          width: 189,
          height: _barHeight,
          itemPadding: 4,
          // Left-anchored, like the reference: the capsule hugs its two
          // tabs and leaves the right end of the line to search.
          alignment: Alignment.bottomLeft,
          margin: const EdgeInsets.only(left: _edge, bottom: 12),
          // The bar's contact shadow lives in the material, like any
          // lens's: the capsule wraps itself in this ring.
          style: _frost(
            _barHeight / 2,
            shadow: const LiquidGlassShadow(blur: 9, opacity: 0.16),
          ),
          itemStyle: const LiquidGlassTabItemStyle(
            selectedColor: Color.fromARGB(255, 0, 123, 255),
            unselectedColor: _kInk,
            iconSize: 24,
            underGlassIconSize: 28,
            labelFontSize: 11,
            iconLabelGap: 2,
            selectedFontWeight: FontWeight.w600,
            unselectedFontWeight: FontWeight.w500,
          ),
          pillStyle: LiquidGlassTabPillStyle(
            mode: LiquidGlassPillMode.both,
            animated: true,
            growHeight: 7,
            distortionWidth: 10,
            //shape: _frostShape(40),
            // Travelling, the pill carries almost no tint — over a
            // capsule this pale, a fill would only mud it. It is the
            // refraction of the bar's own frost that reads as movement.

            // Where it lands: the lighter capsule of the reference, a
            // lift of white on white.
            rest: LiquidGlassStyle(
              shape: _frostShape(50),
              appearance: const LiquidGlassAppearance(color: Color.fromARGB(40, 0, 0, 0)),
            ),
          ),
        ),

        // ── search, on its own glass ───────────────────────────────
        bottomNavigationBarAction: LiquidGlassTabBarAction(
          icon: Icons.search_rounded,
          size: _barHeight,
          onTap: _search,
          touch: _press,
          //foregroundColor: _kInk,
          style: _frost(_barHeight / 2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The header — a plain title over the photographs, and two glass
//  controls beside it.
// ════════════════════════════════════════════════════════════════

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.subtitle,
    required this.selecting,
    required this.onFilter,
    required this.onSelect,
  });

  final String subtitle;
  final bool selecting;
  final VoidCallback onFilter;
  final VoidCallback onSelect;

  static const double _controlHeight = 44;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ignoring the pointer is what lets a drag that starts on the
          // title scroll the grid underneath it — text hit-tests itself,
          // and this layer sits above the photos.
          Expanded(
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.15,
                      shadows: [
                        Shadow(color: Color(0x73000000), blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xF2FFFFFF),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      shadows: [
                        Shadow(color: Color(0x66000000), blurRadius: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Square width and height on the pill radius: the button is a
          // circle, and being the same widget as Select next to it means
          // both controls share one rim and one press response.
          LiquidGlassButton(
            width: _controlHeight,
            height: _controlHeight,
            padding: EdgeInsets.zero,
            onPressed: onFilter,
            touch: _press,
            foregroundColor: _kInk,
            iconSize: 24,
            style: _frost(_controlHeight / 2),
            child: const Icon(Icons.filter_list_rounded),
          ),
          const SizedBox(width: 10),
          LiquidGlassButton(
            label: selecting ? 'Done' : 'Select',
            height: _controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: onSelect,
            touch: _press,
            //foregroundColor: selecting ? _kTint : _kInk,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            style: _frost(_controlHeight / 2),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The page behind the glass — a three-column grid that starts at
//  pixel row zero, so the glass never runs out of photograph.
// ════════════════════════════════════════════════════════════════

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.selecting,
    required this.picked,
    required this.onTap,
    required this.bottomInset,
  });

  final List<int> photos;
  final bool selecting;
  final Set<int> picked;
  final ValueChanged<int> onTap;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GridView.builder(
          // No top padding: the first row runs under the status bar and
          // the title, which is what the glass header sits on.
          padding: EdgeInsets.only(bottom: bottomInset + 108),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: photos.length,
          itemBuilder: (context, i) {
            final int id = photos[i];
            return _PhotoCell(
              id: id,
              selecting: selecting,
              picked: picked.contains(id),
              onTap: () => onTap(id),
            );
          },
        ),
        // The scrim the title reads against — and one more thing for the
        // top controls to bend, so their rim shows even over a blown-out
        // sky.
        const IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 230,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x8C000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.id,
    required this.selecting,
    required this.picked,
    required this.onTap,
  });

  final int id;
  final bool selecting;
  final bool picked;
  final VoidCallback onTap;

  /// Muted fills shown while a photo loads (and if it never arrives), so
  /// an offline run still reads as a mosaic instead of broken tiles.
  static const List<Color> _placeholders = [
    Color(0xFF23262B),
    Color(0xFF2B2A33),
    Color(0xFF1F2A2E),
    Color(0xFF2E2724),
    Color(0xFF262B24),
  ];

  @override
  Widget build(BuildContext context) {
    final Color fill = _placeholders[id % _placeholders.length];

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: fill),
          Image.network(
            'https://picsum.photos/seed/glass$id/320/320',
            fit: BoxFit.cover,
            // The grid never shows a cell wider than a third of the
            // screen, so decoding beyond this is wasted memory.
            cacheWidth: 320,
            errorBuilder: (_, __, ___) => ColoredBox(color: fill),
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: child,
              );
            },
          ),
          if (selecting) ...[
            if (picked)
              const ColoredBox(color: Color(0x59000000)),
            Positioned(
              right: 5,
              bottom: 5,
              child: _PickBadge(picked: picked),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickBadge extends StatelessWidget {
  const _PickBadge({required this.picked});

  final bool picked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: picked ? _kTint : const Color(0x40000000),
        border: Border.all(
          color: picked ? _kTint : const Color(0xCCFFFFFF),
          width: 1.4,
        ),
      ),
      child: picked
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}
