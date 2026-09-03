// -----------------------------------------------------------------------------
// MORPH MENU — the button becomes the menu.
//
// iOS 26's morph transition, the one Apple describes as: "When a presentation,
// like a menu or a popover, is originated from a glass button, the button
// morphs into the overlay. This maintains visual continuity between the source
// and the presentation throughout the animation."
//
// So a menu is not a panel that appears OVER a button. There is one piece of
// glass, and its outline travels from the button's shape to the list's shape.
// Nothing fades in on top of anything.
//
// SwiftUI names three transitions for glass — `GlassEffectTransition.identity`,
// `.matchedGeometry` (the default) and `.materialize` — and the mode chip is
// those three, so they can be told apart instead of guessed at:
//
//   MORPH   One lens. Its rect springs from the button's to the panel's, and
//           its corner radius from a capsule's to a card's. The ••• glyph
//           cross-fades out as the rows cross-fade in, INSIDE the same glass.
//           The button is gone while the menu is open, because the button IS
//           the menu. This is the transition Apple's menus get automatically.
//
//   POUR    Two lenses in a LiquidGlassBlender. The button stays put and the
//           panel grows out of it as a separate member, so the metaball bridges
//           them: the glass visibly pours out of the button and the neck
//           stretches and thins as the panel pulls away. This is the container
//           blending — SwiftUI's GlassEffectContainer `spacing`, our
//           `smoothness` — which is what makes a menu read as having come from
//           one mass rather than several views.
//
//   MATER-  `.materialize`. The panel does NOT change shape at all: it is
//   IALIZE  already its full size, parked where a menu goes. What animates is
//           the MATERIAL — Apple's wording is that the element "appears by
//           gradually modulating light bending", so the refraction depth, the
//           refraction width, the blur, the tint and the rim all ramp from
//           nothing to full. At the start the glass is geometrically all there
//           and optically absent. This is the one people reach for a plain
//           opacity fade to fake; a fade dims what is BEHIND the glass too,
//           and this does not.
//
// The press response on the buttons is SwiftUI's `.interactive()` — the glass
// scales under a finger and pops on release. Here that is the package's own
// flex (`holdScale` for the hold, `tapScale` for the click).
//
// WHAT ANCHORS IT
//   The panel's bottom-right corner is pinned to the button's bottom-right and
//   the panel grows up and to the left from there. Only WIDTH, HEIGHT and
//   RADIUS are sprung; position falls out of the anchor. That is why the menu
//   never appears to slide — the corner it grew from never moves, which is the
//   single most important detail in making it read as one continuous surface.
//
//   The rows are laid out at the panel's FULL size from the first frame and
//   simply clipped by the growing outline (the lens clips its own child), so
//   nothing reflows mid-morph. They stagger in on the open progress, not on a
//   timer, so they stay in step with the springs at any speed.
//
//   flutter run -t lib/morph_menu_page.dart   (standalone)
//   …or open it from the gallery.
// -----------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'spring.dart';

void main() {
  runApp(const _MorphMenuApp());
}

class _MorphMenuApp extends StatelessWidget {
  const _MorphMenuApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MorphMenuPage(),
    );
  }
}

/// Which of the two mechanisms is on show. See the file header.
enum MorphMenuMode { morph, pour, materialize }

/// One row of the menu.
class _Item {
  const _Item(this.icon, this.label, {this.destructive = false});

  final IconData icon;
  final String label;
  final bool destructive;
}

class MorphMenuPage extends StatefulWidget {
  const MorphMenuPage({super.key});

  @override
  State<MorphMenuPage> createState() => _MorphMenuPageState();
}

