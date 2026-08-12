import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../src/controllers/liquid_glass_view_controller.dart';
import '../src/widgets/components/bottom_nav_bar/liquid_glass_bottom_nav_bar.dart';
import '../src/widgets/components/liquid_glass_morph_pill.dart'
    show liquidGlassMorphEnvelope;
import '../src/widgets/components/liquid_glass_tab_bar.dart'
    show LiquidGlassTabBarItem;
import '../src/widgets/liquid_glass.dart';
import '../src/widgets/liquid_glass_config.dart';
import '../src/widgets/liquid_glass_style.dart';
import '../src/widgets/liquid_glass_view.dart';
import '../src/widgets/utils/liquid_glass_blur.dart';
import '../src/widgets/utils/liquid_glass_jelly_spring.dart'
    show liquidGlassSpringStep;
import '../src/widgets/utils/liquid_glass_position.dart';
import '../src/widgets/utils/liquid_glass_refresh_rate.dart';
import '../src/widgets/utils/liquid_glass_shape.dart';
import '../src/widgets/utils/liquid_glass_lens_motion.dart';
import 'liquid_glass_nav_pill.dart';
import '../src/widgets/components/liquid_glass_shadow.dart';

// The bar's geometry is a required argument here, but it is deliberately
// not part of the package's public surface (the drop-in
// `LiquidGlassBottomNavBar` supersedes it for app developers). Surface it
// alongside this experimental bar so a demo can configure one without
// reaching into `src/`.
export '../src/widgets/components/bottom_nav_bar/liquid_glass_bottom_nav_bar.dart'
    show LiquidGlassBottomNavBarLayout;

/// **Experimental.** A copy of `LiquidGlassAnimatedNavBar` — the engine
/// behind `LiquidGlassBottomNavBar.glassPill` — with the pill's **jelly
/// replaced by the acceleration motion model**, the one the experimental
/// stretch slider's thumb runs on.
///
/// Per the experimental-folder rule this is a copy: the shipped bar is
/// untouched, and everything it did not need to change — layout, the bar
/// capsule, the icon shell and its through-the-pill reveal, the static
/// rest pill, the gesture overlay, the dual-view pipeline — is imported
/// from `lib/src`, not duplicated.
///
/// ## What changed, and only this
///
/// **1. Where the deformation comes from.** The shipped bar runs
/// `LiquidGlassJellySpring`: a velocity-driven lean spring plus a
/// direction-memory deform spring, pumped in tab-fraction units, with
/// hand-fed `release()` calls to make a tap-travel recoil. This one runs
/// [LiquidGlassLensMotion]: the pill's drawn position is sampled every
/// frame in PIXELS, differentiated twice, and the averaged acceleration
/// scales the pill oppositely on the two axes —
///
///     scaleX = 1 + d      scaleY = 1 − d
///
/// Accelerating out of a tab stretches the pill wide and flat; braking
/// into the next one squashes it narrow and tall; constant-speed travel
/// leaves it undeformed. Force, not speed.
///
/// That also deletes bookkeeping rather than moving it. The jelly needed
/// `_travelFeedsJelly` / `_travelReleased` to decide which motions were
/// allowed to pump it and when to hand it a release — a drag-release
/// snap had to be hidden from it or it would re-pump. The acceleration
/// model reads the position the pill is actually drawn at, so every
/// motion feeds it and none of them need special-casing: a drag-release
/// snap genuinely IS a motion, and its braking is exactly the landing
/// squash you want.
///
/// **2. There is no lean.** The jelly folded a horizontal bias back into
/// the pill's fractional index, so the body slid ahead of its own cell.
/// The acceleration model has no such term — the pill deforms about its
/// centre and travels on the spring alone.
///
/// **3. How the deformation is drawn.** The shipped pill is a positioned
/// [LiquidGlass] config whose capsule is RE-DERIVED at every size
/// (`cornerRadius: pillH / 2`), so a squashed pill is a new, rounder
/// capsule. Here the pill is a [LiquidGlassLens] widget in the
/// outer view's `child:` slot: the shape is evaluated at the ENVELOPE
/// (rest) size and the deformation rides the shader's `u_shapeScale`
/// with matching elliptical clips, so the outline STRETCHES as one body
/// and the end caps go elliptical. It refracts the same thing the
/// positioned pill did — the outer view's capture is the inner stack, so
/// the pill still bends the bar's own glass.
///
/// One consequence to know about: the view paints its `child:` slot BELOW
/// its positioned `children:`, so the pill now sits under [outerLenses]
/// rather than over them. Nothing overlaps a bottom-anchored pill in
/// practice — an app bar is at the top, a side action sits beside the bar
/// — but a host that deliberately put glass over the pill's own cells
/// would see the difference.
///
/// **4. Glass only while it moves.** The travel spring is unchanged, and the
/// pill's size and material still interpolate from [restStyle] to the active
/// style across the whole lift. But the moment the spring settles — morph
/// envelope back at 0, squash already cleared at the halfway mark — the lens
/// is dropped and a plain `LiquidGlassBottomNavPillStatic` takes the same
/// rect. A bar sitting still then costs no shader pass, no clip, no outer
/// capture, and no dual-layer icon reveal.
///
/// [body] is the page content, captured behind the glass. [outerLenses]
/// are composited in the outer view on top of the bar (e.g. the app bar
/// and the side action button).
class LiquidGlassAnimatedNavBarMotionOnly extends StatefulWidget {
  final Widget body;
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Icon + label styling for every tab cell.
  final LiquidGlassNavItemStyle itemStyle;

