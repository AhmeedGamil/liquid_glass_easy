import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_jelly_config.dart';
import '../../utils/liquid_glass_jelly_spring.dart';
import 'liquid_glass_slider_touch.dart';
import 'liquid_glass_slider_layout.dart';
import 'liquid_glass_slider_thumb.dart';
import 'liquid_glass_slider_track.dart';

export 'liquid_glass_slider_layout.dart';
export 'liquid_glass_slider_thumb.dart';
export 'liquid_glass_slider_track.dart';

/// A drop-in liquid-glass slider.
///
/// This is the **developer-facing** component: it owns its own
/// [LiquidGlassView], the track ([LiquidGlassSliderTrack]), the moving
/// glass thumb ([buildLiquidGlassSliderThumb]) and all the interaction
/// animation (grow-on-press + the signed "jelly" spring that leans the
/// thumb in the drag direction) — so you just give it a [value] in
/// `0..1` and an [onChanged] like a regular `Slider`.
///
/// At rest it shows a solid white pill on the track. While the user
/// drags, the pill is replaced by a liquid-glass pill that grows, leans
/// into the motion, and refracts the track underneath.
///
/// ```dart
/// LiquidGlassSlider(
///   value: _v,
///   onChanged: (v) => setState(() => _v = v),
///   activeColor: Colors.white,
/// )
/// ```
///
/// The glass thumb overhangs the track; the shader honors the captured
/// texel's alpha (always on), so the overhang renders as transparent
/// passthrough instead of a black blob.
class LiquidGlassSlider extends StatefulWidget {
  /// Current value, in `0..1`.
  final double value;

  /// Called continuously with the new value while the user drags.
  final ValueChanged<double> onChanged;

  /// Called when a drag (or tap) begins.
  final ValueChanged<double>? onChangeStart;

  /// Called when the drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// Color of the filled (left) portion of the track.
  final Color activeColor;

  /// Color of the unfilled track background.
  final Color inactiveColor;

  /// Track + thumb geometry. Defaults to a 280-wide track.
  final LiquidGlassSliderLayout layout;

  /// Glass look of the moving thumb (shape + appearance + refraction),
  /// the same [LiquidGlassStyle] vocabulary used across the library. When
  /// null, the tuned default capsule glass is used. A null
  /// [LiquidGlassStyle.shape] keeps the height-tracking capsule so the
  /// thumb stays a clean pill as it grows/jellies during a drag.
  final LiquidGlassStyle? style;

  /// Capture resolution for the inner view. `1.0` is a good default; use
  /// less for cheaper captures, `0.0` for the device pixel ratio.
  final double pixelRatio;

  /// Jelly deformation tuning for the moving thumb. The slider is
  /// **locked to the iOS [LiquidGlassJellyStyle.squashStretch]** squash &
  /// stretch model (on-device-tuned) — any [LiquidGlassJellyConfig.style]
  /// you pass is ignored and normalized to `squashStretch`. The original
  /// `pinchExtrude` model is kept internally (it still drives
  /// [LiquidGlassJelly]) but is no longer selectable here. All the other
  /// fields — springs, stretch/squash amounts, anchors — are honored.
  final LiquidGlassJellyConfig jelly;

  /// **Experimental.** An alternative motion model for the thumb: the
  /// handle is towed toward your finger rather than pinned to it, and the
  /// gap that opens between them is what stretches the pill — including
  /// against the ends of the track, where the handle stops and the finger
  /// does not. See [LiquidGlassSliderTouch].
  ///
  /// Only where the glass is *drawn* lags; [value] and [onChanged] are
  /// reported exactly as before.
  ///
  /// `null` (the default) leaves the shipped [jelly] in charge and this
  /// costs nothing: no second driver, no second ticker. Supply one and it
  /// takes over the thumb's deformation entirely; [jelly] is then unused.
  final LiquidGlassSliderTouch? touch;