class _MorphMenuPageState extends State<MorphMenuPage>
    with SingleTickerProviderStateMixin {
  static const String _wallpaper =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  static const List<_Item> _items = <_Item>[
    _Item(Icons.push_pin_outlined, 'Pin to top'),
    _Item(Icons.drive_file_rename_outline_rounded, 'Rename'),
    _Item(Icons.ios_share_rounded, 'Share'),
    _Item(Icons.folder_copy_outlined, 'Move to…'),
    _Item(Icons.info_outline_rounded, 'Get info'),
    _Item(Icons.delete_outline_rounded, 'Delete', destructive: true),
  ];

  static const double _button = 52;
  static const double _rowHeight = 46;
  static const double _panelPadV = 9;
  static const double _panelRadius = 26;
  static const double _gap = 14;

  /// The droplet the poured panel starts life as. Not zero: a zero-sized
  /// member has no field at all, so there would be nothing for the metaball to
  /// bridge to and the neck would start already broken.
  static const double _seed = 14;

  // Apple's own menu sample animates with `.bouncy(duration: 0.4)`. SwiftUI's
  // Spring(duration:bounce:) puts ω at 2π/duration, so k = ω² = 247, and its
  // bounce maps to ζ = 1 − bounce. iOS 26.2 explicitly made these menus
  // BOUNCIER than 26.0/26.1, so this sits at bounce ≈ 0.4 (ζ ≈ 0.6) rather
  // than `.bouncy`'s stock 0.3.
  static const double _stiffness = 247;
  static const double _damping = 19;

  /// The press response — SwiftUI's `.glassEffect(.regular.interactive())`,
  /// which scales the glass under a finger and pops it on release. The
  /// package's flex owns both: [LiquidGlassFlex.holdScale] is the hold,
  /// [LiquidGlassFlex.tapScale] the click.
  static const LiquidGlassTouch _press = LiquidGlassTouch.flexing(
    LiquidGlassFlex(stretch: 7, lean: 0.2, holdScale: 0.045, tapScale: 0.03),
  );

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// The panel's outline. Position is not sprung — see the header.
  final Spring _w = Spring(_button);
  final Spring _h = Spring(_button);
  final Spring _r = Spring(_button / 2);

  /// How present the GLASS is, 0…1 — the material transition, separate from
  /// the geometric one. At 0 the surface bends no light at all: no refraction,
  /// no blur, no tint, no rim. Only MATERIALIZE drives this away from 1; the
  /// other two modes keep the material at full strength and morph the shape,
  /// which is exactly the distinction SwiftUI draws between
  /// `.matchedGeometry` and `.materialize`.
  final Spring _material = Spring(1);

  bool _open = false;
  MorphMenuMode _mode = MorphMenuMode.morph;
  bool _slow = false;
  String? _picked;

  Size _stage = Size.zero;
  bool _seeded = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Geometry ─────────────────────────────────────────────────────

  double get _panelWidth => math.min(_stage.width - 40, 268);

  double get _panelHeight => _items.length * _rowHeight + _panelPadV * 2;

  /// The bottom-right corner everything is pinned to: the "more" button's.
  Offset get _anchor => Offset(
        _stage.width - 20,
        _stage.height - 26,
      );

  /// The "more" button, whether or not it is currently drawn.
  Rect get _moreRect => Rect.fromLTWH(
        _anchor.dx - _button,
        _anchor.dy - _button,
        _button,
        _button,
      );

  /// How far POUR lifts the panel clear of the button once fully open.
  ///
  /// Without this the panel's bottom edge would stay welded to the button's
  /// top edge and the two would simply be one shape the whole way — there
  /// would be no neck to stretch. Driven off [_progress] rather than a spring
  /// of its own, so it cannot drift out of step with the outline.
  static const double _pourLift = 24;

  /// Where the panel's own anchor sits.
  ///
  /// In MORPH the panel IS the button, so it shares the button's corner
  /// exactly and never moves. In POUR it starts ON the button's top edge —
  /// touching, so the metaball has them fused from the first frame — and rises
  /// away as it opens, drawing the neck out behind it.
  Offset get _panelAnchor => switch (_mode) {
        MorphMenuMode.morph => _moreRect.bottomRight,
        MorphMenuMode.pour =>
          Offset(_moreRect.right, _moreRect.top - _pourLift * _progress),
        // Nothing about MATERIALIZE moves, so it parks where an ordinary menu
        // would: clear of the button, by the same gap the toolbar uses.
        MorphMenuMode.materialize =>
          Offset(_moreRect.right, _moreRect.top - _gap),
      };

  Rect get _panelRect {
    final Offset a = _panelAnchor;
    return Rect.fromLTRB(
      a.dx - _w.value,
      a.dy - _h.value,
      a.dx,
      a.dy,
    );
  }

  /// The shape the panel rests at when closed.
  ///
  /// MATERIALIZE is the odd one out: it does not shrink at all. SwiftUI's
  /// `.glassEffectTransition(.materialize)` is a MATERIAL transition, not a
  /// geometric one — the element is already its full size and instead
  /// "appears by gradually modulating light bending". So the geometry rests
  /// where it ends and [_material] carries the whole transition.
  double get _closedW => switch (_mode) {
        MorphMenuMode.morph => _button,
        MorphMenuMode.pour => _seed,
        MorphMenuMode.materialize => _panelWidth,
      };

  double get _closedH => switch (_mode) {
        MorphMenuMode.morph => _button,
        MorphMenuMode.pour => _seed,
        MorphMenuMode.materialize => _panelHeight,
      };

  double get _closedR =>
      _mode == MorphMenuMode.materialize ? _panelRadius : _closedW / 2;

  /// How far open the panel is, 0…1.
  ///
  /// Measured off the HEIGHT spring rather than a separate clock, so the
  /// contents can never drift out of step with the outline — including when
  /// the spring overshoots, where this legitimately exceeds 1 and is clamped.
  /// In MATERIALIZE the height never changes, so it falls back to [_material],
  /// which is the only thing moving there.
  double get _progress {
    final double span = _panelHeight - _closedH;
    if (span.abs() < 1) return _material.value;
    return ((_h.value - _closedH) / span).clamp(0.0, 1.0);
  }

  void _aim() {
    _w.target = _open ? _panelWidth : _closedW;
    _h.target = _open ? _panelHeight : _closedH;
    _r.target = _open ? _panelRadius : _closedR;
    _material.target = _mode == MorphMenuMode.materialize ? (_open ? 1 : 0) : 1;
    _wake();
  }

  void _toggle() => setState(() {
        _open = !_open;
        if (_open) _picked = null;
        _aim();
      });

  void _pick(_Item item) => setState(() {
        _picked = item.label;
        _open = false;
        _aim();
      });

  void _setMode(MorphMenuMode m) => setState(() {
        _mode = m;
        // The two modes close to different shapes, so re-aim rather than leave
        // the springs pointed at the other mode's rest.
        _aim();
      });

  // ── Integration ──────────────────────────────────────────────────

  void _wake() {
    if (!_ticker.isActive) {
      // Ticker.elapsed restarts at zero, so the baseline must too — otherwise
      // the first step after a pause integrates the whole gap at once.
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;
    if (_slow) dt *= 0.25;

    _w.step(dt, _stiffness, _damping);
    _h.step(dt, _stiffness, _damping);
    // The radius rides a stiffer, calmer spring: a corner that overshoots as
    // hard as the box visibly pumps on arrival, and unlike the box there is no
    // volume to justify it.
    _r.step(dt, _stiffness * 1.4, _damping * 1.3);
    // Critically damped: light bending that overshoots reads as a flicker,
    // not as a material arriving.
    _material.step(dt, _stiffness, 2 * math.sqrt(_stiffness));

    if (_w.moving || _h.moving || _r.moving || _material.moving || _dirty) {
      _dirty = false;
      setState(() {});
    } else {
      // Settled. Stop asking for frames rather than waking the engine every
      // vsync to find nothing to do; _wake() starts it again.
      _ticker.stop();
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Morph menu'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _wallpaper),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              _syncStage(Size(c.maxWidth, c.maxHeight));
              return _buildStage();
            },
          ),
        ),
      ),
    );
  }

  /// Called from inside `build`, so it must not `setState` — it marks the
  /// frame dirty and lets the ticker repaint instead.
  void _syncStage(Size stage) {
    if (stage == _stage) return;
    _stage = stage;
    _w.target = _open ? _panelWidth : _closedW;
    _h.target = _open ? _panelHeight : _closedH;
    _r.target = _open ? _panelRadius : _closedR;
    _material.target = _mode == MorphMenuMode.materialize ? (_open ? 1 : 0) : 1;
    if (!_seeded) {
      // Opening the page is not itself a morph.
      _seeded = true;
      _w.snap();
      _h.snap();
      _r.snap();
      _material.snap();
    }
    _dirty = true;
    _wake();
  }

  Widget _buildStage() {
    final double p = _progress;
    final bool morph = _mode == MorphMenuMode.morph;

    final LiquidGlassStyle glass = LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: _r.value,
        borderWidth: 1.4,
      ),
      appearance: const LiquidGlassAppearance(
        color: Color(0x1FFFFFFF),
        saturation: 1.06,
        blur: LiquidGlassBlur(sigmaX: 7, sigmaY: 7),
      ),
      refraction: const LiquidGlassRefraction(
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: 22,
          depth: 0.5,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Dismiss layer. Always mounted, just inert while closed, so the child
        // list length never changes — a conditional child here would shift
        // every sibling's index and remount the blender below, which reloads
        // its shader and flashes the glass for a frame.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _open ? _toggle : null,
              child: const SizedBox.expand(),
            ),
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(child: _caption()),
        ),

        // The glass. One blender either way: in MORPH its members never touch,
        // so `smoothness: null` unions them hard and each keeps its own
        // outline; in POUR the smoothness is what grows the neck.
        Positioned.fill(
          child: LiquidGlassBlender(
            smoothness: morph ? null : 46,
            style: glass,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _sideButton(Icons.ios_share_rounded, 2),
                _sideButton(Icons.star_border_rounded, 1),
                // POUR and MATERIALIZE both keep the source button. Only
                // MORPH drops it, because there the button and the panel are
                // the same piece of glass.
                if (!morph) _moreButton(),
                _panel(p, morph),
              ],
            ),
          ),
        ),

        // The rows' tap targets, over the panel at its FULL size. Inert until
        // the panel has essentially arrived, so a tap during the morph cannot
        // land on a row that is not yet under the finger.
        Positioned.fromRect(
          rect: Rect.fromLTWH(
            _panelAnchor.dx - _panelWidth,
            _panelAnchor.dy - _panelHeight,
            _panelWidth,
            _panelHeight,
          ),
          child: IgnorePointer(
            ignoring: !_open || p < 0.9,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _panelPadV),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final _Item item in _items)
                    SizedBox(
                      height: _rowHeight,
                      child: GestureDetector(
                        // Keyed: the visible label lives in the glass subtree
                        // under an IgnorePointer, so a test tapping the TEXT
                        // would land here and warn about a missed hit test.
                        key: ValueKey<String>('row-${item.label}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pick(item),
                        child: const SizedBox.expand(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // MORPH's closed panel IS the source button, so it needs the tap. The
        // other two modes have a real button that owns its own, inside the
        // glass subtree where the press response can reach the pointer.
        if (morph && !_open)
          Positioned.fromRect(
            rect: _moreRect,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: const SizedBox.expand(),
            ),
          ),

        Positioned(left: 0, right: 0, bottom: 0, child: _controls()),
      ],
    );
  }

  /// A neighbour in the toolbar, [slot] places to the left of the anchor.
  Widget _sideButton(IconData icon, int slot) {
    final Rect r = _moreRect.translate(-(slot * (_button + _gap)), 0);
    return Positioned.fromRect(
      rect: r,
      // NOT wrapped in IgnorePointer: the press response needs the pointer.
      child: KeyedSubtree(
        key: ValueKey<String>('menu-side-$slot'),
        child: LiquidGlassLens(
          touch: _press,
          style: const LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: _button / 2,
              borderWidth: 1.4,
            ),
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 22)),
        ),
      ),
    );
  }

  Widget _moreButton() {
    return Positioned.fromRect(
      rect: _moreRect,
      // The lens handles the press itself, so the tap lives here rather than
      // on a separate layer above the glass — a GestureDetector is opaque to
      // its SIBLINGS, not to its own child, so the flex still sees the finger.
      child: GestureDetector(
        key: const ValueKey<String>('menu-more'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: LiquidGlassLens(
          touch: _press,
          style: const LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: _button / 2,
              borderWidth: 1.4,
            ),
          ),
          child: const Center(
            child:
                Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  /// The morphing surface itself.
  Widget _panel(double p, bool morph) {
    return Positioned.fromRect(
      rect: _panelRect,
      child: IgnorePointer(
        // Keyed so a test can measure the OUTLINE, which is the whole point of
        // this page. The lens element's own renderObject is an inner box.
        key: const ValueKey<String>('menu-panel'),
        // Pointers go to the row layer above; this is glass only.
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: math.min(
                _r.value,
                math.min(_w.value, _h.value) / 2,
              ),
              // The rim is part of the material, so it materialises too. A
              // full-strength outline around a surface that bends no light is
              // the giveaway that a "materialize" is really just a fade.
              borderWidth: 1.4 * _material.value,
            ),
            appearance: LiquidGlassAppearance(
              color: Color.lerp(
                const Color(0x00FFFFFF),
                const Color(0x1FFFFFFF),
                _material.value,
              )!,
              saturation: 1 + 0.06 * _material.value,
              blur: LiquidGlassBlur(
                sigmaX: 7 * _material.value,
                sigmaY: 7 * _material.value,
              ),
            ),
            // The heart of `.materialize`: Apple's own wording is that the
            // element "appears by gradually modulating light bending", so it
            // is the REFRACTION that ramps, not an opacity. At depth 0 the
            // glass is optically absent while being geometrically all there.
            refraction: LiquidGlassRefraction(
              refractionType: OpticalRefraction(
                refraction: 1.5,
                refractionWidth: 22 * _material.value,
                depth: 0.5 * _material.value,
              ),
            ),
          ),
          // The lens clips its own child to the outline it draws, so the
          // content only has to refuse to reflow.
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // MORPH only: the ••• glyph the panel grew out of. It leaves
              // fast — by a third of the way open it is gone, so it never
              // fights the rows for the same pixels.
              if (morph && p < 0.4)
                Opacity(
                  opacity: (1 - p * 2.6).clamp(0.0, 1.0),
                  child: const Icon(Icons.more_horiz_rounded,
                      color: Colors.white, size: 24),
                ),
              // Laid out at the FULL panel size from the first frame and
              // clipped by the growing outline — nothing here reflows.
              OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  width: _panelWidth,
                  height: _panelHeight,
                  child: _rows(p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The list. Each row keys off the OPEN PROGRESS, not a timer, so the
  /// stagger stays in step with the springs at any speed — including while the
  /// panel is springing back closed.
  Widget _rows(double p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _panelPadV),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < _items.length; i++)
            _row(_items[i], _rowReveal(p, i)),
        ],
      ),
    );
  }

  /// 0…1 for row [i]. Rows nearest the anchor lead, because that end of the
  /// panel exists first — a stagger running the other way would put rows in
  /// space the glass has not reached yet.
  double _rowReveal(double p, int i) {
    final int fromAnchor = _items.length - 1 - i;
    const double each = 0.055;
    const double ramp = 0.28;
    final double start = 0.18 + fromAnchor * each;
    return ((p - start) / ramp).clamp(0.0, 1.0);
  }

  Widget _row(_Item item, double t) {
    final Color ink = item.destructive
        ? const Color(0xFFFF6B6B)
        : Colors.white.withValues(alpha: 0.96);
    return SizedBox(
      height: _rowHeight,
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          // Scales up as it arrives, not just fades. A row that only fades
          // reads as a layer switched on above the glass; one that grows into
          // place reads as part of what the glass is doing.
          scale: 0.92 + 0.08 * t,
          child: Transform.translate(
            // Slides in from the anchor side, a short distance — the panel is
            // doing the travelling, the rows only have to arrive.
            offset: Offset(0, (1 - t) * 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(item.icon, color: ink, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What was last chosen, so the menu demonstrably does something.
  Widget _caption() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 70),
        child: Text(
          _picked == null ? 'Tap •••' : '“$_picked”',
          style: TextStyle(
            color:
                Colors.white.withValues(alpha: _picked == null ? 0.55 : 0.95),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Controls ─────────────────────────────────────────────────────

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final MorphMenuMode m in MorphMenuMode.values)
                _Chip(
                  label: m.name,
                  on: _mode == m,
                  onTap: () => _setMode(m),
                ),
              _Chip(
                label: '0.25×',
                on: _slow,
                onTap: () => setState(() => _slow = !_slow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chrome ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? const Color(0xFF11131A) : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The refractable photo captured by [LiquidGlassView].
class _Background extends StatelessWidget {
  const _Background({required this.url});

  final String url;

  static const DecoratedBox _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF2E1065),
          Color(0xFF0EA5E9),
          Color(0xFFF59E0B),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? progress,
          ) {
            if (progress == null) return child;
            return const Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _fallback,
                Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x22000000), Color(0x55000000)],
            ),
          ),
        ),
      ],
    );
  }
}
