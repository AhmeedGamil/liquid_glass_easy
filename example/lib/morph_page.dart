// -----------------------------------------------------------------------------
// MORPH — one sheet of glass that changes its SHAPE and its DIMENSIONS.
//
// Morphing is the motion at the heart of the iOS 26 glass language: a control
// does not cross-fade into another control and it does not slide a new panel
// over the old one. There is one piece of glass on screen, and it *reshapes* —
// a round button stretches into a capsule, the capsule widens into a search
// field, the field grows down into a card, the card opens into a full panel.
// The surface is continuous the whole way; only its outline moves.
//
// WHAT MAKES IT READ AS LIQUID (and not as a resized box)
//
//   1. WIDTH AND HEIGHT ARE INDEPENDENT SPRINGS. Two springs settle at
//      slightly different times, so the outline arrives in two beats instead
//      of one. A single tween moves both axes in lockstep and reads as a box
//      being scaled.
//   2. THE SPRINGS OVERSHOOT. The glass passes its destination and comes
//      back. That tiny rebound is the whole difference between "liquid" and
//      "animated" — flip the spring/eased chip to see it removed and nothing
//      else changed.
//   3. SQUASH AND STRETCH. While one axis is moving fast the other pinches
//      in, the way a volume of liquid does. Coupled to spring VELOCITY, so it
//      appears and vanishes on its own.
//   4. THE CORNER RADIUS IS A THIRD SPRING, clamped to half the short side,
//      so short-and-wide is automatically a capsule and tall is automatically
//      a card. The radius is never keyframed per station.
//   5. THE CONTENT IS MASKED, NOT LAID OUT. Each station's content keeps its
//      natural size and is clipped by the moving outline (the lens clips its
//      own child), so nothing reflows mid-morph. It cross-fades while the
//      glass travels.
//   6. THE ANCHOR DECIDES WHICH WAY IT OPENS. A size on its own does not say
//      where the glass goes; the alignment does, and it is the difference
//      between a morph that works anywhere and one that only works in the
//      middle. Centred, both edges move and every direction looks correct —
//      which is exactly why the mistake hides there. Anchored to an edge, that
//      edge must HOLD and the glass must open away from it; grow symmetrically
//      instead and it walks across the screen or straight off it.
//      `Alignment.inscribe` applies it, and the resize grip moves to whichever
//      corner is still free — a grip parked on a pinned edge would sit still
//      while the glass grew out from under it.
//
//      THE NINE CELLS ARE A PICKER, NOT THE MECHANISM. `Alignment` is
//      continuous: `Alignment(-0.37, 0.12)` is as valid as `centerLeft`, and
//      an axis at `x` simply sends `(1 + x) / 2` of any size change out one
//      side and the rest out the other. -1 and +1 are just where one of those
//      fractions reaches zero. So there is no "not one of the nine" case to
//      handle — DRAG THE GLASS anywhere and the anchor is DERIVED from where
//      it lands, by inverting `inscribe` (see `_alignOf`). The marker in the
//      grid shows the live value between the cells, and the readout prints the
//      split it produces.
//
//      That inversion is the answer for real layouts too: an element placed by
//      something other than an alignment still has a rect, and a rect inside a
//      field implies the alignment that would have put it there.
//
// The corner STYLE (circular / squircle / Apple-continuous) is an enum, not a
// number — it cannot be interpolated. So it is swapped at the halfway point of
// the travel, where the motion hides the switch.
//
// Tap the glass to advance a station, tap a chip to jump to one, or drag the
// grip at its bottom-right corner to size it freely.
//
//   flutter run -t lib/morph_page.dart   (standalone)
//   …or open it from the gallery.
// -----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  runApp(const _MorphApp());
}

class _MorphApp extends StatelessWidget {
  const _MorphApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MorphPage(),
    );
  }
}