  const LiquidGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x3CFFFFFF),
    this.layout = const LiquidGlassSliderLayout(),
    this.style,
    this.pixelRatio = 1.0,
    this.jelly = const LiquidGlassJellyConfig(
      style: LiquidGlassJellyStyle.squashStretch,
      stiffness: 230,
      damping: 12,
      maxVelocity: 2.9,
      stretchWidth: 8.8,
      squashHeight: 8.0,
      anchorBias: -1.0,
      recoilScale: 3.0,
      recoilAnchor: 1.0,
      directionTau: 0.42,
    ),
    this.touch,
  });

  @override
  State<LiquidGlassSlider> createState() => _LiquidGlassSliderState();
}

class _LiquidGlassSliderState extends State<LiquidGlassSlider>
    with TickerProviderStateMixin {
  final LiquidGlassViewController _viewController = LiquidGlassViewController();

  /// Grow envelope: ramps 0→1 on touch-down, holds while dragging,
  /// reverses to 0 on release. Drives the JELLY path only.
  late final AnimationController _grow;

  /// Touch-path grow envelope — a spring instead of the linear [_grow]:
  /// it pops on grab, holds the glass through the post-release glide and
  /// the violent part of the wobble, and then carries the morph back to
  /// the white pill. The white pill's opacity rides the same value, so
  /// both directions read as one springy transition, never a hard swap.
  double _touchGrow = 0;
  double _touchGrowVel = 0;

  bool _dragging = false;

  /// The shared jelly simulation (lean spring + deform spring +
  /// direction memory). The slider feeds it drag values and maps its
  /// outputs onto the thumb geometry in [buildLiquidGlassSliderThumb].
  final LiquidGlassJellySpring _jelly = LiquidGlassJellySpring();

  /// The slider is locked to the iOS jelly (squash & stretch) model.
  /// Whatever [LiquidGlassJellyConfig.style] the caller supplies is
  /// normalized to [LiquidGlassJellyStyle.squashStretch]; the internal
  /// `pinchExtrude` path is kept for [LiquidGlassJelly] but is not
  /// reachable through the slider.
  LiquidGlassJellyConfig get _effectiveJelly =>
      widget.jelly.style == LiquidGlassJellyStyle.squashStretch
          ? widget.jelly
          : widget.jelly.copyWith(style: LiquidGlassJellyStyle.squashStretch);

  /// The experimental touch simulation, built only when
  /// [LiquidGlassSlider.touch] is supplied. Mutually exclusive with
  /// [_jelly]: whichever is live is the only one ticked.
  LiquidGlassSliderTouchDriver? _touch;

  /// Whether the experimental model is driving this frame.
  bool get _usesTouch => widget.touch != null;

  /// Last ticker `elapsed`, used as the spring integrator's `dt`.
  Duration? _jellyTickerLast;
  Ticker? _jellyTicker;

  /// Geometry stashed by [build] so the thumb-child gesture surface can
  /// map a global pointer position to a 0..1 value (same math as the
  /// track's own hit handling).
  double _gesturePadX = 0;
  double _gestureInnerWidth = 1;

  /// Where on the handle the finger landed, in value units — nonzero
  /// only for touch-model thumb grabs. Subtracting it makes the drag
  /// **relative**, the iOS behavior: grabbing the pill off-centre must
  /// not jump the value, and must not open a phantom finger-to-handle
  /// gap that would fire a stretch on a stationary grab.
  double _grabOffset = 0;

  /// Whether the finger is currently overrun past a track end — edge for
  /// the iOS haptic tick, fired once per entry into the overrun.
  bool _edgeFired = false;

  double _rawFromGlobal(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return widget.value;
    final local = box.globalToLocal(globalPosition);
    return (local.dx - _gesturePadX) / _gestureInnerWidth;
  }

  /// Feeds the touch model, ticking like iOS when the thumb runs into a
  /// stop. All raw-value paths funnel through here.
  void _pumpTouch(double raw) {
    _touch?.pump(raw);
    final bool overrun = raw < 0.0 || raw > 1.0;
    if (overrun && !_edgeFired) HapticFeedback.lightImpact();
    _edgeFired = overrun;
  }

  /// Maps a global pointer position to a slider value and reports it.
  void _handleGlobalDrag(Offset globalPosition) {
    // Unclamped: the overrun past an end is what stretches the pill.
    final raw = _rawFromGlobal(globalPosition) - _grabOffset;
    if (_usesTouch) _pumpTouch(raw);
    _onChanged(raw.clamp(0.0, 1.0));
  }

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _grow.addListener(() => setState(() {}));
    _syncJellyConfig();
    _jelly.start(widget.value);
    _jellyTicker = createTicker(_onJellyTick);
    // TEMP test: run the capture pipeline from startup instead of
    // starting it on the first grab, to check whether the cold capture
    // start is the first-touch stall.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewController.startRealtimeCapture();
    });
  }

  @override
  void dispose() {
    _jellyTicker?.dispose();
    _grow.dispose();
    super.dispose();
  }

  /// Pushes the widget's physics tuning into the shared simulation.
  /// Called every tick so a live change to [LiquidGlassSlider.jelly]
  /// applies immediately, matching the old inline behavior.
  void _syncJellyConfig() {
    final touch = widget.touch;
    if (touch != null) {
      (_touch ??= LiquidGlassSliderTouchDriver(spec: touch)).spec = touch;
      return;
    }
    _jelly
      ..stiffness = widget.jelly.stiffness
      ..damping = widget.jelly.damping
      ..maxVelocity = widget.jelly.maxVelocity
      ..velocityClamp = widget.jelly.velocityClamp
      ..directionTau = widget.jelly.directionTau;
  }

  void _onStart(double v) {
    _dragging = true;
    _viewController.startRealtimeCapture();
    // The touch path sizes the glass with its own spring (ticked in
    // [_onJellyTick]); the linear controller drives the jelly path only.
    if (!_usesTouch) {
      _grow
        ..stop()
        ..forward(from: _grow.value);
    }
    _syncJellyConfig();
    if (_usesTouch) {
      _edgeFired = false;
      // Where on the handle the finger landed, about the handle's own
      // centre. [_grabOffset] was stashed by the thumb recognizer before
      // this ran (zeroed for track grabs) — in value units, converted to
      // a fraction of the handle's half-width. That fraction is the sign
      // of the model: it says which side is being held, and pulling out
      // past that side is what stretches.
      final double travel = math.max(1.0, _gestureInnerWidth);
      final double halfThumb = widget.layout.thumbWidth / 2;
      final double grabPx = _grabOffset * travel;
      _touch!.start(
        widget.value,
        grab: halfThumb > 0 ? (grabPx / halfThumb).clamp(-1.0, 1.0) : 0.0,
      );
    } else {
      _jelly.start(widget.value);
    }
    _jellyTickerLast = null;
    _jellyTicker?.start();
    widget.onChangeStart?.call(v);
  }

  void _onChanged(double v) {
    widget.onChanged(v);
    // The touch model is pumped with the RAW value at the call sites that
    // have one (the thumb drag here, the track's onRawChanged) — never
    // with this clamped one, which would erase the overrun.
    if (!_usesTouch) _jelly.pump(v);
  }

  void _onEnd(double v) {
    _dragging = false;
    if (_usesTouch) {
      // The grow spring decides its own way back — it waits for the
      // handle to land and the wobble to calm before morphing to white.
      _touch?.release(); // spring momentum carries the settle
    } else {
      _grow.reverse(from: _grow.value);
      _jelly.release(); // spring momentum carries the overshoot
    }
    widget.onChangeEnd?.call(v);
  }

  void _onJellyTick(Duration elapsed) {
    final last = _jellyTickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _jellyTickerLast = elapsed;

    _syncJellyConfig();
    bool settled;
    if (_usesTouch) {
      final driverSettled = _touch!.tick(dt);
      bool growSettled = false;
      if (dt > 0) {
        // The grow spring's target: full glass while the finger is down,
        // and after release for as long as the handle is still gliding
        // to its value or the wobble is still violent — only then does
        // it carry the morph back to the white pill.
        final double travel = math.max(1.0, _gestureInnerWidth);
        final bool landed =
            (_touch!.renderValue - widget.value).abs() * travel < 2.0;
        final double target =
            _dragging || (!landed && !driverSettled) || !_touch!.isCalm
                ? 1.0
                : 0.0;
        final (g, gv) = liquidGlassSpringStep(
          x: _touchGrow,
          vel: _touchGrowVel,
          target: target,
          dt: dt,
          stiffness: 420,
          damping: 26,
        );
        _touchGrow = g;
        _touchGrowVel = gv;
        growSettled = target == 0 &&
            _touchGrow.abs() < 0.002 &&
            _touchGrowVel.abs() < 0.02;
        if (growSettled) {
          _touchGrow = 0;
          _touchGrowVel = 0;
        }
      }
      settled = driverSettled && growSettled;
    } else {
      settled = _jelly.tick(dt, dragging: _dragging);
    }
    if (settled) _jellyTicker?.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    // Jelly path only — the touch path swaps nothing: its white pill is
    // faded by the grow spring below, so glass and pill cross-morph.
    final bool glassActive = _dragging || _grow.isAnimating;

    // Padding so the grown AND jelly-deformed thumb is always fully
    // inside the inner view — so it is never clipped at the ends, and
    // its position never hits the clamp (which would pin it before the
    // end and drift on release). The jelly spring output is clamped to
    // +/-1.5 inside the thumb builder, so use that as the peak.
    const jellyPeak = 1.5;
    // Horizontal: exactly half the (grown) pill width — the pill sits
    // centered on the track end and overhangs it by half its width. This is
    // intentionally **independent of `stretchWidth`**: raising the jelly's
    // stretch must not shrink the visible track. The stretch elongation
    // then lives inside this overhang room (and, at the extreme ends with a
    // very large stretch, may briefly reach the view edge).
    final jelly = _effectiveJelly;
    final maxPillW = layout.thumbWidth + layout.thumbExtraWidth;
    final touch = widget.touch;
    // The touch model's stretch peaks exactly at the track ends — the
    // rubber-band overrun — and leans toward the finger, so its leading
    // edge reaches past the half-pill overhang and would be cut off at
    // the view edge. Budget for it: the full stretch, lean-weighted,
    // with slack for the spring's overshoot past its target, plus the
    // press swell. The jelly keeps the original padding untouched.
    final double touchOverhang = touch != null
        ? touch.stretch * (1 + touch.lean) / 2 * 1.2 +
            touch.holdScale * maxPillW / 2
        : 0.0;
    final padX = maxPillW / 2 + touchOverhang;
    // Vertical: half of the (grown + stretched) pill beyond the track.
    // The stretch style gains height during the stop-recoil
    // (squashHeight × recoilScale at peak spring overshoot) instead of
    // the pinch style's thumbStretchHeight.
    // The experimental model has its own budget: the driver caps its
    // cross growth (recoil swell + press swell included) at half the
    // thumb height, so budget exactly that. Its stretch lives in padX's
    // overhang like the jelly's does.
    final jellyHeightGain = touch != null
        ? layout.thumbHeight * 0.5
        : (jelly.style == LiquidGlassJellyStyle.squashStretch
            ? jelly.squashHeight * jelly.recoilScale * jellyPeak
            : layout.thumbStretchHeight * jellyPeak);
    final maxPillH =
        layout.thumbHeight + layout.thumbExtraHeight + jellyHeightGain;
    final padY = math.max(0.0, (maxPillH - layout.thumbHeight) / 2) + 2.0;

    // Inset the track INSIDE the requested width instead of widening the
    // widget. The widget stays exactly `layout.width` wide; the visible
    // track is narrowed by padX on each side (and stays centered), so
    // the thumb's horizontal overhang lives inside that width — no shift,
    // no extra width. Height still grows by padY to fit the taller
    // (grown) thumb vertically.
    final innerLayout = LiquidGlassSliderLayout(
      width: math.max(0.0, layout.width - padX * 2),
      trackHeight: layout.trackHeight,
      thumbWidth: layout.thumbWidth,
      thumbHeight: layout.thumbHeight,
      thumbExtraWidth: layout.thumbExtraWidth,
      thumbExtraHeight: layout.thumbExtraHeight,
      thumbSqueezeWidth: layout.thumbSqueezeWidth,
      thumbStretchHeight: layout.thumbStretchHeight,
    );
    final viewWidth = layout.width;
    final viewHeight = layout.thumbHeight + padY * 2;

    _gesturePadX = padX;
    _gestureInnerWidth = math.max(1.0, innerLayout.width);
    // The gap the model stretches across is measured in pixels, so it
    // needs the track length to convert from value units.
    _touch?.travel = innerLayout.travel;
    // Idle = the ticker is not running, so nothing else will ever move
    // the towed handle: adopt a programmatic [widget.value] change
    // directly, or the thumb (and the fill attached to it) stays frozen
    // at the last gesture's position.
    if (_usesTouch && !_dragging && !(_jellyTicker?.isActive ?? false)) {
      _touch!.syncTo(widget.value);
    }

    return SizedBox(
      width: viewWidth,
      height: viewHeight,
      child: LiquidGlassView.withPositionedLenses(
        controller: _viewController,
        // The track is captured with authored transparency; honor it on
        // Skia so the glass thumb shows the real screen through the track.
        honorBackdropAlpha: true,
        pixelRatio: widget.pixelRatio,
        realTimeCapture: true,
        useSync: true,
        backgroundWidget: Stack(
          children: [
            Positioned(
              // Span the full view width: the track's visible body is
              // re-centered inside via hitSlopX, while the gesture area
              // now reaches the very ends, so the thumb's half-overhang
              // at value 0 and 1 (which lives in padX) is tappable.
              left: 0,
              top: padY,
              child: LiquidGlassSliderTrack(
                value: widget.value,
                // iOS attaches the fill to the thumb, not the finger: the
                // fill edge rides the towed handle wherever it is drawn,
                // never poking out ahead of the pill on a fast drag.
                displayValue: _usesTouch ? _touch!.renderValue : null,
                onChanged: _onChanged,
                onRawChanged: _usesTouch ? _pumpTouch : null,
                // A track grab holds nothing — the finger is off the
                // handle, so there is no grab offset to honor.
                onChangeStart: (v) {
                  _grabOffset = 0;
                  _onStart(v);
                },
                onChangeEnd: _onEnd,
                // The white rest handle is rendered INSIDE the glass
                // lens (as its child) so it sits ON TOP of the glass
                // pill — never here in the background, which lenses
                // always cover.
                showRestThumb: false,
                activeColor: widget.activeColor,
                inactiveColor: widget.inactiveColor,
                layout: innerLayout,
                hitSlopX: padX,
              ),
            ),
          ],
        ),
        children: [
          // The glass thumb is ALWAYS mounted. At rest (growFraction 0,
          // springs at 0) it is exactly the size of the handle and sits
          // UNDER the white rest pill, which is rendered as the lens's
          // child — on top of the glass. On grab the white pill hides
          // and the glass (already rendered all along) grows and
          // jelly-deforms, so nothing new is created at first touch.
          // The child also carries the handle's gesture surface, since
          // the lens sits above the track and would otherwise block it.
          buildLiquidGlassSliderThumb(
            layout: innerLayout,
            trackLeft: padX,
            trackBottom: padY,
            // The touch model tows the handle toward the finger rather
            // than pinning it to the value, and that lag is what opens the
            // gap it stretches across. The reported value is unaffected —
            // only where the glass is drawn.
            value: _usesTouch ? _touch!.renderValue : widget.value,
            growFraction: _usesTouch ? _touchGrow : _grow.value,
            // The stretch style is driven by the speed-based
            // deform spring (sign = stretch vs recoil); the pinch
            // style keeps the direction-signed spring.
            stretchFraction: jelly.style == LiquidGlassJellyStyle.squashStretch
                ? _jelly.deform
                : _jelly.stretch,
            // Smoothed direction memory: the lean follows it
            // continuously, flipping softly across a reversal.
            motionSign: _jelly.direction,
            jelly: jelly,
            style: widget.style,
            // Experimental path: when supplied this replaces the jelly's
            // deformation outright.
            touchDeform: _usesTouch
                ? _touch?.deformFor(
                    thumbWidth: innerLayout.thumbWidth,
                    thumbHeight: innerLayout.thumbHeight,
                  )
                : null,
            // Once the user lands on the thumb we want the slider to OWN
            // the gesture: grabbing the pill and moving vertically should
            // hold/adjust the slider, never scroll an ancestor list. A
            // plain GestureDetector loses that contest — the parent
            // Scrollable wins the arena on vertical motion and the drag is
            // cancelled (leaving the glass latched). So we use an eager
            // pan recognizer that claims the arena the instant a pointer
            // lands, beating any ancestor Scrollable. A pan (not
            // horizontal-only) recognizer also keeps the grab alive under
            // vertical movement; the value still tracks horizontal x only.
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _EagerPanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _EagerPanGestureRecognizer>(
                  () => _EagerPanGestureRecognizer(debugOwner: this),
                  (instance) {
                    instance
                      // Fire onStart at touch-down (not after slop) so the
                      // glass grows the instant the thumb is grabbed.
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = (d) {
                        // iOS thumb drags are RELATIVE: record where on
                        // the handle the finger landed and subtract it
                        // from every update, so an off-centre grab
                        // neither jumps the value nor opens a phantom
                        // gap (which would stretch a stationary thumb).
                        // The jelly path keeps its shipped behavior.
                        _grabOffset = _usesTouch
                            ? _rawFromGlobal(d.globalPosition) - widget.value
                            : 0.0;
                        _onStart(widget.value);
                        _handleGlobalDrag(d.globalPosition);
                      }
                      ..onUpdate = (d) {
                        _handleGlobalDrag(d.globalPosition);
                      }
                      ..onEnd = (_) {
                        _onEnd(widget.value);
                      }
                      // Still revert cleanly if the gesture is ever
                      // cancelled for any other reason.
                      ..onCancel = () {
                        _onEnd(widget.value);
                      };
                  },
                ),
              },
              // White rest handle, drawn over the glass. Touch path: it
              // is never swapped — its opacity rides the grow spring, so
              // white and glass cross-morph in one springy motion (the
              // 1.6 factor finishes the fade early in the grow, and the
              // radius stays a capsule at every in-between size). Jelly
              // path keeps the shipped swap.
              child: _usesTouch
                  ? Opacity(
                      opacity: (1.0 - _touchGrow * 1.6).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    )
                  : glassActive
                      ? const SizedBox.expand()
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              innerLayout.thumbHeight / 2,
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

/// A [PanGestureRecognizer] that wins the gesture arena the instant a
/// pointer lands on it, instead of waiting to accumulate drag slop.
///
/// This is what lets the slider thumb beat an ancestor [Scrollable]:
/// normally both join the arena and the scrollable wins as soon as the
/// finger moves vertically, stealing the drag. By resolving
/// [GestureDisposition.accepted] in [addAllowedPointer], the thumb claims
/// the pointer immediately — so once you grab the pill, moving in any
/// direction keeps controlling the slider and the page never scrolls.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