  /// Whether the persistent selection glass pill is drawn.
  final bool showSelectionPill;

  /// Whether the OUTER pipeline must keep capturing independently of the
  /// selection pill. Hosts that put lenses in [outerChild] must pass `true`.
  final bool outerNeedsRealtime;

  /// Bar geometry (size, position, padding). The bottom margin should
  /// already include any safe-area inset.
  final LiquidGlassBottomNavBarLayout layout;

  /// Lenses composited in the **outer** view, above the bar.
  final List<LiquidGlass> outerLenses;

  /// Widget subtree composited in the **outer** view's `child:` slot,
  /// above the captured bar/body — and, here, above the moving pill,
  /// which now lives in that same slot.
  final Widget? outerChild;

  /// Optional solid color behind [body].
  final Color? backgroundColor;

  /// Custom placement for the bar.
  final LiquidGlassPosition? barPosition;

  /// Overrides the bar-capsule glass shape.
  final LiquidGlassShape? barShape;

  /// Refraction of the bar capsule.
  final LiquidGlassRefraction? barRefraction;

  /// Appearance (tint + blur) of the bar capsule.
  final LiquidGlassAppearance? barAppearance;

  /// Contact shadow around the **bar capsule** — the soft dark band that
  /// hugs its rim and pools underneath, so the bar reads as sitting in
  /// the page rather than floating on it. `null` (the default) draws
  /// none.
  ///
  /// It is drawn into the INNER stack, above the capsule's glass and
  /// below the icons, which puts it in the outer view's capture — so the
  /// moving pill refracts the bar's shadow along with its glass. Its
  /// corner follows [barShape] when one is set.
  final LiquidGlassShadow? barShadow;

  /// Blur behind the moving glass pill. Defaults to none.
  final LiquidGlassBlur pillBlur;

  /// How much taller the glass pill grows than the bar at peak travel.
  final double pillGrowHeight;

  /// Refraction strength of the moving glass pill.
  final double pillDistortion;

  /// Width of the glass pill's refraction band.
  final double pillDistortionWidth;

  /// Complete refraction configuration for the moving pill. When set,
  /// this supersedes [pillDistortion], [pillDistortionWidth] and
  /// [pillMagnification].
  final LiquidGlassRefraction? pillRefraction;