/// One destination of the morph: an outline (size + radius + corner curve) and
/// the content that belongs to it.
///
/// A station is only a TARGET. Nothing in the page ever renders a station
/// directly — the glass renders the springs, which chase whichever station is
/// selected. That is why the morph has no "steps": any station can go to any
/// other, and an interrupted morph just re-aims the springs mid-flight.
class _Station {
  const _Station({
    required this.name,
    required this.size,
    required this.radius,
    required this.corner,
    required this.content,
  });

  final String name;
  final Size size;
  final double radius;
  final LiquidGlassCornerStyle corner;
  final Widget content;
}

class MorphPage extends StatefulWidget {
  const MorphPage({super.key});

  @override
  State<MorphPage> createState() => _MorphPageState();
}

class _MorphPageState extends State<MorphPage>
    with SingleTickerProviderStateMixin {
  // A busy photo so the refraction has real detail to bend as the outline
  // sweeps across it — over a flat colour a morph is just a moving rectangle.
  static const String _wallpaper =
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05'
      '?auto=format&fit=crop&w=900&h=1600&q=80';

  // ── The spring bank ──────────────────────────────────────────────
  // Underdamped: ζ = c / (2·√k) ≈ 0.60, so the outline passes its target and
  // eases back. "Eased" swaps in [_dampingCalm] (ζ ≈ 1.08 — just past
  // critical), which is the SAME integrator with the wobble taken out, so the
  // A/B compares the overshoot and nothing else.
  static const double _stiffness = 250;
  static const double _dampingLiquid = 19;
  static const double _dampingCalm = 34;

  /// Speed, in px/s, that counts as "full" squash. Roughly the peak a station
  /// jump reaches, so a big morph pinches hard and a nudge barely shows.
  static const double _squashReference = 1400;

  /// Peak pinch, as a fraction of the axis. Kept small — past ~0.14 the glass
  /// stops looking like a surface and starts looking like a rubber sheet.
  static const double _squashGain = 0.10;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  // Current outline, and the velocity of each spring.
  double _w = 0, _h = 0, _r = 0;
  double _vw = 0, _vh = 0, _vr = 0;

  // Where the springs are headed.
  double _tw = 0, _th = 0, _tr = 0;

  /// Distance to the target at the moment it was set — the denominator for
  /// "how far along is this morph", which is what times the corner swap.
  double _travelStart = 0;

  int _index = 0;

  /// The corner curve currently being drawn. Lags [_index] until the morph is
  /// half done; see the file header.
  LiquidGlassCornerStyle _corner =
      LiquidGlassCornerStyle.continuousRoundedRectangle;

  /// True once the grip has been dragged: the outline no longer matches any
  /// station, so no chip is lit.
  bool _free = false;

  bool _liquid = true;
  bool _squash = true;

  /// Time dilation. The interesting part of a morph is ~400 ms long; at 0.25×
  /// the overshoot and the pinch are actually watchable.
  bool _slow = false;

  /// Where the glass is anchored, and therefore WHICH WAY it grows.
  ///
  /// This is the whole reason the morph works away from the middle. A centred
  /// morph is the easy case — both edges move, so nothing has to be decided.
  /// Anchored left, the left edge must stay put and the glass must open to the
  /// RIGHT; anchored bottom-right, that corner must stay put and it opens up
  /// and to the left. Grow symmetrically at an edge and the glass either walks
  /// across the screen or runs off it.
  Alignment _align = Alignment.center;

  /// Keeps the glass off the very edge of the stage at the extremes.
  static const double _inset = 14;

  /// Stage size from the last layout, so a tap handler can size its station
  /// without a `LayoutBuilder` of its own.
  Size _stage = Size.zero;
  bool _seeded = false;

  /// Set when layout changes the springs behind the build's back. Layout runs
  /// after the controls have already been built, so without this the readout
  /// would keep the previous frame's numbers until something else moved.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Stations ─────────────────────────────────────────────────────

  /// The five destinations, sized to the stage they have to fit in.
  ///
  /// Rebuilt on every layout rather than held in a field: on a rotation the
  /// stage changes and the targets have to follow it, and a station that
  /// remembers a stale width would morph the glass off-screen.
  List<_Station> _stations(Size stage) {
    final double wide = (stage.width - 32).clamp(220.0, 380.0);
    final double tall = (stage.height - 16).clamp(220.0, 420.0);
    return <_Station>[
      _Station(
        name: 'Dot',
        size: const Size(64, 64),
        radius: 32,
        corner: LiquidGlassCornerStyle.continuousRoundedRectangle,
        content: const _DotContent(),
      ),
      _Station(
        name: 'Pill',
        size: Size(math.min(wide, 236), 60),
        radius: 30,
        corner: LiquidGlassCornerStyle.continuousRoundedRectangle,
        content: const _PillContent(),
      ),
      _Station(
        name: 'Field',
        size: Size(wide, 68),
        radius: 26,
        corner: LiquidGlassCornerStyle.continuousRoundedRectangle,
        content: const _FieldContent(),
      ),
      _Station(
        name: 'Card',
        size: Size(wide, (tall * 0.5).clamp(170.0, 220.0)),
        radius: 40,
        corner: LiquidGlassCornerStyle.squircle,
        content: const _CardContent(),
      ),
      _Station(
        name: 'Panel',
        size: Size(wide, tall),
        radius: 28,
        corner: LiquidGlassCornerStyle.roundedRectangle,
        content: const _PanelContent(),
      ),
    ];
  }

  /// Aim the springs at station [i]. Never touches the current outline — the
  /// glass keeps whatever shape it is in and flows from there, which is what
  /// makes an interrupted morph look intentional instead of glitched.
  void _aim(int i) {
    final _Station s = _stations(_stage)[i];
    _index = i;
    _free = false;
    _tw = s.size.width;
    _th = s.size.height;
    _tr = s.radius;
    _travelStart = _distance();
    // Already there: nothing will cross the halfway mark, so take the curve now.
    if (_travelStart < 1) _corner = s.corner;
  }

  void _go(int i) => setState(() => _aim(i));

  /// How far the outline still has to travel, in px, summed over the three
  /// springs. The radius counts double: a corner change is a small number of
  /// pixels but a large amount of what the eye reads as "shape".
  double _distance() =>
      (_tw - _w).abs() + (_th - _h).abs() + (_tr - _r).abs() * 2;

  void _onTick(Duration elapsed) {
    // Clamp the step: a dropped frame or a resumed app must not launch the
    // springs across the screen in one integration.
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 30) dt = 1 / 30;
    if (_slow) dt *= 0.25;
    if (!_seeded) return;

    final double damping = _liquid ? _dampingLiquid : _dampingCalm;
    final (double nw, double nvw) = liquidGlassSpringStep(
      x: _w,
      vel: _vw,
      target: _tw,
      dt: dt,
      stiffness: _stiffness,
      damping: damping,
    );
    final (double nh, double nvh) = liquidGlassSpringStep(
      x: _h,
      vel: _vh,
      target: _th,
      dt: dt,
      stiffness: _stiffness,
      damping: damping,
    );
    // The radius rides a stiffer, calmer spring than the box. A corner that
    // overshoots as hard as the width visibly "pumps" on arrival, and unlike
    // the box there is no volume to justify it.
    final (double nr, double nvr) = liquidGlassSpringStep(
      x: _r,
      vel: _vr,
      target: _tr,
      dt: dt,
      stiffness: _stiffness * 1.4,
      damping: damping * 1.3,
    );

    final bool moving = (nw - _w).abs() > 0.01 ||
        (nh - _h).abs() > 0.01 ||
        (nr - _r).abs() > 0.01 ||
        nvw.abs() > 0.5 ||
        nvh.abs() > 0.5;

    _w = nw;
    _h = nh;
    _r = nr;
    _vw = nvw;
    _vh = nvh;
    _vr = nvr;

    // Halfway: adopt the destination's corner curve. The enum cannot be
    // interpolated, so it is swapped where the outline is moving fastest and
    // the eye is least able to catch the discontinuity.
    if (!_free && _travelStart > 1 && _distance() < _travelStart * 0.5) {
      final LiquidGlassCornerStyle want = _stations(_stage)[_index].corner;
      if (want != _corner) _corner = want;
      _travelStart = 0;
    }

    // Idle frames cost nothing: the springs are at rest and the wallpaper is
    // static, so there is no reason to rebuild.
    if (moving || _dirty) {
      _dirty = false;
      setState(() {});
    }
  }

  /// The area the glass is aligned inside.
  Rect _field(Size stage) => Rect.fromLTWH(
        _inset,
        _inset,
        math.max(1, stage.width - _inset * 2),
        math.max(1, stage.height - _inset * 2),
      );

  /// Place a box of [size] according to [_align].
  ///
  /// `Alignment.inscribe` is exactly the rule wanted here: it holds whichever
  /// edge the alignment names. At `centerLeft` the left edge is fixed and the
  /// box opens rightward; at `bottomRight` that corner is fixed; at `center`
  /// it opens both ways, which is the behaviour this page had before and the
  /// one case that never revealed the problem.
  Rect _place(Size size, Size stage) => _align.inscribe(size, _field(stage));

  /// The alignment that would place [r] inside [field] — the exact inverse of
  /// [Alignment.inscribe].
  ///
  /// This is the answer to "what if the glass is not at one of the nine spots".
  /// [Alignment] is continuous: `Alignment(-0.37, 0.12)` is as valid as
  /// `centerLeft`, and the growth simply splits in proportion — an axis at `x`
  /// sends `(1 + x) / 2` of any size change out one side and the rest out the
  /// other. So a glass placed anywhere can be handed the alignment its own
  /// position implies, and it will open the way that position wants.
  ///
  /// Degenerate when the box fills the field on an axis: every alignment then
  /// places it identically, and `0` is the honest answer rather than a
  /// division that blows up.
  Alignment _alignOf(Rect r, Rect field) {
    final double slackX = field.width - r.width;
    final double slackY = field.height - r.height;
    return Alignment(
      slackX.abs() < 0.01 ? 0 : ((r.left - field.left) / slackX) * 2 - 1,
      slackY.abs() < 0.01 ? 0 : ((r.top - field.top) / slackY) * 2 - 1,
    );
  }

  /// Drag the glass anywhere. The anchor is not chosen — it is DERIVED from
  /// where the glass ends up, so the morph opens the way its position implies
  /// without anyone picking a preset.
  void _dragGlass(DragUpdateDetails d, Size stage) {
    setState(() {
      final Rect field = _field(stage);
      final Size size = Size(_w, _h);
      final Rect moved = _place(size, stage).translate(d.delta.dx, d.delta.dy);
      // Held inside the field: an alignment outside −1…1 is legal but would
      // place the glass off-stage, which is not a thing to demonstrate.
      final double left = moved.left
          .clamp(field.left, math.max(field.left, field.right - size.width));
      final double top = moved.top
          .clamp(field.top, math.max(field.top, field.bottom - size.height));
      _align =
          _alignOf(Rect.fromLTWH(left, top, size.width, size.height), field);
      _dirty = true;
    });
  }

  /// Which corner of the glass actually MOVES as it resizes — the one opposite
  /// the anchor. The grip has to ride that one: a grip parked on a pinned edge
  /// would sit still while the glass grew out from under it.
  ///
  /// With a continuous alignment both edges move except at the extremes, so
  /// "free" is a matter of degree: whichever edge moves MORE gets the grip.
  Offset _freeCorner(Rect r) => Offset(
        _align.x > 0 ? r.left : r.right,
        _align.y > 0 ? r.top : r.bottom,
      );

  /// Free resize. The grip drives the TARGETS, not the outline — so the glass
  /// still lags and springs behind the finger instead of being nailed to it.
  void _drag(DragUpdateDetails d, Size stage) {
    setState(() {
      _free = true;
      final Rect field = _field(stage);
      // How much the SIZE changes per pixel of grip travel. Centred, both
      // edges move, so the box gains twice the drag; anchored, only the free
      // edge moves and it gains exactly the drag. And when the free edge is
      // the left or the top, dragging back toward the anchor is what grows it,
      // hence the sign.
      final double gainX = _align.x == 0 ? 2.0 : 1.0;
      final double gainY = _align.y == 0 ? 2.0 : 1.0;
      final double signX = _align.x > 0 ? -1.0 : 1.0;
      final double signY = _align.y > 0 ? -1.0 : 1.0;
      _tw = (_tw + d.delta.dx * gainX * signX).clamp(56.0, field.width);
      _th = (_th + d.delta.dy * gainY * signY).clamp(56.0, field.height);
      _travelStart = 0;
    });
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Morph'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Wallpaper(url: _wallpaper),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 44),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final Size stage = Size(c.maxWidth, c.maxHeight);
                    _syncStage(stage);
                    return _buildStage(stage);
                  },
                ),
              ),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  /// Keep the targets valid for the current stage.
  ///
  /// Called from inside `build`, so it must not call `setState` — it only
  /// writes fields the very same build is about to read.
  void _syncStage(Size stage) {
    if (stage == _stage) return;
    _stage = stage;
    _dirty = true;
    if (_free) return;
    final _Station s = _stations(stage)[_index];
    _tw = s.size.width;
    _th = s.size.height;
    _tr = s.radius;
    // First layout: the glass starts AT its station rather than springing in
    // from zero, so opening the page is not itself a morph.
    if (!_seeded) {
      _seeded = true;
      _w = _tw;
      _h = _th;
      _r = _tr;
      _corner = s.corner;
    }
  }

  Widget _buildStage(Size stage) {
    final List<_Station> stations = _stations(stage);
    final _Station station = stations[_index];

    // Squash/stretch, straight off spring velocity: the axis that is opening
    // fast pushes the other one in, and vice versa, so the pair sums to ~0 and
    // the glass keeps roughly its area. Both terms fall to zero on their own
    // as the springs settle — there is nothing to schedule or reset.
    double norm(double v) => (v / _squashReference).clamp(-1.0, 1.0);
    final double bias =
        _squash ? (norm(_vw) - norm(_vh)) * 0.5 * _squashGain : 0.0;
    final double drawW = (_w * (1 + bias)).clamp(24.0, stage.width);
    final double drawH = (_h * (1 - bias)).clamp(24.0, stage.height);

    // Half the short side is the cap that turns "wide and short" into a
    // capsule and "tall" into a card without either being a special case.
    final double radius = math.min(_r, math.min(drawW, drawH) / 2);

    // The anchored rect, and the corner the grip rides.
    final Rect glass = _place(Size(drawW, drawH), stage);
    final Offset grip = _freeCorner(glass);

    final LiquidGlassStyle style = LiquidGlassStyle(
      shape: LiquidGlassShape(
        cornerStyle: _corner,
        cornerRadius: radius,
        borderWidth: 1.4,
        lightIntensity: 1.05,
      ),
      appearance: const LiquidGlassAppearance(
        color: Color(0x1AFFFFFF),
        saturation: 1.08,
        blur: LiquidGlassBlur(sigmaX: 6, sigmaY: 6),
      ),
      refraction: const LiquidGlassRefraction(
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: 24,
          depth: 0.42,
        ),
      ),
    );

    // Tight to the stage. A bare Stack here would size itself to the glass —
    // the Column's cross axis is loose — and then every `Positioned` below
    // would be resolving stage coordinates inside a box the size of the lens.
    return SizedBox(
      width: stage.width,
      height: stage.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Positioned from the ANCHORED rect rather than left to a centring
          // Stack: the alignment is what decides which way the morph opens.
          Positioned.fromRect(
            rect: glass,
            child: GestureDetector(
              // Keyed so a test can measure the OUTLINE, which is what the
              // anchoring is about.
              key: const ValueKey<String>('morph-glass'),
              onTap: () => _go((_index + 1) % stations.length),
              onPanUpdate: (DragUpdateDetails d) => _dragGlass(d, stage),
              child: LiquidGlassLens(
                style: style,
                // The lens clips its own child to the outline it draws, so
                // the content only has to refuse to reflow — the mask is free.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (Widget? current, List<Widget> previous) =>
                      Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      ...previous,
                      if (current != null) current,
                    ],
                  ),
                  transitionBuilder: (Widget child, Animation<double> a) =>
                      FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.88, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_index),
                    // Natural size, centred, clipped by the moving outline —
                    // the content never learns that the glass is resizing.
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      // WIDTH only. Forcing the station's height as well made
                      // the content's Column a fixed box that a short stage
                      // could squeeze until it overflowed — and an overflow
                      // stripe is a reflow, which is the one thing this page
                      // promises never happens. Unbounded, the content takes
                      // its own natural height and the lens masks it.
                      child: SizedBox(
                        width: station.size.width,
                        child: station.content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // The resize grip, riding whichever corner of the glass is free to
          // move. Clamped into the stage so the widest station cannot push it
          // off the edge.
          Positioned(
            left: (grip.dx - _Grip.size / 2)
                .clamp(0.0, math.max(0.0, stage.width - _Grip.size)),
            top: (grip.dy - _Grip.size / 2)
                .clamp(0.0, math.max(0.0, stage.height - _Grip.size)),
            child: GestureDetector(
              onPanUpdate: (DragUpdateDetails d) => _drag(d, stage),
              child: const _Grip(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Controls ─────────────────────────────────────────────────────

  Widget _controls() {
    final List<_Station> stations = _stations(_stage);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_w.round()} × ${_h.round()}    r ${_r.round()}    '
            '${_cornerName(_corner)}${_free ? '    free' : ''}\n'
            'anchor ${_align.x.toStringAsFixed(2)}, '
            '${_align.y.toStringAsFixed(2)}    '
            'opens ${(100 * (1 + _align.x) / 2).round()}% left / '
            '${(100 * (1 - _align.x) / 2).round()}% right',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (int i = 0; i < stations.length; i++)
                _Chip(
                  label: stations[i].name,
                  on: !_free && i == _index,
                  onTap: () => _go(i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _Chip(
                label: _liquid ? 'spring' : 'eased',
                on: _liquid,
                onTap: () => setState(() => _liquid = !_liquid),
              ),
              _Chip(
                label: 'squash',
                on: _squash,
                onTap: () => setState(() => _squash = !_squash),
              ),
              _Chip(
                label: '0.25×',
                on: _slow,
                onTap: () => setState(() => _slow = !_slow),
              ),
              // Nine anchors. The grid IS the idea: pick a corner and the
              // morph opens away from it; pick the middle and it opens both
              // ways, which is the one case that never shows the difference.
              _AlignGrid(
                value: _align,
                onChanged: (Alignment a) => setState(() {
                  _align = a;
                  // Nothing is re-aimed: the SIZE targets are untouched and
                  // only the anchor moved, so the glass slides to the new
                  // corner on the springs it is already riding.
                  _dirty = true;
                }),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the glass for the next shape, or drag the grip to size it '
            'freely.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  static String _cornerName(LiquidGlassCornerStyle s) => switch (s) {
        LiquidGlassCornerStyle.roundedRectangle => 'circular',
        LiquidGlassCornerStyle.squircle => 'squircle',
        LiquidGlassCornerStyle.continuousRoundedRectangle => 'continuous',
      };
}

// ── Station contents ───────────────────────────────────────────────
// Each one is laid out at its station's natural size and simply clipped by the
// glass while the outline is somewhere else, so none of them reflow mid-morph.

class _DotContent extends StatelessWidget {
  const _DotContent();

  @override
  Widget build(BuildContext context) => const Center(
      child: Icon(Icons.search_rounded, color: Colors.white, size: 26));
}

class _PillContent extends StatelessWidget {
  const _PillContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_rounded, color: Colors.white, size: 20),
          SizedBox(width: 9),
          Text(
            'Search',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldContent extends StatelessWidget {
  const _FieldContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, color: Colors.white, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search photos',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 16,
              ),
            ),
          ),
          Icon(
            Icons.mic_rounded,
            color: Colors.white.withValues(alpha: 0.72),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Heading('Today'),
          const SizedBox(height: 6),
          Text(
            'Four new photos from this morning.',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                Expanded(child: _Thumb(index: i)),
                if (i < 2) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent();

  static const List<(IconData, String, String)> _rows =
      <(IconData, String, String)>[
    (Icons.photo_library_rounded, 'Recents', '1,284'),
    (Icons.favorite_rounded, 'Favourites', '96'),
    (Icons.people_alt_rounded, 'People', '12'),
    (Icons.delete_outline_rounded, 'Recently deleted', '4'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Heading('Library'),
          const SizedBox(height: 14),
          for (int i = 0; i < _rows.length; i++) ...<Widget>[
            _PanelRow(
              icon: _rows[i].$1,
              label: _rows[i].$2,
              trailing: _rows[i].$3,
            ),
            if (i < _rows.length - 1)
              Divider(
                height: 17,
                thickness: 0.6,
                color: Colors.white.withValues(alpha: 0.14),
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                Expanded(child: _Thumb(index: i)),
                if (i < 2) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontFeatures: const <ui.FontFeature>[
              ui.FontFeature.tabularFigures()
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Icon(
          Icons.more_horiz_rounded,
          color: Colors.white.withValues(alpha: 0.7),
          size: 20,
        ),
      ],
    );
  }
}

/// A plain gradient tile — deliberately NOT a lens. The page keeps exactly one
/// piece of glass on screen so the morph is the only thing being measured.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.index});

  final int index;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF60A5FA), Color(0xFF1D4ED8)],
    <Color>[Color(0xFFF472B6), Color(0xFF9D174D)],
    <Color>[Color(0xFF34D399), Color(0xFF065F46)],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _palettes[index % _palettes.length],
        ),
      ),
    );
  }
}

// ── Chrome ─────────────────────────────────────────────────────────

class _Grip extends StatelessWidget {
  const _Grip();

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Transform.rotate(
        angle: math.pi / 2,
        child: const Icon(
          Icons.open_in_full_rounded,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The nine-anchor picker. Small on purpose — it is a setting, not the demo.
class _AlignGrid extends StatelessWidget {
  const _AlignGrid({required this.value, required this.onChanged});

  final Alignment value;
  final ValueChanged<Alignment> onChanged;

  static const List<double> _axis = <double>[-1, 0, 1];

  static const double _cell = 17;
  static const double _pitch = 20; // cell + 1.5 margin either side
  static const double _extent = _pitch * 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _extent,
      height: _extent,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final double y in _axis)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final double x in _axis)
                      GestureDetector(
                        key: ValueKey<String>(
                            'anchor-${x.toInt()}-${y.toInt()}'),
                        onTap: () => onChanged(Alignment(x, y)),
                        child: Container(
                          width: _cell,
                          height: _cell,
                          margin: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: value == Alignment(x, y)
                                ? Colors.white.withValues(alpha: 0.92)
                                : Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          // The LIVE anchor, which is continuous. The nine cells are presets;
          // dragging the glass lands the marker between them, and that is the
          // point — nothing about the mechanism needs it to be on a cell.
          Positioned(
            left: _extent / 2 + value.x * _pitch - 3,
            top: _extent / 2 + value.y * _pitch - 3,
            child: IgnorePointer(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF11131A),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          borderRadius: BorderRadius.circular(11),
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

/// The refractable wallpaper captured by [LiquidGlassView]. Static, so the
/// Skia path captures it once and the morph costs nothing but the shader.
class _Wallpaper extends StatelessWidget {
  const _Wallpaper({required this.url});

  final String url;

  static const DecoratedBox _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF1E3A8A),
          Color(0xFF9D174D),
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
              colors: <Color>[Color(0x33000000), Color(0x66000000)],
            ),
          ),
        ),
      ],
    );
  }
}
