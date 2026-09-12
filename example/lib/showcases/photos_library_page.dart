import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this showcase can be launched directly with:
///   flutter run -t lib/showcases/photos_library_page.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Both brightnesses, because the page paints from the theme: what
      // shows past the grid is `scaffoldBackgroundColor`, so the two
      // entries below are the only place the page's backdrop is chosen.
      // From the gallery it is that app's theme instead.
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFD7D5D5),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101012),
      ),
      themeMode: ThemeMode.system,
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
//     stay legible as bright and dark photos scroll under them;
//   • the filter circle is not a button that opens a menu, it BECOMES
//     one — `LiquidGlassMorph` on the `fluid` preset, so the same piece
//     of glass leaps down-left into the list and drains back into the
//     circle. Nothing fades in over anything.
//
// The whole page is one `LiquidGlassScaffold`: the grid is the `body`
// every lens refracts, the header goes in `appBar`, the tab capsule in
// `bottomNavigationBar` and search in `bottomNavigationBarAction` —
// which pins the circle to the capsule's baseline, safe area included.
// The page's own surface — all that shows past the grid — comes from
// the app theme, so the whole thing follows light and dark.
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
  continuousGlassColor: true,
);

/// The title has no frost to hide in, so the ink is what adapts here —
/// the exact opposite of [_adapt]. Bare text over a photograph only
/// survives by inverting, white over a dark frame and near-black over a
/// bright one, which is why the glass palettes above cannot be reused
/// for it.
const LiquidGlassAdaptivity _titleAdapt = LiquidGlassAdaptivity(
  contentColorOnDark: Color(0xFFFFFFFF),
  contentColorOnLight: _kInk,
  duration: Duration(milliseconds: 300),
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
  bool _menuOpen = false;

  /// True from the frame the menu is asked to open or close until the
  /// morph's `onEnd`. While it is up the menu cannot be toggled again, so
  /// the glass always finishes becoming one thing before it is asked to
  /// become the other.
  bool _morphing = false;
  final Set<int> _picked = <int>{};

  /// What the filter menu offers. The count is the library's headline
  /// number; the step is what the grid actually shows, so the two agree
  /// as you pick.
  static const List<(String, String, int, IconData)> _filters = [
    ('Items', '4,627', 1, Icons.photo_library_outlined),
    ('Favorites', '318', 3, Icons.favorite_border_rounded),
    ('Videos', '96', 4, Icons.videocam_outlined),
    ('Screenshots', '211', 5, Icons.crop_free_rounded),
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
    final (String name, String count, _, _) = _filters[_filter];
    return '$count $name';
  }

  /// Opens or closes the menu — the only place [_menuOpen] changes, so
  /// the morph lock is applied to every path. A request that lands while
  /// the glass is still in flight is dropped, not queued.
  void _setMenu(bool open) {
    if (_morphing || open == _menuOpen) return;
    setState(() {
      _menuOpen = open;
      _morphing = true;
    });
  }

  void _onMorphEnd() {
    if (_morphing) setState(() => _morphing = false);
  }

  /// Picking a row changes the filter and leaves the menu up: the grid
  /// re-flows behind it, and the tap outside is what puts it away.
  void _pickFilter(int index) => setState(() {
        _filter = index;
        _picked.clear();
      });

  void _toggleSelecting() => setState(() {
        // A menu is modal: choosing the other control puts it away, the
        // way tapping past it does — unless the glass is mid-morph, in
        // which case the menu stays where it is until it has settled.
        if (_menuOpen && !_morphing) {
          _menuOpen = false;
          _morphing = true;
        }
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
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    // A plain Scaffold underneath, purely so the search snack bar has
    // somewhere to land — `ScaffoldMessenger` presents into a registered
    // Scaffold, and the glass one is not a Material Scaffold. It paints
    // the theme's surface and nothing else; the glass scaffold covers it.
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: LiquidGlassScaffold(
        pixelRatio: 1,
        useSync: true,
        // The page's own surface, which shows on overscroll and past the
        // last row — so it comes from the app theme rather than a colour
        // pinned here, and the grid sits on paper in the light and on
        // near-black in the dark.
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actionMargin: _edge,
        // Every glass slot below — header controls, the tab capsule,
        // the search circle — inherits these palettes and judges the
        // photographs behind ITSELF, so nothing here has to be told
        // about the grid.
        //
        // The grid runs edge to edge under BOTH system bars, so each one
        // gets a strip: the scaffold samples that band and drives the
        // OS icon brightness from it. The strips judge only the bars —
        // the glass chrome above still judges its own backdrop, so the
        // two can legitimately disagree.
        adaptivity: const LiquidGlassScaffoldAdaptivity(
          _adapt,
          systemChrome: LiquidGlassSystemChrome.both,
        ),

        // ── the photographs, edge to edge and under everything ─────
        body: _PhotoGrid(
          photos: _photos,
          selecting: _selecting,
          picked: _picked,
          onTap: _tapCell,
          bottomInset: pad.bottom,
        ),

        // ── tap anywhere else to put the menu away ─────────────────
        //
        // In `lenses`, so it sits ABOVE the grid but BELOW the app bar:
        // the menu and the Select pill still get their taps, everything
        // else — photographs, the title, the bars — closes it. It also
        // stops a scroll from starting under an open menu, which is what
        // makes it read as modal.
        //
        // Here rather than in `body` because this layer is outside the
        // capture the lenses refract, so an open menu costs no repaint of
        // the page behind it.
        lenses: [
          if (_menuOpen)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setMenu(false),
            ),
        ],

        // ── title + the two top controls ───────────────────────────
        appBar: _LibraryHeader(
          subtitle: _subtitle,
          selecting: _selecting,
          filters: _filters,
          filter: _filter,
          menuOpen: _menuOpen,
          onMenu: () => _setMenu(true),
          onMorphEnd: _onMorphEnd,
          onPickFilter: _pickFilter,
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
            // Travelling, the pill carries almost no tint — over a
            // capsule this pale, a fill would only mud it. It is the
            // refraction of the bar's own frost that reads as movement.
            //
            // Where it lands: the lighter capsule of the reference, a
            // lift of white on white.
            rest: LiquidGlassStyle(
              shape: _frostShape(50),
              appearance: const LiquidGlassAppearance(
                color: Color.fromARGB(40, 0, 0, 0),
              ),
            ),
          ),
        ),

        // ── search, on its own glass ───────────────────────────────
        bottomNavigationBarAction: LiquidGlassTabBarAction(
          icon: Icons.search_rounded,
          size: _barHeight,
          onTap: _search,
          touch: _press,
          style: _frost(_barHeight / 2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The header — a plain title over the photographs, and two glass
//  controls beside it. One of them is a menu that has not opened yet.
//
//  A Stack rather than a Row, because the filter control has to be
//  able to grow to the size of its open menu WITHOUT moving the Select
//  pill or squeezing the title. Each piece is placed against an edge
//  that never moves, and the morph's box is pinned by its RIGHT edge —
//  the circle's own right edge — so widening it opens the menu
//  leftward instead of pushing its neighbour.
// ════════════════════════════════════════════════════════════════

class _LibraryHeader extends StatefulWidget {
  const _LibraryHeader({
    required this.subtitle,
    required this.selecting,
    required this.filters,
    required this.filter,
    required this.menuOpen,
    required this.onMenu,
    required this.onMorphEnd,
    required this.onPickFilter,
    required this.onSelect,
  });

  final String subtitle;
  final bool selecting;
  final List<(String, String, int, IconData)> filters;
  final int filter;
  final bool menuOpen;
  final VoidCallback onMenu;

  /// The morph's `onEnd`, passed up so the page can lift its morph lock.
  final VoidCallback onMorphEnd;
  final ValueChanged<int> onPickFilter;
  final VoidCallback onSelect;

  static const double _controlHeight = 44;
  static const double _left = 20;
  static const double _right = 16;
  static const double _top = 2;

  /// The gap between the two top controls, and the Select pill's width.
  /// Select is pinned rather than measured so the morph's box can be
  /// placed against the circle's right edge with arithmetic instead of
  /// a layout pass — and so 'Select' and 'Done' do not resize the row.
  static const double _gap = 10;
  static const double _selectWidth = 88;

  /// As wide as the menu gets. Narrower on a small screen, so it never
  /// runs off the left edge.
  static const double _menuMaxWidth = 240;

  @override
  State<_LibraryHeader> createState() => _LibraryHeaderState();
}

class _LibraryHeaderState extends State<_LibraryHeader> {
  /// Whether the morph's BOX is menu-sized. Not the same question as
  /// "is the menu open": the box has to already be big on the frame the
  /// glass starts growing, and has to stay big until the glass has
  /// finished draining back into the circle — so it goes up with
  /// [_LibraryHeader.menuOpen] and comes down on the morph's `onEnd`.
  ///
  /// Shrinking it back matters: the box is what the glass judges its
  /// backdrop over, so a permanently menu-sized box would have the
  /// closed circle reading a slab of photographs it does not cover.
  bool _wide = false;

  @override
  void didUpdateWidget(covariant _LibraryHeader old) {
    super.didUpdateWidget(old);
    // No setState: this runs inside the rebuild that opened the menu.
    if (widget.menuOpen) _wide = true;
  }

  double get _menuHeight => _FilterMenu.heightFor(widget.filters.length);

  /// Distance from the header's right edge to the filter circle's right
  /// edge — which is the edge the morph's box is pinned by, and the
  /// corner the glass grows out of.
  static const double _fieldRight = _LibraryHeader._right +
      _LibraryHeader._selectWidth +
      _LibraryHeader._gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double ctrl = _LibraryHeader._controlHeight;
        final double menuWidth = math.min(
          _LibraryHeader._menuMaxWidth,
          constraints.maxWidth - _fieldRight - 12,
        );

        return SizedBox(
          // Tight width so the two pinned controls resolve against the
          // screen and not against the title's own width. The height is
          // the menu's while it is open, and otherwise whatever the title
          // — the tallest thing here — comes to.
          width: constraints.maxWidth,
          height: _wide ? _LibraryHeader._top + _menuHeight : null,
          // The blender pads its own bounds to fit the neck and the
          // spring's overshoot, and that padding is allowed to leave
          // the header.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── the title, held clear of both controls ──────────
              //
              // Not positioned, on purpose: it is what gives the header
              // its height while the menu is shut.
              Padding(
                padding: EdgeInsets.only(
                  left: _LibraryHeader._left,
                  top: _LibraryHeader._top,
                  right: _fieldRight + ctrl + 14,
                ),
                child: _Title(subtitle: widget.subtitle),
              ),

              // ── Select, pinned to the right edge ────────────────
              Positioned(
                right: _LibraryHeader._right,
                top: _LibraryHeader._top,
                child: LiquidGlassButton(
                  width: _LibraryHeader._selectWidth,
                  height: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: widget.onSelect,
                  touch: _press,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  style: _frost(ctrl / 2),
                  // The label as a `child` rather than `label:`, because a
                  // pinned width has to be able to clip: the built-in row
                  // sizes to the text and overflows a large text scale.
                  // Size, weight and the adapted ink still come from the
                  // button — they arrive as ambient style.
                  child: Text(
                    widget.selecting ? 'Done' : 'Select',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),

              // ── the filter control, and the menu it becomes ─────
              //
              // The box is pinned by its right edge and its top, so both
              // sizes share one top-right corner: resizing it moves
              // nothing, and the glass anchored to that corner simply has
              // more room to open into. `fluid` is the preset where the
              // new shape's centre leaves first and its size follows, so
              // the menu pulls a neck out of the circle on the way down
              // and the circle drains after it.
              Positioned(
                top: _LibraryHeader._top,
                right: _fieldRight,
                width: _wide ? menuWidth : ctrl,
                height: _wide ? _menuHeight : ctrl,
                child: LiquidGlassMorph(
                  alignment: Alignment.topRight,
                  motion: LiquidGlassMorphMotion.fluid,
                  smoothness: 28,
                  // The shape of the DESTINATION: a circle while it is a
                  // button, a card once it is a menu. The same frost as
                  // every other surface on the page.
                  style: _frost(widget.menuOpen ? 28 : ctrl / 2),
                  onEnd: () {
                    if (_wide != widget.menuOpen) {
                      setState(() => _wide = widget.menuOpen);
                    }
                    widget.onMorphEnd();
                  },
                  // Keys: without them a swap is not seen as one, and the
                  // glass would resize instead of morph.
                  child: widget.menuOpen
                      ? _FilterMenu(
                          key: const ValueKey<String>('menu'),
                          width: menuWidth,
                          filters: widget.filters,
                          active: widget.filter,
                          onPick: widget.onPickFilter,
                        )
                      : _FilterGlyph(
                          key: const ValueKey<String>('glyph'),
                          size: ctrl,
                          onTap: widget.onMenu,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The two lines of bare text over the photographs.
class _Title extends StatelessWidget {
  const _Title({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // Ignoring the pointer is what lets a drag that starts on the title
    // scroll the grid underneath it — text hit-tests itself, and this
    // layer sits above the photos.
    return IgnorePointer(
      // Both lines in ONE adaptive block: the title and the count under
      // it are a single region of bare text, so they sample together and
      // flip together — the glass beside them keeps judging its own
      // backdrop. The builder form is what lets the halo flip with the
      // ink; a plain child only gets the colour.
      child: LiquidGlassAdaptiveContent(
        adaptivity: _titleAdapt,
        builder: (context, color, brightness) {
          // The lift the text sits on. It has to invert with the ink — a
          // dark halo under light letters, a light one under dark — or
          // the type loses its edge exactly where a photograph disagrees
          // with the verdict in patches.
          final Color halo = brightness == Brightness.dark
              ? const Color(0x73000000)
              : const Color(0x8CFFFFFF);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library',
                style: TextStyle(
                  color: color,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.15,
                  shadows: [Shadow(color: halo, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                // The count is the quiet line: the same adapted ink, held
                // back rather than given a colour of its own.
                style: TextStyle(
                  color: color.withValues(alpha: color.a * 0.82),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  shadows: [Shadow(color: halo, blurRadius: 10)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  What the one piece of glass holds: a glyph, or a list.
//
//  Both state their OWN size and the morph reads it — that is the
//  contract. Add a filter to the page's list and the menu grows; there
//  is no dimension anywhere to keep in sync.
//
//  Neither carries a colour: the blender publishes the group's verdict
//  as an `IconTheme` and a `DefaultTextStyle`, so the glyph and the
//  rows adapt with the frost they sit in, exactly as the page's other
//  controls do.
// ════════════════════════════════════════════════════════════════

/// The closed state: the filter glyph, and the tap that opens the menu.
///
/// The gesture is INSIDE the glass rather than wrapped around the
/// morph, because the morph fills a box the size of the OPEN menu.
/// Wrapped outside, the closed circle would be swallowing taps across
/// a slab of photographs it does not cover.
class _FilterGlyph extends StatelessWidget {
  const _FilterGlyph({super.key, required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.filter_list_rounded, size: 24),
      ),
    );
  }
}

/// The open state: one row per filter, the active one checked.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.width,
    required this.filters,
    required this.active,
    required this.onPick,
  });

  final double width;
  final List<(String, String, int, IconData)> filters;
  final int active;
  final ValueChanged<int> onPick;

  static const double _rowHeight = 46;
  static const double _vPad = 7;

  /// The height [rows] rows come to — the same arithmetic the build
  /// below performs, so the header can size the morph's box to the menu
  /// before the menu has been laid out even once.
  static double heightFor(int rows) => rows * _rowHeight + _vPad * 2;

  @override
  Widget build(BuildContext context) {
    // The group's adapted ink, so the count can be a held-back version
    // of the SAME colour the labels inherit rather than a second one.
    final Color ink = DefaultTextStyle.of(context).style.color ?? _kInk;

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _vPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < filters.length; i++)
              _FilterRow(
                filter: filters[i],
                on: i == active,
                last: i == filters.length - 1,
                ink: ink,
                onTap: () => onPick(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.on,
    required this.last,
    required this.ink,
    required this.onTap,
  });

  final (String, String, int, IconData) filter;
  final bool on;
  final bool last;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String name, String count, _, IconData icon) = filter;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: _FilterMenu._rowHeight,
        // A `DecoratedBox` paints the hairline without insetting the
        // row, so the height stays exactly what `heightFor` promised.
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(
                    bottom: BorderSide(
                      color: ink.withValues(alpha: ink.a * 0.10),
                      width: 0.6,
                    ),
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  count,
                  style: TextStyle(
                    color: ink.withValues(alpha: ink.a * 0.5),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                // The tick takes the icon's place rather than joining
                // it: one trailing mark per row, the way a menu that
                // picks exactly one thing should read.
                Icon(
                  on ? Icons.check_rounded : icon,
                  size: 19,
                  color: on ? _kTint : null,
                ),
              ],
            ),
          ),
        ),
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
