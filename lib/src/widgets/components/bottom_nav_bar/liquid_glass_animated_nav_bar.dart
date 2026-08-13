import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import 'liquid_glass_bottom_nav_bar.dart';
import '../liquid_glass_morph_pill.dart' show liquidGlassMorphEnvelope;
import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import '../../liquid_glass.dart';
import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_jelly_spring.dart' show liquidGlassSpringStep;
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_refresh_rate.dart';
import '../../utils/liquid_glass_shape.dart';
import '../../utils/liquid_glass_lens_motion.dart';
import 'liquid_glass_nav_bar_motion_pill.dart';
import '../liquid_glass_shadow.dart';

/// Self-contained **animated** liquid-glass bottom nav bar — the iOS-26
/// "morphing glass pill" that slides between tabs, grows out of the rest
/// highlight, can be picked up with a press-and-hold on the selected pill
/// and dragged, and reveals the selected icon as it passes.
///
/// This is the internal machinery behind
/// [LiquidGlassBottomNavBar.glassPill]: it owns the entire dual
/// `LiquidGlassView` pipeline and is built by
/// [LiquidGlassBottomNavBar.buildGlassPillBar] (which
/// `LiquidGlassScaffold` calls when the bar's `glassPill` mode resolves
/// for the active renderer). Prefer configuring it through
/// [LiquidGlassBottomNavBar] — constructing it directly still works, but
/// it will be hidden from the public API in 3.0.
///
/// ## How the pill deforms
///
/// The BAR runs [LiquidGlassLensMotion], not the glass widget: its drawn
/// position is sampled every frame in PIXELS, differentiated twice, and
/// the averaged acceleration scales it oppositely on the two axes —
///
///     scaleX = 1 + d      scaleY = 1 − d
///
/// Accelerating out of a tab stretches the pill wide and flat; braking
/// into the next one squashes it narrow and tall; constant-speed travel
/// leaves it undeformed. Force, not speed — and no lean term, so the pill
/// deforms about its centre and travels on the spring alone.
///
/// Because the model reads the position the pill is actually drawn at,
/// every motion feeds it and none needs special-casing: a drag-release
/// snap genuinely IS a motion, and its braking is exactly the landing
/// squash you want.
///
/// It lives on the bar because the deformation belongs to the selection
/// pill as a thing, not to whichever widget is drawing it this frame. The
/// glass and the plain pill are both drawn at the size it produces, so it
/// runs unbroken across the hand-off between them — and it outlives the
/// glass, which is where the landing squash actually happens.
///
/// ## How the deformation is drawn
///
/// The pill is a [LiquidGlassNavBarMotionPill] — a lens widget — in the
/// outer view's `child:` slot. Its shape is evaluated at the ENVELOPE
/// (rest) size and the deformation rides the shader's `u_shapeScale` with
/// matching elliptical clips, so the outline STRETCHES as one body and
/// the end caps go elliptical rather than the capsule being re-rounded at
/// each new size. The outer view's capture is the inner stack, so the
/// pill still bends the bar's own glass.
///
/// One consequence to know about: the view paints its `child:` slot BELOW
/// its positioned `children:`, so the pill sits under [outerLenses]
/// rather than over them. Nothing overlaps a bottom-anchored pill in
/// practice — an app bar is at the top, a side action sits beside the bar
/// — but a host that deliberately put glass over the pill's own cells
/// would see the difference.
///
/// ## Handing over to the plain pill
///
/// A settled bar draws no glass at all — no shader pass, no clip, no
/// outer capture, no dual-layer icon reveal. The glass gets there by
/// **becoming** the plain pill rather than being cross-faded with one.
///
/// Starting on approach ([handoverStart]), or the instant a held pill is
/// released, the lens sheds its glass while everything else keeps
/// running: the rim and its contact shadow go first, then the refraction
/// band narrows to nothing behind them. The travel, the lift and the
/// acceleration squash are untouched throughout — the pill is still
/// moving and still deforming while it stops looking like glass.
///
/// Only once there is nothing left in it to see — no glass, no lift, no
/// deformation — is the lens dropped and
/// `LiquidGlassBottomNavPillStatic` put in its place. By then the lens is
/// drawing a flat fill at rest size, which is exactly what the plain pill
/// draws, so the exchange is two identical pictures. That is what keeps
/// the plain pill plain: it never needs the deformation, the stretched
/// outline or an opacity, because it only ever appears once all three
/// have finished.
///
/// [handoverStart] is a target rather than a switch, so tapping another
/// tab mid-hand-off turns the glass straight back around
/// ([glassReturnTau]) instead of finishing and starting over.
///
/// [body] is the page content, captured behind the glass. [outerLenses]
/// are composited in the outer view on top of the bar (e.g. the app bar
/// and the side action button).
class LiquidGlassAnimatedNavBar extends StatefulWidget {
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

  /// The pill's acceleration squash/stretch tuning, applied on both
  /// finger-drags and tap-travel.
  ///
  /// The default caps the deformation at ±12 % rather than the free-floating
  /// ±30 % a slider thumb can afford: this pill lives inside the bar
  /// capsule, and a third of its height in overhang would climb out of it.
  final LiquidGlassLensMotionSpec motion;

