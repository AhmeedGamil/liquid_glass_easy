import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_jelly_config.dart';
import '../../utils/liquid_glass_jelly_resolver.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_shape.dart';
import '../../utils/liquid_glass_jelly_spring.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_refresh_rate.dart';
import '../liquid_glass_morph_pill.dart' show liquidGlassMorphEnvelope;
import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_bottom_nav_bar.dart';

/// Self-contained **animated** liquid-glass bottom nav bar —
/// the iOS-26 "morphing glass pill" that slides between tabs, grows out
/// of the rest highlight, can be picked up with a press-and-hold on the
/// selected pill and dragged with a jelly-spring stretch, and reveals
/// the selected icon as it passes.
///
/// This is the internal machinery behind
/// [LiquidGlassBottomNavBar.glassPill]: it owns the entire dual
/// `LiquidGlassView` pipeline and is built by
/// [LiquidGlassBottomNavBar.buildGlassPillBar] (which
/// `LiquidGlassScaffold` calls when the bar's `glassPill` mode resolves
/// for the active renderer). Prefer configuring it through
/// [LiquidGlassBottomNavBar] — constructing it directly still works,
/// but it will be hidden from the public API in 3.0.
///
/// [body] is the page content, captured behind the glass. [outerLenses]
/// are composited in the outer view on top of the bar (e.g. the app bar
/// and the side action button).
class LiquidGlassAnimatedNavBar extends StatefulWidget {
  final Widget body;
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Icon + label styling for every tab cell. Forwarded to the shell so
  /// the glass tier honors the same [LiquidGlassNavItemStyle] as the
  /// non-glass tiers.
  final LiquidGlassNavItemStyle itemStyle;

  /// Whether the selection highlight (the moving glass pill + the static
  /// rest pill) is drawn. When `false`, only the icons show and the
  /// selected tab is colored via the shell's `selectedIndex`.
  final bool showSelectionPill;

  /// Whether the OUTER pipeline must keep capturing even while the glass
  /// pill is hidden.
  ///
  /// The outer view exists to composite the moving pill, but the host's own
  /// lens-anywhere widgets — an app bar, a side action, extra `lenses` —
  /// also live in it and refract its capture. When there are none, the
  /// capture has nothing to feed the moment the pill is gone, and running it
  /// rasterizes the whole page every frame for a view that composites
  /// nothing. That is the difference between the glass-pill bar and the
  /// plain one on an idle screen.
  ///
  /// `false` (the default) lets the capture stop at rest and wake with the
  /// pill. Hosts that put lenses in [outerChild] must pass `true`.
  final bool outerNeedsRealtime;

  /// Bar geometry (size, position, padding). The bottom margin should
  /// already include any safe-area inset.
  final LiquidGlassBottomNavBarLayout layout;

  /// Lenses composited in the **outer** view, above the bar — typically
  /// the app bar, the side action button, and any extra glass.
  ///
  /// Legacy positional API; prefer [outerChild] for widget-based slots.
  final List<LiquidGlass> outerLenses;

  /// Widget subtree composited in the **outer** view's `child:` slot,
  /// above the captured bar/body — typically a full-screen `Stack` of
  /// the app bar and side action ([LiquidGlassLens]-based widgets). This
  /// is the lens-anywhere replacement for [outerLenses].
  final Widget? outerChild;

  /// Optional solid color behind [body].
  final Color? backgroundColor;

  /// Custom placement for the bar. When non-null, the capsule, pill,
  /// icon shell, rest pill, and gesture overlay all honor it (resolved
  /// against the parent size). When `null` the bar is bottom-center
  /// anchored via [layout]'s `bottomMargin`.
  final LiquidGlassPosition? barPosition;

  /// Overrides the bar-capsule glass shape (e.g. a
  /// [LiquidGlassShape] or a custom radius/clip). When null,
  /// the default optical capsule is used.
  final LiquidGlassShape? barShape;

  /// Refraction of the bar capsule. When `null`, the default optical
  /// capsule refraction is used.
  final LiquidGlassRefraction? barRefraction;