  /// Magnification of the content seen through the glass pill.
  final double pillMagnification;

  /// When `true`, the glass pill's inner area is transparent.
  final bool pillEnableInnerRadiusTransparent;

  /// Overrides the moving glass pill's shape. When `null` the pill is an
  /// Apple capsule-style shape whose radius tracks the pill's ENVELOPE
  /// height — the size before the acceleration deformation, since the
  /// shader stretches the authored outline rather than re-rounding it.
  final LiquidGlassShape? pillShape;

  /// Fill tint of the moving glass pill.
  final Color pillColor;

  /// Contact shadow around the **moving pill**. `null` (the default)
  /// draws none.
  ///
  /// It wraps the pill's lens rather than living inside it, so the arc
  /// that pools below the pill is not clipped off at the outline, and it
  /// is handed the live envelope corner and outline stretch so the ring
  /// stays on the rim while the pill squashes. It fades with the pill.
  final LiquidGlassShadow? pillShadow;

  /// Resting material endpoint of the same persistent glass pill.
  final LiquidGlassStyle restStyle;

  /// Stiffness of the spring carrying the pill between tabs.
  final double travelStiffness;

  /// Damping of the travel spring.
  final double travelDamping;

  /// The pill's squash/stretch tuning — the replacement for the shipped
  /// bar's `jelly`.
  ///
  /// The default drops the slider thumb's ±30 % ceiling to ±12 %: a
  /// thumb floats free, while this pill lives inside a capsule and a
  /// third of its height in overhang would climb out of the bar. The
  /// window, coefficient and response ease are the slider's.
  final LiquidGlassLensMotionSpec motion;

  // Render pipeline knobs forwarded to both views.
  final double pixelRatio;
  final bool useSync;
  final bool? useImpellerBackdrop;

  /// Whether the **inner** view (body + bar capsule) captures every frame.
  final bool realTimeCapture;

  const LiquidGlassAnimatedNavBarMotionOnly({
    super.key,
    required this.body,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.itemStyle = const LiquidGlassNavItemStyle(),
    this.showSelectionPill = true,
    this.outerNeedsRealtime = false,
    this.outerLenses = const [],
    this.outerChild,
    this.backgroundColor,
    this.barPosition,
    this.barShape,
    this.barRefraction,
    this.barAppearance,
    this.barShadow,
    this.pillShadow,
    this.pillBlur = const LiquidGlassBlur(),
    this.pillGrowHeight = 12,
    this.pillDistortion = 0.06,
    this.pillDistortionWidth = 10,
    this.pillRefraction,
    this.pillMagnification = 1,
    this.pillEnableInnerRadiusTransparent = false,
    this.pillShape,
    this.pillColor = const Color(0x1CFFFFFF),
    this.restStyle = const LiquidGlassStyle(
      appearance: LiquidGlassAppearance(color: Color(0x26FFFFFF)),
      refraction: LiquidGlassRefraction(
        distortion: 0.015,
        distortionWidth: 8,
        chromaticAberration: 0.0002,
      ),
    ),
    this.travelStiffness = 280,
    this.travelDamping = 31.4,
    this.motion = const LiquidGlassLensMotionSpec(
      window: 0.3,
      coefficient: 0.00007,
      maxDeviation: 0.12,
      responseTau: 0.18,
    ),
    this.pixelRatio = 1.0,
    this.useSync = true,
    this.useImpellerBackdrop,
    this.realTimeCapture = true,
  });

  @override
  State<LiquidGlassAnimatedNavBarMotionOnly> createState() =>
      _LiquidGlassAnimatedNavBarMotionOnlyState();
}