  /// How far through a travel the pill starts handing over to its plain
  /// twin, `0`..`1`. The default `0.72` begins it once the pill is nearly
  /// home, so the glass is shed on approach rather than on arrival.
  ///
  /// A press-and-hold ignores this: letting go starts the hand-off at
  /// once, since the release is the moment the pill stops being held.
  final double handoverStart;

  /// Time constant of the hand-off — glass → plain. Larger is slower.
  final double handoverTau;

  /// Time constant of the reverse — plain → glass, when a travel starts
  /// or a pill is picked up. Shorter than [handoverTau]: glass that is
  /// slow to arrive reads as lag, while glass that is slow to leave reads
  /// as settling.
  final double glassReturnTau;

  // Render pipeline knobs forwarded to both views.
  final double pixelRatio;
  final bool useSync;
  final bool? useImpellerBackdrop;

  /// Whether the **inner** view (body + bar capsule) captures every frame.
  final bool realTimeCapture;

  const LiquidGlassAnimatedNavBar({
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
    // Inert at rest: the moving pill hands over to a non-refracting
    // static pill, so any glass left here would pop off at the swap.
    this.restStyle = const LiquidGlassStyle(
      appearance: LiquidGlassAppearance(color: Color(0x26FFFFFF)),
      refraction: LiquidGlassRefraction(
        distortion: 0,
        distortionWidth: 0,
        chromaticAberration: 0,
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
    this.handoverStart = 0.72,
    this.handoverTau = 0.09,
    this.glassReturnTau = 0.05,
    this.pixelRatio = 1.0,
    this.useSync = true,
    this.useImpellerBackdrop,
    this.realTimeCapture = true,
  });

  @override
  State<LiquidGlassAnimatedNavBar> createState() =>
      _LiquidGlassAnimatedNavBarState();
}

class _LiquidGlassAnimatedNavBarState extends State<LiquidGlassAnimatedNavBar>
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

  /// Drag-release state and the shrink envelope it settles on.
  bool _settlingFromDrag = false;
  double _settleGrow = 0;

  /// Grow-in multiplier for a glass surface appearing from rest.
  double _glassAppear = 1;

  /// How long that grow-in takes, chosen per gesture.
  double _glassAppearSeconds = _kGrabAppear;

  /// A **tap** has to finish growing well inside the travel, or the ramp
  /// caps the pill's size rather than merely easing it in — at the grab's
  /// rate the pill was still climbing when the morph envelope had already
  /// turned around, and peaked at ~0.73 of its lifted size without ever
  /// reaching it.
  static const double _kTapAppear = 0.05;

  /// A **grab** is not racing anything: the pill is lifted for as long as
  /// the finger is down, so it can rise at its own pace.
  static const double _kGrabAppear = 0.15;

  /// The pill's acceleration squash/stretch — owned by the BAR, not by
  /// the glass pill.
  ///
  /// The deformation belongs to the selection pill as a thing, not to
  /// whichever widget happens to be drawing it. Both the glass and the
  /// plain pill are drawn at the size this produces, so a hand-off in the
  /// middle of a squash is invisible; and it keeps running after the
  /// glass is gone, which is where the landing squash actually lands.
  late final LiquidGlassLensMotion _pillMotion =
      LiquidGlassLensMotion(spec: widget.motion);
  double _deviation = 0;

  /// How far the pill has shed its glass. `0` = the full material, `1` =
  /// a flat fill indistinguishable from the plain pill.
  double _handover = 1;

  /// Pill centre, recomputed on the ticker so the motion model samples
  /// the position the pill is drawn at this frame — not last frame's.
  Offset _pillCenter = Offset.zero;
  bool _pillCenterValid = false;

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
  }