  /// Appearance (tint + blur) of the bar capsule. When `null`, the
  /// default frost is used.
  final LiquidGlassAppearance? barAppearance;

  /// Blur behind the moving glass pill. Defaults to none.
  final LiquidGlassBlur pillBlur;

  /// How much taller the glass pill grows than the bar at peak travel —
  /// the pill's size knob. Peak height is `layout.height + pillGrowHeight`.
  final double pillGrowHeight;

  /// Refraction strength of the moving glass pill.
  final double pillDistortion;

  /// Width of the glass pill's refraction band.
  final double pillDistortionWidth;

  /// Complete refraction configuration for the moving pill. When set, this
  /// supersedes [pillDistortion], [pillDistortionWidth], and
  /// [pillMagnification].
  final LiquidGlassRefraction? pillRefraction;

  /// Magnification of the content seen through the glass pill.
  final double pillMagnification;

  /// When `true`, the glass pill's inner area is transparent.
  final bool pillEnableInnerRadiusTransparent;

  /// Overrides the moving glass pill's shape. When `null` the pill is an
  /// Apple capsule-style [LiquidGlassShape] whose radius
  /// tracks the pill height (a clean capsule as it grows/squashes).
  final LiquidGlassShape? pillShape;

  /// Fill tint of the moving glass pill.
  final Color pillColor;

  /// Look of the static rest pill (the highlight shown when the glass
  /// pill is not moving): its `appearance.color` is the fill, `shape` the
  /// corners, and a border is drawn only when the shape sets a
  /// `borderColor`.
  final LiquidGlassStyle restStyle;

  /// Stiffness of the spring carrying the pill between tabs.
  final double travelStiffness;

  /// Damping of the travel spring. Critical (no overshoot) ≈
  /// `2·√travelStiffness`; below it the pill bounces.
  final double travelDamping;

  /// The pill's jelly squash/stretch tuning, applied on both finger-drags
  /// and tap-travel. The nav bar is **locked to the iOS
  /// [LiquidGlassJellyStyle.squashStretch]** model — any
  /// [LiquidGlassJellyConfig.style] passed here is ignored and normalized
  /// to `squashStretch`. The original `pinchExtrude` model is kept internally
  /// (it still drives [LiquidGlassJelly]) but is not selectable here; all
  /// other fields are honored.
  final LiquidGlassJellyConfig jelly;

  // Render pipeline knobs forwarded to both views.
  final double pixelRatio;
  final bool useSync;
  final bool? useImpellerBackdrop;