class _LiquidGlassAnimatedNavBarMotionOnlyState
    extends State<LiquidGlassAnimatedNavBarMotionOnly>
    with TickerProviderStateMixin {
  // Inner pipeline captures wallpaper + bar capsule; outer composites
  // the moving glass pill on top so it refracts the bar's own glass.
  final _outerViewController = LiquidGlassViewController();
  final _innerViewController = LiquidGlassViewController();

  /// Live selection driving the animation (source of truth internally).
  late int _tabIndex;

  /// Index the static UI (shell icons, rest pill) shows as selected.
  /// Flips only AFTER the glass finishes travelling.
  late int _tabIndexCommitted;

  /// The persistent glass pill's live size, published by the pill itself.
  /// Before its first physics tick the rest size is used as the fallback.
  final ValueNotifier<Size?> _pillGeometry = ValueNotifier<Size?>(null);

  /// Fractional pill position (0..itemCount-1). While dragging this is
  /// the finger's target; the pill is drawn at [_dragFollow], a smoothed
  /// chase of it.
  double _tabPillFracIndex = 0;
  double _dragFollow = 0;
  bool _tabDragging = false;

  /// Fractional position of the initial press, captured at long-press
  /// start.
  double _pressFrac = 0;

  /// True once the finger has moved far enough from [_pressFrac] to count
  /// as a genuine drag.
  bool _draggedRealMove = false;

  // ── Travel spring ────────────────────────────────────────────────
  double _travelPos = 0;
  double _travelVel = 0;
  double _travelTarget = 0;
  double _travelFrom = 0;

  /// True from the moment a travel starts until the spring settles.
  bool _travelActive = false;

  /// Original shipped-bar drag-release state and shrink envelope.
  bool _settlingFromDrag = false;
  double _settleGrow = 0;

  /// Original shipped-bar grow-in multiplier.
  double _glassAppear = 1;
  static const double _glassAppearSeconds = 0.15;

  /// Single ticker driving the travel spring, the motion sampling and
  /// the settle-grow decay.
  Ticker? _ticker;
  Duration? _tickerLast;

  /// Absolute left edge of the bar in the parent, recomputed each build.
  double _barLeft = 0;

  /// Effective bottom inset of the bar.
  double _effBottomMargin = 0;

  LiquidGlassBottomNavBarLayout get _layout => widget.layout;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.selectedIndex;
    _tabIndexCommitted = widget.selectedIndex;
    _tabPillFracIndex = widget.selectedIndex.toDouble();
    _travelPos = widget.selectedIndex.toDouble();
    _travelTarget = _travelPos;
    _travelFrom = _travelPos;
    _ticker = createTicker(_onTick);
    // The pill morphs on its own ticker; the bar rebuilds when its size
    // changes so the icon shell's reveal stays glued to the glass.
    _pillGeometry.addListener(_onPillGeometry);
  }

  void _onPillGeometry() {
    if (mounted) setState(() {});
  }

  /// Starts the shared ticker if it isn't already running.
  void _startTicker() {
    if (_ticker?.isActive != true) {
      _tickerLast = null;
      _ticker?.start();
    }
  }

  @override
  void didUpdateWidget(
      covariant LiquidGlassAnimatedNavBarMotionOnly oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External (programmatic) selection change — animate to it without
    // re-notifying the parent.
    if (widget.selectedIndex != _tabIndex &&
        widget.selectedIndex != oldWidget.selectedIndex) {
      _animateTo(widget.selectedIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _pillGeometry.removeListener(_onPillGeometry);
    _pillGeometry.dispose();
    _outerViewController.detach();
    _innerViewController.detach();
    super.dispose();
  }

  // ── Capture lifecycle ────────────────────────────────────────────
  void _startCapture() {
    if (!widget.realTimeCapture) _innerViewController.startRealtimeCapture();
  }

  void _maybeStopCapture() {
    if (widget.realTimeCapture) return; // keep the inner pipeline live
    if (!_travelActive && !_tabDragging) {
      _innerViewController.stopRealtimeCapture();
    }
  }

  // ── Selection / animation ────────────────────────────────────────
  void _animateTo(int next, {required bool notify}) {
    if (next == _tabIndex) return;
    if (!_travelActive && !_tabDragging) _glassAppear = 0;
    setState(() {
      _tabIndex = next;
      _travelActive = true;
      _settlingFromDrag = false;
      // Retarget from wherever the pill currently is; the spring keeps
      // its velocity.
      _travelFrom = _travelPos;
      _travelTarget = next.toDouble();
    });
    _startCapture();
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  // ── Gesture geometry ─────────────────────────────────────────────
  double _xToTabFrac(double globalDx) {
    final cell0Center = _barLeft + _layout.padding + _layout.cellWidth / 2;
    final cellW = _layout.cellWidth;
    final raw = (globalDx - cell0Center) / cellW;
    return raw.clamp(0.0, (_layout.itemCount - 1).toDouble());
  }

  void _onTabBarTapUp(TapUpDetails d) {
    final cellW = _layout.cellWidth;
    final raw = d.localPosition.dx / cellW;
    final idx = raw.floor().clamp(0, _layout.itemCount - 1);
    _animateTo(idx, notify: true);
  }

  // ── Hold-to-grab handlers ────────────────────────────────────────
  void _onTabPillLongPressStart(LongPressStartDetails d) {
    if (!_travelActive && !_tabDragging) _glassAppear = 0;
    _tabDragging = true;
    _travelActive = false;
    _settlingFromDrag = false;
    _startCapture();
    final frac = _xToTabFrac(d.globalPosition.dx);
    // Start the smoothed follow at the pill's current resting position so
    // a hold away from the pill EASES over to the finger.
    _dragFollow = _travelPos;
    _travelVel = 0;
    _pressFrac = frac;
    _draggedRealMove = false;
    _startTicker();
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!_tabDragging) return;
    final frac = _xToTabFrac(d.globalPosition.dx);
    if ((frac - _pressFrac).abs() > 0.2) _draggedRealMove = true;
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillLongPressEnd(LongPressEndDetails d) {
    if (!_tabDragging) return;
    _releaseTabPillDrag();
  }

  void _onTabPillLongPressCancel() {
    if (!_tabDragging) return;
    _releaseTabPillDrag();
  }

  void _releaseTabPillDrag() {
    final from = _dragFollow;
    final double snapFrac = _draggedRealMove ? from : _pressFrac;
    final next = snapFrac.round().clamp(0, _layout.itemCount - 1);
    final notify = next != _tabIndex;
    setState(() {
      _tabDragging = false;
      _settlingFromDrag = true;
      _tabIndex = next;
      _travelActive = true;
      _travelPos = from;
      _travelVel = 0;
      _travelFrom = from;
      _travelTarget = next.toDouble();
      _settleGrow = 1;
    });
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  /// One frame of the bar's own physics: the travel spring, and the
  /// smoothed follow while a finger is down. That is all the bar owns —
  /// the pill's morph and its squash/stretch run on the pill's ticker.
  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;

    // 1) Travel (positional) spring.
    bool travelSettled = true;
    if (_travelActive) {
      final r = liquidGlassSpringStep(
        x: _travelPos,
        vel: _travelVel,
        target: _travelTarget,
        dt: dt,
        stiffness: widget.travelStiffness,
        damping: widget.travelDamping,
      );
      _travelPos = r.$1;
      _travelVel = r.$2;
      travelSettled =
          (_travelPos - _travelTarget).abs() < 0.003 && _travelVel.abs() < 0.05;
      if (travelSettled) {
        _travelPos = _travelTarget;
        _travelVel = 0;
      }
    }

    // 2) While dragging, smoothly chase the finger target so a hold away
    // from the pill glides to the held position.
    if (_tabDragging) {
      const followTau = 0.05;
      _dragFollow +=
          (_tabPillFracIndex - _dragFollow) * (1 - math.exp(-dt / followTau));
    }

    // 3) Original shipped-bar drag-release shrink.
    if (_settlingFromDrag && _settleGrow > 0) {
      const tau = 0.06;
      _settleGrow *= math.exp(-dt / tau);
      if (_settleGrow < 0.01) _settleGrow = 0;
    }
    final bool growSettled = !_settlingFromDrag || _settleGrow == 0;

    // 4) Commit only after both original travel and drag shrink settle.
    if (_travelActive && travelSettled && growSettled && !_tabDragging) {
      _travelActive = false;
      _settlingFromDrag = false;
      _settleGrow = 0;
      _tabIndexCommitted = _tabIndex;
    }

    if (_glassAppear < 1) {
      _glassAppear += dt / _glassAppearSeconds;
      if (_glassAppear >= 1) _glassAppear = 1;
    }

    // The external original envelope is fully driven by this ticker.
    if (!_travelActive && !_tabDragging) {
      _maybeStopCapture();
      _ticker?.stop();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final parentWidth = constraints.maxWidth;
      final parentHeight = constraints.maxHeight;

      // Resolve the bar's placement.
      final centeredLeft = (parentWidth - _layout.width) / 2;
      if (widget.barPosition != null) {
        final off = widget.barPosition!.resolve(
          Size(parentWidth, parentHeight),
          Size(_layout.width, _layout.height),
        );
        _barLeft = off.dx;
        _effBottomMargin = parentHeight - off.dy - _layout.height;
      } else {
        _barLeft = centeredLeft;
        _effBottomMargin = _layout.bottomMargin;
      }
      final layout = _layout.copyWith(bottomMargin: _effBottomMargin);

      final cellW = layout.cellWidth;

      // Glass pill geometry: same w:h ratio as the rest pill, scaled up
      // so the glass is a touch bigger than the bar height.
      // The two sizes the pill morphs between: the cell it rests in, and
      // the raised glass it becomes while a finger is on the bar.
      final Size pillRest = Size(layout.pillWidth, layout.cellHeight);
      final double liftedH = layout.height + widget.pillGrowHeight;
      final Size pillLifted =
          Size(liftedH * (layout.pillWidth / layout.cellHeight), liftedH);

      // Exact rest/lift timing from the shipped animated nav bar.
      final double travelSpan = (_travelTarget - _travelFrom).abs();
      final double travelP = travelSpan < 1e-6
          ? 1
          : (1 - (_travelTarget - _travelPos).abs() / travelSpan)
              .clamp(0.0, 1.0);
      final double growT;
      if (_tabDragging) {
        growT = 1;
      } else if (_settlingFromDrag) {
        growT = _settleGrow;
      } else if (_travelActive) {
        growT = liquidGlassMorphEnvelope(travelP);
      } else {
        growT = 0;
      }
      final double morphProgress = growT * _glassAppear;

      final pillFrac = _tabDragging ? _dragFollow : _travelPos;

      // The pill's centre in the outer view's coordinates. Horizontally
      // it rides its cell; vertically the centre never moves, since the
      // morph is symmetric about the bar's row.
      final double pillCX =
          _barLeft + layout.padding + pillFrac * cellW + layout.pillWidth / 2;
      final double pillCY = parentHeight -
          (_effBottomMargin + layout.padding + layout.cellHeight / 2);

      // Acceleration deformation is limited to the lifting/held phase. The
      // returning half uses only the original nav bar's morph envelope.
      final bool returningToRest = _settlingFromDrag ||
          (_travelActive && !_tabDragging && travelP >= 0.5);
      final bool trackPillMotion =
          (_tabDragging || _travelActive) && !returningToRest;

      // One glass surface exists at both endpoints. Before its first tick,
      // use the authored rest geometry so the selected reveal is present on
      // the very first frame instead of waiting for a notifier update.
      final Size envelopeSize = Size.lerp(
        pillRest,
        pillLifted,
        morphProgress.clamp(0.0, 1.0),
      )!;
      final Size liveSize = trackPillMotion
          ? (_pillGeometry.value ?? envelopeSize)
          : envelopeSize;

      // The glass surface exists only while something is moving it. The
      // instant the travel spring settles, the pill is already at rest
      // geometry with zero deformation — the morph envelope has returned to
      // 0 and `resetMotionOnStop` cleared the squash at the halfway mark —
      // so the plain rest pill can take over with nothing to cross-fade.
      //
      // That is the whole point: at rest there is no lens, no shader pass,
      // no clip, and (below) no outer capture either.
      final bool glassMounted =
          widget.showSelectionPill && (_travelActive || _tabDragging);
      final bool glassOn = glassMounted;
      // The icon shell's reveal is cut to the size the pill says it is
      // drawing, so the selected colour wipes on exactly under the glass.
      final double? hlFrac = glassOn ? pillFrac : null;
      final double? hlW = glassOn ? liveSize.width : null;
      final double? hlH = glassOn ? liveSize.height : null;

      return Stack(
        fit: StackFit.expand,
        children: [
          // OUTER view: captures the inner stack and composites the
          // moving glass pill + the developer's outer lenses on top.
          LiquidGlassView.withPositionedLenses(
            controller: _outerViewController,
            pixelRatio: widget.pixelRatio,
            useSync: widget.useSync,
            // Only capture while there is something to composite — which is
            // now only while the glass pill is actually mounted.
            realTimeCapture: glassMounted || widget.outerNeedsRealtime,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            useImpellerBackdrop: widget.useImpellerBackdrop,
            backgroundWidget: _buildInner(
              layout: layout,
              pillFrac: hlFrac,
              pillW: hlW,
              pillH: hlH,
            ),
            children: [
              // Stable, role-based keys so each outer lens keeps its own
              // `State`. The pill no longer lives in this list, so the
              // list's length is now invariant.
              for (int i = 0; i < widget.outerLenses.length; i++)
                widget.outerLenses[i].key != null
                    ? widget.outerLenses[i]
                    : widget.outerLenses[i]
                        .copyWith(key: ValueKey('lg-nav-outer-$i')),
            ],
            // The pill is a lens WIDGET now, in the view's `child:` slot —
            // the only place an externally-driven deformation can be
            // rendered (a positioned `LiquidGlass` can only deform from
            // its own internal touch driver). It refracts the same
            // capture the positioned pill did: this view's background,
            // which is the inner stack.
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (glassMounted)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LiquidGlassNavPill(
                        center: Offset(pillCX, pillCY),
                        active: morphProgress > 0,
                        morphProgress: morphProgress,
                        restSize: pillRest,
                        activeSize: pillLifted,
                        style: _pillStyle(),
                        restStyle: widget.restStyle,
                        motion: widget.motion,
                        trackMotion: trackPillMotion,
                        resetMotionOnStop: true,
                        shadow: widget.pillShadow,
                        geometry: _pillGeometry,
                        honorBackdropAlpha: false,
                      ),
                    ),
                  )
                // Settled: the same rect the glass just vacated, painted as
                // a plain fill. Placed from the pill's own centre rather
                // than re-derived from the committed index, so the two can
                // never disagree by a pixel at the hand-off.
                else if (widget.showSelectionPill)
                  Positioned(
                    key: const ValueKey('lg-motion-nav-pill-static'),
                    left: pillCX - pillRest.width / 2,
                    top: pillCY - pillRest.height / 2,
                    child: LiquidGlassBottomNavPillStatic(
                      width: pillRest.width,
                      height: pillRest.height,
                      color: widget.restStyle.appearance.color,
                      shape: widget.restStyle.shape,
                    ),
                  ),
                if (widget.outerChild != null) widget.outerChild!,
              ],
            ),
          ),
          // Unified gesture overlay: a quick tap on any cell selects it;
          // a press-and-hold lifts the pill to drag.
          Positioned(
            key: const ValueKey('lg-animated-nav-gesture-overlay'),
            left: _barLeft + layout.padding,
            bottom: _effBottomMargin + layout.padding,
            width: layout.width - 2 * layout.padding,
            height: layout.cellHeight,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (instance) => instance.onTapUp = _onTabBarTapUp,
                ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(
                    duration: const Duration(milliseconds: 100),
                  ),
                  (instance) => instance
                    ..onLongPressStart = _onTabPillLongPressStart
                    ..onLongPressMoveUpdate = _onTabPillLongPressMoveUpdate
                    ..onLongPressEnd = _onTabPillLongPressEnd
                    ..onLongPressCancel = _onTabPillLongPressCancel,
                ),
              },
            ),
          ),
        ],
      );
    });
  }

  /// The moving pill's look, assembled from the bar's pill-* knobs.
  ///
  /// A null [pillShape] is left null on purpose: the pill then builds a
  /// capsule whose radius tracks its own morphing height, and scales the
  /// refraction band with it — both of which it is better placed to do,
  /// since it owns the size.
  LiquidGlassStyle _pillStyle() {
    return LiquidGlassStyle(
      shape: widget.pillShape,
      appearance: LiquidGlassAppearance(
        color: widget.pillColor,
        blur: widget.pillBlur,
        enableInnerRadiusTransparent: widget.pillEnableInnerRadiusTransparent,
      ),
      refraction: widget.pillRefraction ??
          LiquidGlassRefraction(
            magnification: widget.pillMagnification,
            distortion: widget.pillDistortion,
            distortionWidth: widget.pillDistortionWidth,
            chromaticAberration: 0.002,
          ),
    );
  }

  /// Inner stack the outer view captures: wallpaper/body + bar capsule
  /// lens, with the icon shell drawn on top.
  Widget _buildInner({
    required LiquidGlassBottomNavBarLayout layout,
    double? pillFrac,
    double? pillW,
    double? pillH,
  }) {
    final Widget background = widget.backgroundColor == null
        ? widget.body
        : ColoredBox(color: widget.backgroundColor!, child: widget.body);

    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView.withPositionedLenses(
          controller: _innerViewController,
          pixelRatio: widget.pixelRatio,
          useSync: widget.useSync,
          realTimeCapture: widget.realTimeCapture,
          refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
          useImpellerBackdrop: widget.useImpellerBackdrop,
          backgroundWidget: background,
          children: [
            buildLiquidGlassBottomNavCapsule(
              layout: layout,
              position: widget.barPosition,
              shape: widget.barShape,
              refraction: widget.barRefraction,
              appearance: widget.barAppearance,
            ),
          ],
        ),
        // The bar's own contact shadow, over the capsule's glass and
        // under the icons. Being in the inner stack puts it inside the
        // outer view's capture, so the moving pill refracts it too.
        if (widget.barShadow != null)
          Positioned(
            left: _barLeft,
            bottom: _effBottomMargin,
            width: layout.width,
            height: layout.height,
            child: IgnorePointer(
              child: LiquidGlassShadow(
                blur: widget.barShadow!.blur,
                opacity: widget.barShadow!.opacity,
                color: widget.barShadow!.color,
                offset: widget.barShadow!.offset,
                cornerRadius: widget.barShadow!.cornerRadius ??
                    widget.barShape?.cornerRadius,
                inset: widget.barShadow!.inset,
                visible: widget.barShadow!.visible,
              ),
            ),
          ),
        // Cosmetic only — taps are owned by the outer gesture overlay.
        IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: LiquidGlassAnimatedBottomNavBarShell(
              items: widget.items,
              selectedIndex: _tabIndexCommitted,
              itemStyle: widget.itemStyle,
              layout: layout,
              left: _barLeft,
              bottom: _effBottomMargin,
              highlightFrac: pillFrac,
              highlightWidth: pillW,
              highlightHeight: pillH,
            ),
          ),
        ),
      ],
    );
  }
}
