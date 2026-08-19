import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import 'liquid_glass_tab_bar.dart';
import '../liquid_glass_tab_item.dart' show LiquidGlassTabBarItem;
import '../../lens/liquid_glass_lens.dart';
import '../../liquid_glass.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_spring.dart' show liquidGlassSpringStep;
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
/// [LiquidGlassTabBar.glassPill]: it owns the entire dual
/// `LiquidGlassView` pipeline and is built by
/// [LiquidGlassTabBar.buildGlassPillBar] (which
/// `LiquidGlassScaffold` calls when the bar's `glassPill` mode resolves
/// for the active renderer). Prefer configuring it through
/// [LiquidGlassTabBar] — constructing it directly still works, but
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
/// Force, not speed: the pill deforms hardest as it launches off a tab
/// and as it brakes into the next, and sits undeformed at constant
/// speed. There is no lean term, so it deforms about its centre and
/// travels on the spring alone.
///
/// Under a **finger** the sign is the force's own, so the pill answers
/// the hand: push it right and it stretches wide, push it left and it
/// squashes narrow and tall.
///
/// A **travel** takes the same magnitudes but keys the sign to the
/// direction it is going ([_travelSign]) — a tap to the left stretches
/// the pill for the whole trip, a tap to the right holds it narrow and
/// tall. Signed on the force, a journey contradicted itself: the launch
/// pulled one way and the braking the other, and only the braking was
/// still on screen when you looked at the tab you had chosen. The
/// landing is unchanged; the launch now agrees with it.
///
/// Because the model reads the position the pill is actually drawn at,
/// every motion feeds it and none needs special-casing: a drag-release
/// snap genuinely IS a travel, and its braking is exactly the landing
/// deformation you want.
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
/// ## How the pill grows
///
/// The lift is a **held state**, not a pass the travel makes through a
/// bigger size. Tap a tab and the pill inflates at once, on springs
/// under critical damping so it overshoots its raised size and rebounds;
/// it stays there for the whole journey; and only once it has landed
/// ([handoverStart]) is the lift released, so it deflates where it
/// stands — dipping a little under its resting size and coming back.
/// A grab is the same thing held open by a finger.
///
/// Each axis carries its own spring, at damping ratios that differ just
/// enough that the width overshoots a shade further and settles a shade
/// later than the height. The material has a third, much faster one, so
/// the glass is fully on long before the size stops moving.
///
/// ## Handing over to the plain pill
///
/// A settled bar draws no glass at all — no shader pass, no clip, no
/// outer capture, no dual-layer icon reveal. The glass gets there by
/// **becoming** the plain pill rather than being cross-faded with one.
///
/// From the landing ([handoverStart]) the lens sheds its glass while
/// everything else keeps running: the rim and its contact shadow go
/// first, then the refraction band narrows to nothing behind them. The
/// deflation and the acceleration squash are untouched throughout — the
/// pill is still shrinking and still deforming while it stops looking
/// like glass.
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
  final LiquidGlassTabItemStyle itemStyle;

  /// Whether the persistent selection glass pill is drawn.
  final bool showSelectionPill;

  /// Whether the OUTER pipeline must keep capturing independently of the
  /// selection pill. Hosts that put lenses in [outerChild] must pass `true`.
  final bool outerNeedsRealtime;

  /// Bar geometry (size, position, padding). The bottom margin should
  /// already include any safe-area inset.
  final LiquidGlassTabBarLayout layout;

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

  /// How much taller than the bar the glass pill stands while it is
  /// lifted — which is the whole travel, not a peak it passes through.
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

  /// How far through a travel the pill counts as **landed**, `0`..`1` —
  /// the one moment the settle hangs off. At it the lift is released, so
  /// the pill starts deflating, and the hand-off to the plain twin
  /// begins with it.
  ///
  /// The default `0.92` is the last of the travel, where the spring is
  /// creeping the final pixels in: the pill arrives at full size and
  /// comes down where it stands, rather than shrinking on the way in.
  ///
  /// A press-and-hold is held up for as long as the finger is down, and
  /// then lands like any other travel — letting go starts the snap, not
  /// the settle.
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

  /// The Impeller-only magnifier pill under the glass one — see
  /// [LiquidGlassTabMagnifierPillStyle].
  final LiquidGlassTabMagnifierPillStyle magnifierPill;

  const LiquidGlassAnimatedNavBar({
    super.key,
    required this.body,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.itemStyle = const LiquidGlassTabItemStyle(),
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
      sampleWindow: 0.3,
      sensitivity: 0.00007,
      maxDeformation: 0.12,
      responseTime: 0.18,
    ),
    this.handoverStart = 0.92,
    this.handoverTau = 0.09,
    this.glassReturnTau = 0.05,
    this.pixelRatio = 1.0,
    this.useSync = true,
    this.useImpellerBackdrop,
    this.realTimeCapture = true,
    this.magnifierPill = const LiquidGlassTabMagnifierPillStyle(),
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

  /// Whether the pill is currently held up at its raised size. It goes
  /// up the instant a travel starts or a pill is grabbed, stays up for
  /// the whole journey, and only comes down once the pill has landed.
  bool _lifted = false;

  /// The raised size, one spring per axis. Both are under critical, so
  /// each end of the lift overshoots and rebounds rather than easing in
  /// — and the two ratios differ slightly, so the width overshoots a
  /// little further and settles a little later than the height. That
  /// small disagreement is what keeps the growth from reading as a
  /// plain scale-up.
  double _liftX = 0;
  double _liftXVel = 0;
  double _liftY = 0;
  double _liftYVel = 0;

  /// The material's own lift — how much of the glass is on. Critically
  /// damped and four times as stiff as the size springs, so the pill
  /// LOOKS like glass almost at once, and stops looking like it as soon
  /// as it lands, while its size is still wobbling into place.
  double _lift = 0;
  double _liftVel = 0;

  static const double _kLiftStiffness = 250;

  /// Damping ratio 0.6 across, 0.7 down (`ζ · 2√k`).
  static const double _kLiftDampingX = 19.0;
  static const double _kLiftDampingY = 22.1;

  static const double _kMaterialStiffness = 1000;
  static const double _kMaterialDamping = 63.3;

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

  /// Which way the current travel is headed — `-1` left, `1` right, `0`
  /// while a finger is driving the pill instead.
  ///
  /// A travel deforms by where it is GOING, not by which way the force
  /// happens to point this instant. The raw model is signed on the
  /// force, so a journey used to contradict itself: the launch and the
  /// braking pull the pill opposite ways, and only the second of the two
  /// is still on screen when you look. Keyed to the travel instead, the
  /// launch agrees with the landing — a tap to the left stretches the
  /// pill wide for the whole trip, a tap to the right holds it narrow
  /// and tall — and the landing itself is the deformation it always was.
  ///
  /// Only the travel is keyed this way. A finger keeps the raw force,
  /// where pushing right stretches and pushing left squashes: a drag is
  /// something you are doing to the pill, and it should answer the hand.
  double _travelSign = 0;

  /// The key the deformation is actually drawn with, which crosses
  /// between the two directions rather than switching.
  ///
  /// Tapping a tab on the other side mid-flight reverses [_travelSign]
  /// in one frame, and with it the entire deformation — a pill squashed
  /// narrow would be stretched wide on the very next frame. Crossing
  /// instead takes it through `0`, where the pill is drawn on the raw
  /// force it always was, so a reversal passes through undeformed
  /// instead of turning inside out. A travel starting from rest has
  /// nothing to cross and takes its key at once.
  double _travelSignEased = 0;

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

  /// True when the lenses render on the Impeller BackdropFilter path —
  /// the same resolution [LiquidGlassView] applies. Only there do
  /// stacked lenses chain (each samples everything painted beneath it),
  /// which is what the under-pill magnifier needs; the Skia capture
  /// path keeps the single glass pill exactly as it is.
  late final bool _useImpeller = (widget.useImpellerBackdrop ?? true) &&
      ui.ImageFilter.isShaderFilterSupported;

  LiquidGlassTabBarLayout get _layout => widget.layout;

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
    // The OUTER view is the one the moving pill samples on Skia, and it
    // sleeps at rest — so it is woken here, at the gesture, rather than
    // being left to the rebuilt widget's `realTimeCapture` flag alone.
    // The wake retires the sleep-time capture with it, so the pill's
    // first frame refracts the live bar and not the snapshot from
    // whenever the bar last settled. Idempotent when already live.
    if (!widget.outerNeedsRealtime) {
      _outerViewController.startRealtimeCapture();
    }
  }

  void _maybeStopCapture() {
    if (!_travelActive && !_tabDragging) {
      if (!widget.realTimeCapture) _innerViewController.stopRealtimeCapture();
      if (!widget.outerNeedsRealtime) {
        _outerViewController.stopRealtimeCapture();
      }
    }
  }

  // ── Selection / animation ────────────────────────────────────────
  void _animateTo(int next, {required bool notify}) {
    if (next == _tabIndex) return;
    setState(() {
      _tabIndex = next;
      _travelActive = true;
      _lifted = true;
      // Retarget from wherever the pill currently is; the spring keeps
      // its velocity.
      _travelFrom = _travelPos;
      _travelTarget = next.toDouble();
      _travelSign = _signOfTravel(_travelTarget - _travelFrom);
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
    _tabDragging = true;
    _travelActive = false;
    _lifted = true;
    // The hand takes the deformation back off the travel.
    _travelSign = 0;
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
    // The pill stays lifted through the snap and comes down on landing,
    // exactly as a tap's does — letting go is not the end of the
    // journey, arriving is.
    setState(() {
      _tabDragging = false;
      _tabIndex = next;
      _travelActive = true;
      _travelPos = from;
      _travelVel = 0;
      _travelFrom = from;
      _travelTarget = next.toDouble();
      _travelSign = _signOfTravel(_travelTarget - _travelFrom);
    });
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  /// One frame of the pill's physics, all of which the bar owns: the
  /// travel spring, the smoothed follow while a finger is down, the lift
  /// springs, the acceleration squash and the hand-off. The pill widget
  /// is handed the results and draws them.
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

    // 3) The lift. The pill is raised for the whole journey and comes
    // down once it has landed — [handoverStart] is where "landed"
    // begins — so it arrives at full size and settles afterwards,
    // rather than deflating on the way in.
    // Arriving counts as landing whatever [handoverStart] says, so a
    // gate set past the end of the travel cannot strand the pill up.
    if (!_tabDragging &&
        (travelSettled || _travelProgress() >= widget.handoverStart)) {
      _lifted = false;
    }
    final double liftTarget = _lifted ? 1.0 : 0.0;
    final xr = _stepLift(
      _liftX,
      _liftXVel,
      liftTarget,
      dt,
      _kLiftStiffness,
      _kLiftDampingX,
    );
    _liftX = xr.$1;
    _liftXVel = xr.$2;
    final yr = _stepLift(
      _liftY,
      _liftYVel,
      liftTarget,
      dt,
      _kLiftStiffness,
      _kLiftDampingY,
    );
    _liftY = yr.$1;
    _liftYVel = yr.$2;
    final mr = _stepLift(
      _lift,
      _liftVel,
      liftTarget,
      dt,
      _kMaterialStiffness,
      _kMaterialDamping,
    );
    _lift = mr.$1;
    _liftVel = mr.$2;
    final bool liftSettled =
        !_lifted && _liftX == 0 && _liftY == 0 && _lift == 0;

    // 4) Commit only once the travel AND the lift have finished: the
    // deflation outlives the spring that carried the pill there.
    if (_travelActive && travelSettled && liftSettled && !_tabDragging) {
      _travelActive = false;
      _tabIndexCommitted = _tabIndex;
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

      // A key of zero is a destination like any other — grabbing a pill
      // mid-flight hands it back to the raw force, and that hand-back
      // crosses too.
      if (_travelSignEased == 0) {
        _travelSignEased = _travelSign;
      } else if (_travelSignEased != _travelSign) {
        const signTau = 0.25;
        _travelSignEased +=
            (_travelSign - _travelSignEased) * (1 - math.exp(-dt / signTau));
        if ((_travelSign - _travelSignEased).abs() < 0.01) {
          _travelSignEased = _travelSign;
        }
      }

      // Keep the force's MAGNITUDE — the launch peak, the lull at
      // constant speed, the braking peak — and take its sign from the
      // direction of travel, so the pill deforms one way for the whole
      // journey instead of turning itself inside out at the halfway
      // mark. A part-way key is a blend of the two, which is what makes
      // a reversal cross rather than switch. See [_travelSign].
      final double key = _travelSignEased;
      if (key != 0) {
        _deviation = _deviation * (1 - key.abs()) - key * _deviation.abs();
      }
    }

    // 6) The hand-off, on the same landing the deflation runs off: the
    // glass leaves as the pill starts coming down. It is a target, not a
    // switch, so tapping again mid-hand-off turns the glass straight
    // back around instead of restarting it.
    final double handoverTarget = _lifted ? 0 : 1;
    final double tau =
        handoverTarget > _handover ? widget.handoverTau : widget.glassReturnTau;
    _handover += (handoverTarget - _handover) * (1 - math.exp(-dt / tau));
    if ((handoverTarget - _handover).abs() < 0.002) _handover = handoverTarget;

    // Everything must be finished — not just the travel. The deflation
    // and the squash both outlive the spring (the squash's sampling
    // window has to drain), and the hand-off outlives all of them, so
    // stopping on the spring alone would freeze the pill mid-shrink,
    // mid-deformation or mid-fade.
    final bool motionSettled = _deviation.abs() < 0.0005;
    final bool handoverSettled = _handover >= 1.0;
    if (!_travelActive &&
        !_tabDragging &&
        liftSettled &&
        motionSettled &&
        handoverSettled) {
      _pillMotion.stop();
      _deviation = 0;
      // Held until here, not dropped at the end of the travel: the
      // deformation drains after the spring does, and it has to drain
      // on the sense it was drawn with.
      _travelSign = 0;
      _travelSignEased = 0;
      _maybeStopCapture();
      _ticker?.stop();
    }

    if (mounted) setState(() {});
  }

  /// The direction key for a travel of [span] cells. A travel with no
  /// distance in it has no direction either, and keeps the raw force.
  double _signOfTravel(double span) => span.abs() < 1e-6 ? 0 : span.sign;

  /// One frame of a lift spring, snapped to its target once it has
  /// nothing left to say — so a settled lift compares equal to `0` and
  /// the bar can tell the deflation has finished.
  (double, double) _stepLift(
    double x,
    double vel,
    double target,
    double dt,
    double stiffness,
    double damping,
  ) {
    final r = liquidGlassSpringStep(
      x: x,
      vel: vel,
      target: target,
      dt: dt,
      stiffness: stiffness,
      damping: damping,
    );
    if ((r.$1 - target).abs() < 0.0008 && r.$2.abs() < 0.01) {
      return (target, 0.0);
    }
    return r;
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

      // The two ends of the lift: the cell the pill rests in, and the
      // raised glass it stands at while it is up — the same w:h ratio,
      // scaled so the glass is a touch bigger than the bar height.
      final Size pillRest = Size(layout.pillWidth, layout.cellHeight);
      final double liftedH = layout.height + widget.pillGrowHeight;
      final Size pillLifted =
          Size(liftedH * (layout.pillWidth / layout.cellHeight), liftedH);

      // How much of the glass is on. Its own spring, so the material
      // can be all the way in before the size is.
      final double morphProgress = _lift.clamp(0.0, 1.0);

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
      //
      // The envelope is the two lift springs, one per axis, rather than
      // one progress along a line between the two sizes: they overshoot
      // past the raised size and dip under the resting one, and they do
      // it by slightly different amounts.
      final Size envelopeSize = Size(
        pillRest.width + (pillLifted.width - pillRest.width) * _liftX,
        pillRest.height + (pillLifted.height - pillRest.height) * _liftY,
      );
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
          _liftX == 0 &&
          _liftY == 0 &&
          dev.abs() < 0.0005 &&
          !_travelActive &&
          !_tabDragging;
      final bool glassMounted = widget.showSelectionPill && !pillIsFlat;

      // The icon shell's reveal is cut to the size the pill says it is
      // drawing, so the selected colour wipes on exactly under the glass.
      final double? hlFrac = glassMounted ? pillFrac : null;
      final double? hlW = glassMounted ? liveSize.width : null;
      final double? hlH = glassMounted ? liveSize.height : null;

      // Impeller only: a pill-shaped magnifier that lives INSIDE the
      // inner stack, above the bar capsule but BELOW the icon shell —
      // same silhouette, same lift, travel, squash and shed as the
      // glass pill, but transparent, unblurred, undistorted, rimless
      // and shadowless. Painted there, its backdrop sample contains
      // only the page and the capsule, so under the pill the BAR reads
      // pushed back while the icons keep their size; the glass pill
      // above then refracts the receded bar and the crisp icons alike.
      // The Skia capture path cannot chain lenses and is untouched.
      final Widget? magnifierPill =
          (glassMounted && _useImpeller && widget.magnifierPill.enabled)
              ? Positioned.fill(
                  key: const ValueKey('lg-motion-nav-pill-magnifier'),
                  child: IgnorePointer(
                    child: LiquidGlassNavBarMotionPill(
                      center: Offset(pillCX, pillCY),
                      active: _lifted,
                      morphProgress: morphProgress,
                      envelopeSize: envelopeSize,
                      restSize: pillRest,
                      activeSize: pillLifted,
                      style: _magnifierStyle(
                        baseShape: widget.pillShape,
                        fallbackRadius: pillLifted.height / 2,
                        magnification: widget.magnifierPill.magnification,
                      ),
                      restStyle: _magnifierStyle(
                        baseShape: widget.restStyle.shape,
                        fallbackRadius: pillRest.height / 2,
                        magnification: 1,
                      ),
                      deviation: dev,
                      glassPresence: glassPresence,
                      honorBackdropAlpha: false,
                    ),
                  ),
                )
              : null;

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
              pillGlass: glassPresence,
              magnifier: magnifierPill,
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
                        active: _lifted,
                        // The bar owns the size as well as the squash;
                        // the pill's own morph spring stays out of it.
                        morphProgress: morphProgress,
                        envelopeSize: envelopeSize,
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
    final LiquidGlassRefraction refraction = widget.pillRefraction ??
        LiquidGlassRefraction(
          magnification: widget.pillMagnification,
          distortion: widget.pillDistortion,
          distortionWidth: widget.pillDistortionWidth,
          chromaticAberration: 0.002,
        );
    return LiquidGlassStyle(
      shape: widget.pillShape,
      appearance: LiquidGlassAppearance(
        color: widget.pillColor,
        blur: widget.pillBlur,
        enableInnerRadiusTransparent: widget.pillEnableInnerRadiusTransparent,
      ),
      // On Impeller the under-pill magnifier lens owns the magnification;
      // the glass pill on top must not compound it (m² in the middle).
      refraction: _useImpeller
          ? refraction.copyWith(magnification: 1)
          : refraction,
    );
  }

  /// The magnifier's silhouette: the shape the glass pill draws with at
  /// this end of the morph, stripped of everything visible — no rim, no
  /// glint. [base] mirrors the pill's own shape resolution ([fallbackRadius]
  /// is the capsule radius used when the host authored no shape).
  LiquidGlassShape _magnifierShape(LiquidGlassShape? base, double fallbackRadius) {
    final s = base;
    if (s == null) {
      return LiquidGlassShape(
        cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
        cornerRadius: fallbackRadius,
        borderWidth: 0,
        lightIntensity: 0,
      );
    }
    return LiquidGlassShape(
      cornerStyle: s.cornerStyle,
      clipQuality: s.clipQuality,
      lightMode: s.lightMode,
      cornerRadius: s.cornerRadius,
      borderWidth: 0,
      lightIntensity: 0,
      lightColor: s.lightColor,
      lightDirection: s.lightDirection,
      borderType: s.borderType,
    );
  }

  /// One end of the Impeller under-pill magnifier's material: pure
  /// magnification — fully transparent, zero blur, no distortion, no
  /// chromatic aberration, no rim. The lifted end carries
  /// [_magnifierMagnification]; the rest end carries `1`, so the
  /// magnification lerps in with the lift and back out through the
  /// handover on exactly the curve the glass material runs.
  LiquidGlassStyle _magnifierStyle({
    required LiquidGlassShape? baseShape,
    required double fallbackRadius,
    required double magnification,
  }) {
    return LiquidGlassStyle(
      shape: _magnifierShape(baseShape, fallbackRadius),
      appearance: const LiquidGlassAppearance(
        color: Color(0x00000000),
        blur: LiquidGlassBlur(sigmaX: 0, sigmaY: 0),
      ),
      refraction: LiquidGlassRefraction(
        distortion: 0,
        distortionWidth: 0,
        chromaticAberration: 0,
        magnification: magnification,
      ),
    );
  }

  /// Inner stack the outer view captures: wallpaper/body + bar capsule
  /// lens, with the icon shell drawn on top. [magnifier] (Impeller only)
  /// slots between the capsule and the icons, so it recedes the bar
  /// without touching the icons drawn above it.
  Widget _buildInner({
    required LiquidGlassTabBarLayout layout,
    double? pillFrac,
    double? pillW,
    double? pillH,
    double pillGlass = 0,
    Widget? magnifier,
  }) {
    final Widget background = widget.backgroundColor == null
        ? widget.body
        : ColoredBox(color: widget.backgroundColor!, child: widget.body);

    // The bar capsule's material: the caller's groups over the tuned
    // defaults, with the bar's contact shadow riding the appearance
    // (`appearance.shadow`) — the lens wraps itself in the ring, so it
    // paints behind the glass, lands inside the outer view's capture,
    // and the moving pill refracts it too. A shadow already carried by
    // [barAppearance] is honored when [barShadow] is unset.
    final LiquidGlassAppearance capsuleAppearance = widget.barAppearance ??
        LiquidGlassAppearance(
          color: Colors.white.withAlpha(22),
          blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
        );
    final LiquidGlassStyle capsuleStyle = LiquidGlassStyle(
      shape: widget.barShape ??
          LiquidGlassShape.roundedRectangle(
            cornerRadius: 40,
            borderWidth: 1.2,
            lightIntensity: 1.1,
            lightDirection: 80,
            borderType: const OpticalBorder(
              borderSaturation: 1.2,
              ambientIntensity: 1.0,
              borderSolidity: 0.35,
            ),
          ),
      appearance: widget.barShadow == null
          ? capsuleAppearance
          : capsuleAppearance.copyWith(shadow: widget.barShadow),
      refraction: widget.barRefraction ??
          const LiquidGlassRefraction(
            distortion: 0.07,
            distortionWidth: 28,
            chromaticAberration: 0.002,
          ),
    );

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
          children: const [],
          // The capsule is a layout-driven [LiquidGlassLens] in the
          // view's child slot: on Skia it refracts this view's captured
          // background, on Impeller the live backdrop. Placed off the
          // same [_barLeft]/[_effBottomMargin] the shell, the gesture
          // overlay and the pill already use, so the four can never
          // disagree by a pixel.
          child: Stack(
            children: [
              Positioned(
                left: _barLeft,
                bottom: _effBottomMargin,
                width: layout.width,
                height: layout.height,
                child: IgnorePointer(
                  child: LiquidGlassLens(style: capsuleStyle),
                ),
              ),
            ],
          ),
        ),
        // Impeller-only magnifier pill: painted here its backdrop sample
        // is the page + capsule (+ shadow) alone — the icon shell above
        // stays out of it, so the bar recedes under the pill while the
        // icons keep their size.
        if (magnifier != null) magnifier,
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
              underGlass: pillGlass,
            ),
          ),
        ),
      ],
    );
  }
}