  /// Whether the **inner** view (body + bar capsule) captures every
  /// frame. `true` (default) keeps the bar's refraction live as the
  /// body scrolls/animates — important on Skia, where the capsule reads
  /// a captured snapshot. `false` falls back to snapshot-at-rest and
  /// only wakes the inner pipeline during a morph (cheaper for a static
  /// body). No effect on Impeller, which always samples the live
  /// backdrop.
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
    ),
    this.travelStiffness = 280,
    this.travelDamping = 31.4,
    // Kept in sync with [LiquidGlassNavPillStyle]'s iOS squash & stretch
    // default (softer snap + longer direction memory).
    this.jelly = const LiquidGlassJellyConfig(
      style: LiquidGlassJellyStyle.squashStretch,
      stiffness: 260,
      damping: 13,
      maxVelocity: 6,
      velocityClamp: 60,
      stretchWidth: 17.1,
      squashHeight: 9.8,
      anchorBias: -1.0,
      recoilScale: 3.0,
      recoilAnchor: 1.0,
      directionTau: 0.42,
    ),
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

  /// True while the glass pill should be on screen (animating/dragging,
  /// or fading out).
  bool _pillGlassActive = false;
  bool _settlingFromDrag = false;

  // ── Glass→static cross-fade ──────────────────────────────────────
  // When the pill settles, the glass pill fades OUT (a true opacity fade
  // of the whole pill); once it's gone the static rest pill fades IN. A
  // new interaction cancels an in-flight fade.
  /// Opacity of the moving glass pill (`1` while live; ramps 1→0 to fade).
  double _glassOpacity = 1.0;

  /// Appear progress of the glass pill (`0`→`1`): drives both a fade-in and
  /// a grow-in so the pill doesn't pop in at full size. Reset to `0` each
  /// time the pill appears from rest.
  double _glassAppear = 1.0;

  /// True while the glass pill is fading out (kept on screen meanwhile).
  bool _fadingOutGlass = false;

  /// True while the static rest pill is fading in (after the glass is gone).
  bool _fadingInStatic = false;

  /// Opacity of the static rest pill (`1` at rest; ramps 0→1 on fade-in).
  double _staticOpacity = 1.0;

  static const double _glassFadeSeconds = 0.28;
  static const double _staticFadeSeconds = 0.26;
  static const double _glassAppearSeconds = 0.15;

  /// Fractional pill position (0..itemCount-1). While dragging this is
  /// the finger's target; the pill is drawn at [_dragFollow], a smoothed
  /// chase of it (so a hold away from the pill glides over).
  double _tabPillFracIndex = 0;
  double _dragFollow = 0;
  bool _tabDragging = false;

  /// Fractional position of the initial press, captured at long-press
  /// start. A click (a press that never became a real drag) commits to
  /// THIS cell, so a quick press always selects exactly where it landed
  /// instead of borrowing the drag glide's lagging follow position.
  double _pressFrac = 0;

  /// True once the finger has moved far enough from [_pressFrac] to count
  /// as a genuine drag — distinguishes a hold-and-slide from a click that
  /// merely tripped the long-press recognizer (jittery tap-to-click).
  bool _draggedRealMove = false;

  // ── Travel spring ────────────────────────────────────────────────
  // The pill's position is spring-driven (same underdamped integrator
  // as the jelly), so a tap travels with momentum and settles with a
  // single soft overshoot instead of an eased tween.
  double _travelPos = 0;
  double _travelVel = 0;
  double _travelTarget = 0;

  /// Position the current travel started from — used to derive the
  /// morph-grow envelope's progress.
  double _travelFrom = 0;

  /// True from the moment a travel starts until the spring settles.
  bool _travelActive = false;

  /// Grow envelope value during the drag-release settle (decays 1 → 0).
  double _settleGrow = 0;

  /// Jelly simulation (in tab-fraction units), shared by finger-drags
  /// and tap-travel. Its spring constants are pushed from [widget.jelly]
  /// each frame by [_syncJellyConfig].
  final LiquidGlassJellySpring _dragJelly =
      LiquidGlassJellySpring(maxVelocity: 6, velocityClamp: 60);

  /// True once the current tap-travel has handed the jelly its release
  /// (so the recoil/settle fires exactly once per travel, not every tick
  /// while the spring finishes converging).
  bool _travelReleased = false;

  /// Whether the active travel should drive the jelly. A tap-travel does
  /// (the spring motion IS the input); a drag-release travel does NOT —
  /// the finger already loaded and released the jelly, so the positional
  /// snap to the nearest tab must not re-pump it.
  bool _travelFeedsJelly = false;

  /// Pushes the current [widget.jelly] tuning into the live spring.
  void _syncJellyConfig() {
    final j = widget.jelly;
    _dragJelly
      ..stiffness = j.stiffness
      ..damping = j.damping
      ..maxVelocity = j.maxVelocity
      ..velocityClamp = j.velocityClamp
      ..directionTau = j.directionTau;
  }

  /// Single ticker driving the travel spring, the drag jelly and the
  /// settle-grow decay.
  Ticker? _ticker;
  Duration? _tickerLast;

  /// Absolute left edge of the bar in the parent, recomputed each build
  /// from [LiquidGlassAnimatedNavBar.barPosition] (or centered). Used by
  /// the drag math so the pill tracks a moved bar.
  double _barLeft = 0;

  /// Effective bottom inset of the bar (from a custom position, or the
  /// layout's `bottomMargin`).
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

  /// Starts the shared ticker if it isn't already running. The ticker's
  /// `elapsed` restarts from zero on every `start()`, so the last-seen
  /// timestamp must be cleared or the first `dt` would be negative.
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
  // When [LiquidGlassAnimatedNavBar.realTimeCapture] is true the inner
  // view already captures every frame (so a scrolling/animated body
  // refracts live), and these are no-ops. When it's false the inner
  // pipeline is snapshot-only at rest and we briefly wake it during a
  // morph so the moving glass has live frames to refract.
  void _startCapture() {
    if (!widget.realTimeCapture) _innerViewController.startRealtimeCapture();
  }

  void _maybeStopCapture() {
    if (widget.realTimeCapture) return; // keep the inner pipeline live
    if (!_travelActive && !_tabDragging) {
      _innerViewController.stopRealtimeCapture();
    }
  }

  // ── Glass→static cross-fade ──────────────────────────────────────
  /// Cancels any in-flight glass-fade / static-fade so a new interaction
  /// shows the glass pill at full strength again.
  void _cancelFades() {
    _fadingOutGlass = false;
    _fadingInStatic = false;
    _glassOpacity = 1.0;
    _staticOpacity = 1.0; // static is hidden under the active glass anyway
  }

  // ── Selection / animation ────────────────────────────────────────
  void _animateTo(int next, {required bool notify}) {
    if (next == _tabIndex) return;
    // If the pill is coming back from rest, grow + fade it in.
    final bool wasInactive = !_pillGlassActive && !_tabDragging;
    _cancelFades();
    if (wasInactive) _glassAppear = 0.0;
    setState(() {
      _tabIndex = next;
      _pillGlassActive = true;
      _settlingFromDrag = false;
      _travelActive = true;
      // Retarget from wherever the pill currently is (so a tap during
      // a travel is handled gracefully); the spring keeps its velocity.
      _travelFrom = _travelPos;
      _travelTarget = next.toDouble();
    });
    // Prime the jelly so the spring-driven travel motion deforms the
    // pill (squash/stretch) the same way a finger-drag would.
    _syncJellyConfig();
    _dragJelly.start(_travelPos);
    _travelReleased = false;
    _travelFeedsJelly = true;
    _startCapture();
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  // ── Gesture geometry ─────────────────────────────────────────────
  double _xToTabFrac(double globalDx) {
    // `_barLeft` is the bar's absolute left (honors a custom position).
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
  // Press-and-hold ANYWHERE on the bar lifts the pill and glides it to
  // the held position, then slides it across tabs while the finger moves;
  // releasing snaps it to the nearest tab. A quick tap still selects
  // instantly (handled by the tap recognizer). See [_onTabBarTapUp].

  void _onTabPillLongPressStart(LongPressStartDetails d) {
    // If the pill is coming back from rest, grow + fade it in.
    final bool wasInactive = !_pillGlassActive && !_tabDragging;
    _cancelFades();
    if (wasInactive) _glassAppear = 0.0;
    _tabDragging = true;
    _pillGlassActive = true;
    _settlingFromDrag = false;
    _travelActive = false;
    _startCapture();
    final frac = _xToTabFrac(d.globalPosition.dx);
    // Start the smoothed follow at the pill's current resting position so
    // a hold away from the pill EASES over to the finger instead of
    // teleporting; _onTick chases the finger target from here.
    _dragFollow = _travelPos;
    _syncJellyConfig();
    _dragJelly.start(_dragFollow);
    _travelVel = 0;
    // Remember where the press landed; until the finger moves off it, this
    // is treated as a click and commits to this exact cell on release.
    _pressFrac = frac;
    _draggedRealMove = false;
    _startTicker();
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!_tabDragging) return;
    final frac = _xToTabFrac(d.globalPosition.dx);
    // Once the finger travels a fraction of a cell from the press point,
    // it's a real drag — release should settle to the glide, not the
    // pressed cell. Small jitter (tap-to-click) stays below this.
    if ((frac - _pressFrac).abs() > 0.2) _draggedRealMove = true;
    // Only set the destination; the pill (and its jelly) chase it via the
    // smoothed follow in _onTick.
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
    // The pill always travels FROM where it visually is (the smoothed
    // follow) so the motion is continuous. WHERE it commits depends on the
    // gesture: a real drag settles to the tab the glide reached; a click
    // (no real drag) commits to the cell that was pressed, so a quick press
    // lands exactly where it landed instead of on the lagging follow.
    final from = _dragFollow;
    final double snapFrac = _draggedRealMove ? from : _pressFrac;
    final next = snapFrac.round().clamp(0, _layout.itemCount - 1);
    final notify = next != _tabIndex;
    setState(() {
      _tabDragging = false;
      _settlingFromDrag = true;
      _tabIndex = next;
      _pillGlassActive = true;
      _travelActive = true;
      _travelFrom = from;
      _travelPos = from;
      _travelVel = 0;
      _travelTarget = next.toDouble();
      _settleGrow = 1.0;
    });
    // The finger already drove the jelly; the post-release positional
    // snap to the nearest tab must not re-pump it.
    _travelFeedsJelly = false;
    _travelReleased = true;
    _dragJelly.release();
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  /// One frame of the spring system: travel spring, drag jelly, and
  /// the drag-release grow decay. Commits the selection and drops the
  /// glass the moment everything has settled.
  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;

    // 1) Travel (positional) spring — advance before feeding the jelly,
    // so the jelly reads this frame's motion.
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

    // 2) Feed the jelly from a TAP-travel so the pill deforms like a
    // drag: pump the spring-driven position while moving, then hand it a
    // single release on arrival so it recoils and wobbles to rest. A
    // finger-drag feeds the jelly through its own handlers; a
    // drag-RELEASE snap does not feed it at all (_travelFeedsJelly).
    _syncJellyConfig();
    // While dragging, smoothly chase the finger target so a hold away
    // from the pill glides to the held position; the jelly is fed from
    // this smoothed motion so it deforms along the glide and the drag.
    if (_tabDragging) {
      const followTau = 0.05;
      _dragFollow +=
          (_tabPillFracIndex - _dragFollow) * (1 - math.exp(-dt / followTau));
      _dragJelly.pump(_dragFollow);
    }
    final bool travelFeeding =
        _travelActive && !_tabDragging && _travelFeedsJelly;
    if (travelFeeding && !travelSettled) {
      _dragJelly.pump(_travelPos);
    } else if (travelFeeding && travelSettled && !_travelReleased) {
      _dragJelly.release();
      _travelReleased = true;
    }
    final bool jellyDriven = _tabDragging || (travelFeeding && !travelSettled);
    final jellySettled = _dragJelly.tick(dt, dragging: jellyDriven);

    // 3) Drag-release grow decay — replaces the old 140ms linear shrink.
    if (_settlingFromDrag && _settleGrow > 0) {
      const tau = 0.06;
      _settleGrow *= math.exp(-dt / tau);
      if (_settleGrow < 0.01) _settleGrow = 0;
    }
    final growSettled = !_settlingFromDrag || _settleGrow == 0;

    // 4) Commit the selection once the pill has ARRIVED (travel + grow
    // settled), even if the jelly is still wobbling. The glass pill sits
    // over the committed index, so flipping it here causes no flash; the
    // recoil keeps playing on the now-committed pill.
    if (_travelActive && travelSettled && growSettled && !_tabDragging) {
      _travelActive = false;
      _settlingFromDrag = false;
      _settleGrow = 0;
      _tabIndexCommitted = _tabIndex;
    }

    // 4.5) Grow + fade the pill IN when it first appears.
    if (_glassAppear < 1.0) {
      _glassAppear += dt / _glassAppearSeconds;
      if (_glassAppear >= 1.0) _glassAppear = 1.0;
    }

    // 5) Cross-fade as soon as the pill ARRIVES (travel settled) and has
    // finished appearing — do NOT wait for the jelly recoil to die out, or
    // the fade is held back by the wobble. The pill fades while it finishes
    // its last little wobble. Once the glass is gone the static rest pill
    // fades in. A new interaction cancels this (see _cancelFades).
    final bool arrived = !_travelActive && !_tabDragging && _glassAppear >= 1.0;
    if (arrived && _pillGlassActive && !_fadingOutGlass) {
      _fadingOutGlass = true;
    }
    if (_fadingOutGlass) {
      _glassOpacity -= dt / _glassFadeSeconds;
      if (_glassOpacity <= 0) {
        _glassOpacity = 0;
        _fadingOutGlass = false;
        _pillGlassActive = false; // remove the (now invisible) glass pill
        _staticOpacity = 0;
        _fadingInStatic = true;
      }
    }
    if (_fadingInStatic) {
      _staticOpacity += dt / _staticFadeSeconds;
      if (_staticOpacity >= 1) {
        _staticOpacity = 1;
        _fadingInStatic = false;
      }
    }

    // Stop the ticker + capture only once the fades AND the jelly recoil
    // have all finished.
    if (arrived && jellySettled && !_fadingOutGlass && !_fadingInStatic) {
      _maybeStopCapture();
      _ticker?.stop();
    }

    if (mounted) setState(() {});
  }

  bool get _pillGlassVisible => _pillGlassActive || _tabDragging;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final parentWidth = constraints.maxWidth;
      final parentHeight = constraints.maxHeight;

      // Resolve the bar's placement. A custom position is honored by the
      // capsule, pill, shell, rest pill, and gesture overlay; otherwise
      // the bar is bottom-center anchored via the layout's bottomMargin.
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
      final dx = _barLeft - centeredLeft;
      final layout = _layout.copyWith(bottomMargin: _effBottomMargin);

      final cellW = layout.cellWidth;

      // Glass pill geometry: same w:h ratio as the rest pill, scaled
      // up so the glass is a touch bigger than the bar height.
      final glassOverflowPx = widget.pillGrowHeight;
      final restRatio = layout.pillWidth / layout.cellHeight;
      final targetGlassH = layout.height + glassOverflowPx;
      final targetGlassW = targetGlassH * restRatio;

      // Travel progress for the morph-grow envelope, derived from the
      // spring's remaining distance. An overshoot past the target
      // clamps to 1, so the pill is back at rest size while the
      // position wobble settles — the wobble reads in the motion, not
      // the geometry.
      final travelSpan = (_travelTarget - _travelFrom).abs();
      final travelP = travelSpan < 1e-6
          ? 1.0
          : (1.0 - (_travelTarget - _travelPos).abs() / travelSpan)
              .clamp(0.0, 1.0);

      // Morph-grow envelope.
      final double growT;
      if (_tabDragging) {
        growT = 1.0;
      } else if (_settlingFromDrag) {
        growT = _settleGrow;
      } else if (_travelActive) {
        growT = liquidGlassMorphEnvelope(travelP);
      } else {
        growT = 0.0;
      }

      final glassH =
          layout.cellHeight + (targetGlassH - layout.cellHeight) * growT;
      final glassW =
          layout.pillWidth + (targetGlassW - layout.pillWidth) * growT;
      final pillExtraH = glassH - layout.cellHeight;

      final basePillFrac = _tabDragging ? _dragFollow : _travelPos;

      final staticPillLeft =
          _barLeft + layout.padding + _tabIndexCommitted * cellW;
      final staticBottom = _effBottomMargin + layout.padding;

      // Jelly deformation — the same model as the slider thumb, fed by
      // both finger-drags and tap-travel (see _onTick). It produces a
      // width delta, a height delta, and a horizontal lean (px); the lean
      // is folded back into the pill's fractional index below.
      //
      //   • pinchExtrude — from the lean spring: squeeze narrower + grow
      //     taller while loaded, leaning into the motion.
      //   • stretch (iOS) — from the signed deform spring: elongate along
      //     the travel axis while moving, then recoil narrower + taller on
      //     arrival/reversal, with a momentum-sided crumple.
      // The nav pill is locked to the iOS jelly (squash & stretch) model:
      // normalize away any `pinchExtrude` the caller passed. That branch is
      // kept internally (used by [LiquidGlassJelly] and below) but is not
      // reachable through the nav bar's public API.
      final jelly = widget.jelly.style == LiquidGlassJellyStyle.squashStretch
          ? widget.jelly
          : widget.jelly.copyWith(style: LiquidGlassJellyStyle.squashStretch);
      double jellyDeltaW = 0;
      double jellyDeltaH = 0;
      double jellyBiasPx = 0;
      if (_pillGlassVisible) {
        // Squash/stretch via the shared resolver (single source of the
        // jelly geometry math — also used by LiquidGlassJelly and the
        // slider thumb). pinch derives its amounts from the pill width;
        // stretch uses the jelly's stretch/squash amounts.
        final bool isPinch = jelly.style == LiquidGlassJellyStyle.pinchExtrude;
        final deform = resolveJellyDeformation(
          style: isPinch
              ? LiquidGlassJellyStyle.pinchExtrude
              : LiquidGlassJellyStyle.squashStretch,
          springValue: isPinch ? _dragJelly.stretch : _dragJelly.deform,
          directionSign: _dragJelly.direction.isNegative ? -1.0 : 1.0,
          alongAmount: isPinch ? layout.pillWidth * 0.18 : jelly.stretchWidth,
          crossAmount:
              isPinch ? layout.pillExtraHeight * 0.18 : jelly.squashHeight,
          anchorBias: jelly.anchorBias,
          recoilScale: jelly.recoilScale,
          recoilAnchor: jelly.recoilAnchor,
          alongFloor: -layout.pillWidth * 0.45,
          crossFloor: -layout.cellHeight * 0.4,
        );
        jellyDeltaW = deform.along;
        jellyDeltaH = deform.cross;
        jellyBiasPx = deform.bias;
      }

      // Damp the jelly wobble by the pill's opacity so it subsides AS the
      // pill fades out — keeps the disappearance clean no matter how bouncy
      // a jelly the developer configures (no effect while opacity == 1).
      jellyDeltaW *= _glassOpacity;
      jellyDeltaH *= _glassOpacity;
      jellyBiasPx *= _glassOpacity;

      // Fold the horizontal lean into the fractional index (px → tabs).
      final pillFrac = basePillFrac + (cellW > 0 ? jellyBiasPx / cellW : 0.0);

      // Grow-in: when the pill appears it scales up from the STATIC-PILL
      // size (its extras → 0 at appear=0, so width/height = pillWidth ×
      // cellHeight) to its full glass size as _glassAppear ramps 0→1.
      final double effExtraW =
          ((glassW - layout.pillWidth) + jellyDeltaW) * _glassAppear;
      final double effExtraH = (pillExtraH + jellyDeltaH) * _glassAppear;

      final bool glassOn = _pillGlassVisible && widget.showSelectionPill;
      final double? hlFrac = glassOn ? pillFrac : null;
      final double? hlW = glassOn ? layout.pillWidth + effExtraW : null;
      final double? hlH = glassOn ? layout.cellHeight + effExtraH : null;

      return Stack(
        fit: StackFit.expand,
        children: [
          // OUTER view: captures the inner stack and composites the
          // moving glass pill + the developer's outer lenses on top.
          LiquidGlassView.withPositionedLenses(
            controller: _outerViewController,
            pixelRatio: widget.pixelRatio,
            useSync: widget.useSync,
            // Only capture while there is something to composite. With the
            // pill hidden and no host lenses this view rasterizes the whole
            // page every frame and draws nothing with it — the reason an
            // idle glass-pill bar cost far more than the plain one.
            //
            // `LiquidGlassView.didUpdateWidget` syncs its enabled flag when
            // this flips, and the morph ticker rebuilds on every tick, so
            // the capture wakes on the same frame the pill appears.
            realTimeCapture: glassOn || widget.outerNeedsRealtime,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            useImpellerBackdrop: widget.useImpellerBackdrop,
            backgroundWidget: _buildInner(
              layout: layout,
              pillFrac: hlFrac,
              pillW: hlW,
              pillH: hlH,
            ),
            // Outer slots (app bar, side action) live in the view's
            // `child:` subtree as lens-anywhere widgets (declared after
            // `children:` to satisfy sort_child_properties_last).
            children: [
              if (glassOn)
                buildLiquidGlassBottomNavPill(
                  // Constant key: the pill is added to / removed from this
                  // list as it animates. Without a stable key the lenses
                  // are matched by index, so toggling the pill renumbers
                  // the outer lenses and the app bar reuses the pill's
                  // `State` (and its bottom-anchored position) — shifting
                  // it. See `LiquidGlass.key`.
                  key: const ValueKey('lg-nav-morph-pill'),
                  layout: layout,
                  animatedIndex: pillFrac,
                  parentWidth: parentWidth,
                  dx: dx,
                  blur: widget.pillBlur,
                  distortion: widget.pillDistortion,
                  distortionWidth: widget.pillDistortionWidth,
                  refraction: widget.pillRefraction,
                  magnification: widget.pillMagnification,
                  enableInnerRadiusTransparent:
                      widget.pillEnableInnerRadiusTransparent,
                  shape: widget.pillShape,
                  color: widget.pillColor,
                  // Grow-in from the static-pill size: extras scaled by
                  // _glassAppear (0 → full).
                  extraHeight: effExtraH,
                  extraWidth: effExtraW,
                  // Fade in/out by opacity: grow-in fade (_glassAppear) on
                  // appear, fade-out (_glassOpacity) once the selection
                  // settles (then the static rest pill fades in).
                  opacity: _glassOpacity * _glassAppear,
                ),
              // Stable, role-based keys so each outer lens keeps its own
              // `State` regardless of whether the pill is currently in the
              // list. The outer-lenses order is invariant (app bar, extra
              // lenses, side action — they never reorder at runtime), so an
              // index-derived key here is stable; only the pill toggles.
              for (int i = 0; i < widget.outerLenses.length; i++)
                widget.outerLenses[i].key != null
                    ? widget.outerLenses[i]
                    : widget.outerLenses[i]
                        .copyWith(key: ValueKey('lg-nav-outer-$i')),
            ],
            child: widget.outerChild,
          ),
          // Static rest pill — only once the glass pill has fully faded
          // out. It fades IN (via _staticOpacity, 0→1) so the hand-off
          // reads as two sequential fades.
          if (!_pillGlassActive && !_tabDragging && widget.showSelectionPill)
            Positioned(
              key: const ValueKey('lg-animated-nav-pill-static'),
              left: staticPillLeft,
              bottom: staticBottom,
              child: Opacity(
                opacity: _staticOpacity.clamp(0.0, 1.0),
                child: LiquidGlassBottomNavPillStatic(
                  width: layout.pillWidth,
                  height: layout.cellHeight,
                  color: widget.restStyle.appearance.color,
                  shape: widget.restStyle.shape,
                ),
              ),
            ),
          // Unified gesture overlay: a quick tap on any cell selects it;
          // a press-and-hold on the *selected* pill lifts it to drag.
          // Both recognizers share one arena — tap wins a quick release,
          // the long-press wins once the hold deadline passes.
          Positioned(
            key: const ValueKey('lg-animated-nav-gesture-overlay'),
            left: _barLeft + layout.padding,
            bottom: staticBottom,
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

  /// Inner stack the outer view captures: wallpaper/body + bar capsule
  /// lens, with the icon shell drawn on top. The shell does the iOS-26
  /// dual-layer "icon highlights through the moving pill" reveal when
  /// [pillFrac]/[pillW]/[pillH] are supplied.
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
        // Cosmetic only — taps are owned by the outer gesture overlay.
        // Wrapped in a transparent Material so the shell's labels get a
        // DefaultTextStyle (otherwise they render with the debug yellow
        // underline).
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