  /// Starts the shared ticker if it isn't already running.
  void _startTicker() {
    if (_ticker?.isActive != true) {
      _tickerLast = null;
      _ticker?.start();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassAnimatedNavBar oldWidget) {
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
    if (!_travelActive && !_tabDragging) {
      _glassAppear = 0;
      _glassAppearSeconds = _kTapAppear;
    }
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
    if (!_travelActive && !_tabDragging) {
      _glassAppear = 0;
      _glassAppearSeconds = _kGrabAppear;
    }
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

    // 3) Drag-release shrink.
    if (_settlingFromDrag && _settleGrow > 0) {
      const tau = 0.06;
      _settleGrow *= math.exp(-dt / tau);
      if (_settleGrow < 0.01) _settleGrow = 0;
    }
    final bool growSettled = !_settlingFromDrag || _settleGrow == 0;

    // 4) Commit only after both the travel and the drag shrink settle.
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

    // 5) Sample the pill where it is drawn THIS frame, in pixels. Done
    // here rather than from the last build so the model never reads a
    // frame-old position, and so it keeps running once the glass is gone.
    if (_pillCenterValid) {
      _pillCenter = _resolvePillCenter();
      if (!_pillMotion.isTracking) _pillMotion.start();
      _pillMotion.track(
        _pillCenter,
        now: elapsed.inMicroseconds / 1e6,
        dt: dt,
      );
      _deviation = _pillMotion.deviation;
    }

    // 6) The hand-off. It begins when the pill is nearly home — or the
    // instant a held pill is let go — and it is a target, not a switch,
    // so tapping again mid-hand-off turns the glass straight back around
    // instead of restarting it.
    final double handoverTarget;
    if (_tabDragging) {
      handoverTarget = 0;
    } else if (_settlingFromDrag) {
      handoverTarget = 1;
    } else if (_travelActive) {
      handoverTarget = _travelProgress() >= widget.handoverStart ? 1 : 0;
    } else {
      handoverTarget = 1;
    }
    final double tau =
        handoverTarget > _handover ? widget.handoverTau : widget.glassReturnTau;
    _handover += (handoverTarget - _handover) * (1 - math.exp(-dt / tau));
    if ((handoverTarget - _handover).abs() < 0.002) _handover = handoverTarget;

    // Everything must be finished — not just the travel. The squash
    // outlives the spring (its sampling window has to drain), and the
    // hand-off outlives both, so stopping on the spring alone would
    // freeze the pill mid-deformation or mid-fade.
    final bool motionSettled = _deviation.abs() < 0.0005;
    final bool handoverSettled = _handover >= 1.0;
    if (!_travelActive && !_tabDragging && motionSettled && handoverSettled) {
      _pillMotion.stop();
      _deviation = 0;
      _maybeStopCapture();
      _ticker?.stop();
    }

    if (mounted) setState(() {});
  }

  /// How far through the current travel the pill is, `0`..`1`.
  double _travelProgress() {
    final double span = (_travelTarget - _travelFrom).abs();
    if (span < 1e-6) return 1;
    return (1 - (_travelTarget - _travelPos).abs() / span).clamp(0.0, 1.0);
  }

  /// The pill's centre in the outer view's coordinates, from the current
  /// spring/drag state and the geometry the last build resolved.
  Offset _resolvePillCenter() {
    final layout = _layout;
    final double frac = _tabDragging ? _dragFollow : _travelPos;
    return Offset(
      _barLeft +
          layout.padding +
          frac * layout.cellWidth +
          layout.pillWidth / 2,
      _pillCenter.dy,
    );
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

      // Rest/lift timing of the morph envelope.
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
      // Hand the row's Y to the ticker, which re-derives X itself each
      // frame. Until layout has run once there is no centre to sample, so
      // the model stays parked rather than tracking a bogus origin.
      _pillCenter = Offset(pillCX, pillCY);
      _pillCenterValid = true;

      // The size the pill would be with no deformation, and the size it is
      // actually drawn at. The deformation is the BAR's, so it applies to
      // whichever pill is on screen — including both at once, mid-hand-off.
      final Size envelopeSize = Size.lerp(
        pillRest,
        pillLifted,
        morphProgress.clamp(0.0, 1.0),
      )!;
      final double dev = _deviation;
      final Size liveSize = Size(
        envelopeSize.width * (1 + dev),
        envelopeSize.height * (1 - dev),
      );

      // How much of the pill still reads as glass. It sheds the rim, its
      // shadow and its refraction on this, and keeps everything else —
      // the travel, the lift, the squash — running underneath.
      final double glassPresence = (1 - _handover).clamp(0.0, 1.0);

      // The lens stays until there is nothing left in it to see: no glass,
      // no lift and no deformation. By then it is drawing a flat fill at
      // rest size — exactly what the plain pill draws — so handing over is
      // a swap of two identical pictures and needs no cross-fade, and the
      // plain pill never has to know about the motion.
      final bool pillIsFlat = glassPresence <= 0 &&
          morphProgress <= 0 &&
          dev.abs() < 0.0005 &&
          !_travelActive &&
          !_tabDragging;
      final bool glassMounted = widget.showSelectionPill && !pillIsFlat;

      // The icon shell's reveal is cut to the size the pill says it is
      // drawing, so the selected colour wipes on exactly under the glass.
      final double? hlFrac = glassMounted ? pillFrac : null;
      final double? hlW = glassMounted ? liveSize.width : null;
      final double? hlH = glassMounted ? liveSize.height : null;

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
                      child: LiquidGlassNavBarMotionPill(
                        center: Offset(pillCX, pillCY),
                        active: morphProgress > 0,
                        morphProgress: morphProgress,
                        restSize: pillRest,
                        activeSize: pillLifted,
                        style: _pillStyle(),
                        restStyle: widget.restStyle,
                        // The bar owns the model; the pill just draws it.
                        deviation: dev,
                        glassPresence: glassPresence,
                        shadow: widget.pillShadow,
                        honorBackdropAlpha: false,
                      ),
                    ),
                  )
                // Flat: the same rect the glass just vacated, painted as a
                // plain fill. Placed from the pill's own centre rather than
                // re-derived from the committed index, so the two can never
                // disagree by a pixel at the hand-off.
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
