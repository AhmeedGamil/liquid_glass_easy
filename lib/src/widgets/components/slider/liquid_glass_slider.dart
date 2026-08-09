import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_jelly_spring.dart' show liquidGlassSpringStep;
import '../../utils/liquid_glass_lens_motion.dart';
import '../liquid_glass_motion_pill.dart';
import '../liquid_glass_shadow.dart';
import 'liquid_glass_slider_layout.dart';

export 'liquid_glass_slider_layout.dart';

/// **Experimental.** The sliding-thumb slider PLUS an acceleration-driven
/// squash/stretch on the lifted thumb. A duplicate of
/// `liquid_glass_slider_experimental.dart` with that one effect grafted
/// on; the plainer variant stays untouched for side-by-side comparison.
///
/// ## The thumb is a shared component now
///
/// The whole thumb effect — the two-state morph, the acceleration
/// squash/stretch, and the driven-lens rendering (rest-size shape
/// stretched through the shader's `u_shapeScale`, elliptical caps,
/// band compensation) — lives in [LiquidGlassMotionPill] +
/// `LiquidGlassLensMotion`, shared with anything else that moves a
/// glass pill, such as a nav bar's selection pill. This slider is a
/// HOST: it owns the gesture, the track, the rubber band and the
/// thumb's centre, and hands the pill a `center` + `active` flag each
/// frame. The physics and rendering are documented on the component.
///
/// The behaviour it carries:
///
///  * **Two thumbs, one morph.** A contracted solid pill (37×24) rests in
///    the track; touch it and it cross-morphs into an expanded liquid
///    glass pill (58×38.33) on a bouncy spring (0.4 s, ζ 0.6). Release
///    morphs back on a softer one (0.6 s, ζ 0.7). Both run as ONE size +
///    fade morph here, since the two layers scale in lockstep.
///  * **The thumb rides the finger 1:1.** Dragging is relative to where
///    the thumb was at touch-down — no tow spring, no lag, and no
///    squash/stretch of the pill itself.
///  * **The rubber band is the TRACK's.** Run past an end and the thumb
///    overshoots by `sqrt(overrun)` while the whole track slides after
///    it, stretches by half the offset, and thins by a third of it —
///    the elasticity of the control, not of the thumb.
///  * **Tap vs drag at 150 ms.** Shorter than that is a tap: the thumb
///    spring-glides to the tapped spot (0.5 s, critically damped) and
///    contracts 0.2 s later. Longer is a drag: on release the track
///    relaxes (0.3 s, ζ 0.8), the thumb contracts and glides to its
///    final value.
///  * **Edge haptics.** A light impact entering the minimum end, a
///    medium one entering the maximum, re-armed after leaving; a tap
///    landing exactly on an end fires the same.
///  * **Fill that snaps at the ends.** The fill edge follows the thumb's
///    centre, but within 10 px of either end it eases to exactly empty /
///    exactly full, and it follows the rubber-banded track frame.
class LiquidGlassSlider extends StatefulWidget {
  /// Current value, in [minimumValue]..[maximumValue].
  final double value;

  /// Called with the new value — continuously while dragging when
  /// [isContinuous], otherwise once per gesture.
  final ValueChanged<double> onChanged;

  /// Called when a touch lands on the control.
  final ValueChanged<double>? onChangeStart;

  /// Called when the gesture ends.
  final ValueChanged<double>? onChangeEnd;

  /// Value range, mirroring `minimumValue` / `maximumValue`.
  final double minimumValue;
  final double maximumValue;

  /// Whether value changes are reported continuously while dragging
  /// (`true`, the default) or once at gesture end.
  final bool isContinuous;

  /// Color of the filled (minimum-side) track portion. Defaults to the
  /// iOS system blue.
  final Color activeColor;

  /// Color of the unfilled track.
  final Color inactiveColor;

  /// Color of the contracted rest thumb.
  final Color thumbColor;

  /// The control's geometry: track, both thumb sizes, and the end icons.
  final LiquidGlassSliderLayout layout;

  /// How hard the lifted thumb squashes and stretches as it is carried.
  /// `LiquidGlassLensMotionSpec(maxDeviation: 0)` turns the deformation
  /// off entirely and leaves the plain morphing thumb.
  final LiquidGlassLensMotionSpec motion;

  /// Optional icons at the two ends. The track shortens to make room.
  final Widget? minimumIcon;
  final Widget? maximumIcon;

  /// Glass look of the expanded thumb; null keeps the tuned default.
  final LiquidGlassStyle? style;

  /// Contact shadow around the lifted thumb — the soft dark band that
  /// hugs its rim and pools underneath, so the glass reads as sitting in
  /// the track rather than floating over it.
  ///
  /// `null` (the default) draws none. Pass `const LiquidGlassShadow()`
  /// for the standard one, or a configured instance to tune its blur,
  /// opacity, colour or offset.
  ///
  /// It wraps the thumb's lens rather than living inside it, so the arc
  /// that pools *below* the thumb survives instead of being clipped at
  /// the outline, and it tracks the thumb's stretch as it deforms.
  final LiquidGlassShadow? shadow;

  /// Capture resolution for the inner view.
  final double pixelRatio;

  const LiquidGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.minimumValue = 0,
    this.maximumValue = 1,
    this.isContinuous = true,
    this.activeColor = const Color(0xFF0A84FF),
    this.inactiveColor = const Color(0x3CFFFFFF),
    this.thumbColor = Colors.white,
    this.layout = const LiquidGlassSliderLayout(),
    this.motion = const LiquidGlassLensMotionSpec(),
    this.minimumIcon,
    this.maximumIcon,
    this.style,
    this.shadow,
    this.pixelRatio = 1.0,
  });

  @override
  State<LiquidGlassSlider> createState() =>
      _LiquidGlassSliderState();
}

class _LiquidGlassSliderState
    extends State<LiquidGlassSlider>
    with TickerProviderStateMixin {
  // ── Constants that are not geometry ────────────────────────────────
  static const double _tapTimeThreshold = 0.15; // seconds
  static const double _fillEndRamp = 10; // px, the fill's end snap zone
  static const double _hapticEdge = 2; // px

  LiquidGlassSliderLayout get _layout => widget.layout;
  double get _trackHeight => _layout.trackHeight;
  double get _contractedW => _layout.thumbWidth;
  double get _contractedH => _layout.thumbHeight;
  double get _expandedW => _layout.liftedThumbWidth;
  double get _expandedH => _layout.liftedThumbHeight;
  double get _iconSize => _layout.iconSize;
  double get _iconPadding => _layout.iconGap;

  /// Room at each end for the lifted thumb's overhang, the rubber-band
  /// overshoot and the squash — all of which must fit the glass capture.
  double get _padX => _layout.resolveHorizontalInset(widget.motion.maxDeviation);

  /// The control's height, sized for the lifted thumb at full squash.
  double get _viewHeight => _layout.resolveHeight(widget.motion.maxDeviation);

  // ── Springs, mapped as ω₀ = 2π / duration ─────────────────────────
  // (The morph and lens-motion constants moved into
  // LiquidGlassMotionPill's defaults.)
  static const double _positionStiffness = 158, _positionDamping = 25.1;
  static const double _rubberStiffness = 439, _rubberDamping = 33.5; // .3 ζ.8

  final LiquidGlassViewController _viewController = LiquidGlassViewController();

  /// The thumb's centre X in widget-local coordinates — set directly
  /// while dragging, spring-driven on taps and releases.
  double _thumbCX = 0;
  double _thumbVel = 0;
  double? _thumbSpringTarget;

  /// Whether the thumb is lifted — drives [LiquidGlassMotionPill.active],
  /// which owns the morph spring and the motion tracking internally.
  bool _thumbActive = false;

  /// Signed rubber-band offset (negative = past the minimum end). Set
  /// directly while dragging; springs back to 0 after release.
  double _rubber = 0;
  double _rubberVel = 0;
  bool _rubberSettling = false;

  bool _pointerDown = false;
  bool _isDragging = false;
  DateTime _downTime = DateTime.now();
  double _startFingerX = 0;
  double _startThumbCX = 0;
  double _lastFingerX = 0;

  /// The value THIS gesture last computed — the control's own record,
  /// updated synchronously as the finger moves. Release targets are
  /// derived from it, never from
  /// [widget.value]: the parent's echo is a frame behind, and a flick
  /// released at the max end would otherwise glide to the stale value
  /// and stop short of the track's end.
  double _gestureValue = 0;
  bool _didMinHaptic = false;
  bool _didMaxHaptic = false;

  /// Generation guard for the tap's delayed contraction, standing in
  /// for the delayed contraction plus its re-check that no new touch
  /// has claimed the thumb.
  int _contractGen = 0;

  Ticker? _ticker;
  Duration? _tickerLast;

  // ── Geometry ──────────────────────────────────────────────────────
  double get _trackMinX =>
      _padX + (widget.minimumIcon != null ? _iconSize + _iconPadding : 0);
  double get _trackMaxX =>
      _layout.width -
      _padX -
      (widget.maximumIcon != null ? _iconSize + _iconPadding : 0);
  double get _trackWidth => math.max(1.0, _trackMaxX - _trackMinX);
  double get _minThumbCX => _trackMinX + _contractedW / 2;
  double get _maxThumbCX => _trackMaxX - _contractedW / 2;
  double get _thumbRange => math.max(1.0, _maxThumbCX - _minThumbCX);

  double get _normalizedValue {
    final span = widget.maximumValue - widget.minimumValue;
    if (span <= 0) return 0;
    return ((widget.value - widget.minimumValue) / span).clamp(0.0, 1.0);
  }

  double get _targetThumbCX => _minThumbCX + _thumbRange * _normalizedValue;

  double _valueAt(double centerX) {
    final t = ((centerX - _minThumbCX) / _thumbRange).clamp(0.0, 1.0);
    return widget.minimumValue +
        t * (widget.maximumValue - widget.minimumValue);
  }

  double _centerForValue(double value) {
    final span = widget.maximumValue - widget.minimumValue;
    if (span <= 0) return _minThumbCX;
    final t = ((value - widget.minimumValue) / span).clamp(0.0, 1.0);
    return _minThumbCX + _thumbRange * t;
  }

  @override
  void initState() {
    super.initState();
    _thumbCX = _targetThumbCX;
    _ticker = createTicker(_onTick);
    // Warm the capture from startup, same as the shipped slider — the
    // first grab must not pay the cold-start raster stall.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewController.startRealtimeCapture();
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LiquidGlassSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pointerDown) return;
    if (_thumbSpringTarget != null) {
      // A glide is in flight. If the value (or geometry) changed under
      // it — typically the parent's echo of the gesture's final value
      // landing a frame after the release — retarget the running
      // spring instead of letting it finish at a stale position.
      if (oldWidget.value != widget.value || oldWidget.layout.width != _layout.width) {
        _thumbSpringTarget = _targetThumbCX;
        _ensureTicking();
      }
    } else {
      // Idle: a programmatic value (or geometry) change places the
      // thumb directly — a programmatic value set is un-animated.
      _thumbCX = _targetThumbCX;
    }
  }

  void _ensureTicking() {
    final ticker = _ticker;
    if (ticker != null && !ticker.isActive) {
      _tickerLast = null;
      ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;
    if (dt <= 0) return;

    bool busy = _pointerDown;

    // (The thumb morph and the lens acceleration sampling moved into
    // LiquidGlassMotionPill — it runs its own ticker. This one only
    // drives the slider's own springs: position glide and rubber.)

    // The position glide (tap-to-place and post-release travel).
    final springTarget = _thumbSpringTarget;
    if (springTarget != null) {
      final (x, v) = liquidGlassSpringStep(
        x: _thumbCX,
        vel: _thumbVel,
        target: springTarget,
        dt: dt,
        stiffness: _positionStiffness,
        damping: _positionDamping,
      );
      _thumbCX = x;
      _thumbVel = v;
      if ((x - springTarget).abs() < 0.1 && v.abs() < 1) {
        _thumbCX = springTarget;
        _thumbVel = 0;
        _thumbSpringTarget = null;
      } else {
        busy = true;
      }
    }

    // The track relaxing out of its rubber band after a release.
    if (_rubberSettling) {
      final (r, rv) = liquidGlassSpringStep(
        x: _rubber,
        vel: _rubberVel,
        target: 0,
        dt: dt,
        stiffness: _rubberStiffness,
        damping: _rubberDamping,
      );
      _rubber = r;
      _rubberVel = rv;
      if (_rubber.abs() < 0.05 && rv.abs() < 0.5) {
        _rubber = 0;
        _rubberVel = 0;
        _rubberSettling = false;
      } else {
        busy = true;
      }
    }

    if (!busy) _ticker?.stop();
    if (mounted) setState(() {});
  }

  // ── Touch handling: down / move / up ─────────────────────────────

  double _localX(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return _thumbCX;
    return box.globalToLocal(globalPosition).dx;
  }

  void _handleDown(Offset globalPosition) {
    _pointerDown = true;
    _isDragging = false;
    _didMinHaptic = false;
    _didMaxHaptic = false;
    _rubber = 0;
    _rubberVel = 0;
    _rubberSettling = false;
    _downTime = DateTime.now();
    _startFingerX = _localX(globalPosition);
    _lastFingerX = _startFingerX;
    // Relative drag: the thumb continues from wherever it is, even if a
    // previous glide is still in flight.
    _startThumbCX = _thumbCX;
    _thumbSpringTarget = null;
    _thumbVel = 0;
    _gestureValue = widget.value;
    _contractGen++;
    // Expand immediately, tap or drag alike; the pill starts its own
    // motion tracking on activation.
    _thumbActive = true;
    _viewController.startRealtimeCapture();
    _ensureTicking();
    widget.onChangeStart?.call(widget.value);
    setState(() {});
  }

  void _handleMove(Offset globalPosition) {
    if (!_pointerDown) return;
    final elapsed =
        DateTime.now().difference(_downTime).inMicroseconds / 1e6;
    if (!_isDragging && elapsed >= _tapTimeThreshold) _isDragging = true;

    final currentX = _localX(globalPosition);
    _lastFingerX = currentX;
    final newCenterX = _startThumbCX + (currentX - _startFingerX);

    // The sqrt rubber band: past a bound the thumb advances
    // by the square root of the overrun.
    double clamped = newCenterX;
    if (newCenterX < _minThumbCX) {
      clamped = _minThumbCX - math.sqrt(_minThumbCX - newCenterX);
      _rubber = clamped - _minThumbCX;
    } else if (newCenterX > _maxThumbCX) {
      clamped = _maxThumbCX + math.sqrt(newCenterX - _maxThumbCX);
      _rubber = clamped - _maxThumbCX;
    } else {
      _rubber = 0;
    }
    _thumbCX = clamped;

    final newValue = _valueAt(newCenterX);
    final prevValue = _gestureValue;
    _gestureValue = newValue;
    if (widget.isContinuous && newValue != prevValue) {
      widget.onChanged(newValue);
    }

    // Edge haptics read the UNCLAMPED position, not the rubber-banded one.
    _checkEdgeHaptics(newCenterX);
    setState(() {});
  }

  void _handleUp() {
    if (!_pointerDown) return;
    _pointerDown = false;
    final elapsed =
        DateTime.now().difference(_downTime).inMicroseconds / 1e6;

    if (elapsed < _tapTimeThreshold) {
      // A tap: glide the thumb to the tapped spot and report the value.
      final clampedX =
          _lastFingerX.clamp(_minThumbCX, _maxThumbCX).toDouble();
      final newValue = _valueAt(clampedX);
      _gestureValue = newValue;
      widget.onChanged(newValue);
      _thumbSpringTarget = clampedX;
      _rubberSettling = _rubber != 0;

      // The tap's own end haptics: light landing on the minimum,
      // medium landing on the maximum.
      if ((newValue - widget.minimumValue).abs() < 0.01) {
        HapticFeedback.lightImpact();
      } else if ((newValue - widget.maximumValue).abs() < 0.01) {
        HapticFeedback.mediumImpact();
      }

      // Contract 0.2 s later, unless a new touch claimed the thumb.
      // Deactivating the pill is its own instant tracking reset.
      final gen = ++_contractGen;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || gen != _contractGen || _pointerDown) return;
        setState(() => _thumbActive = false);
      });
    } else {
      // A drag: the track relaxes, the thumb contracts and glides home.
      // The glide target comes from the gesture's OWN value — the
      // parent's echo may still be a frame behind at the max end.
      _isDragging = false;
      _rubberSettling = _rubber != 0;
      _thumbActive = false; // contract; the pill resets its own tracking
      if (!widget.isContinuous) widget.onChanged(_gestureValue);
      _thumbSpringTarget = _centerForValue(_gestureValue);
    }
    _ensureTicking();
    widget.onChangeEnd?.call(_gestureValue);
    setState(() {});
  }

  void _checkEdgeHaptics(double centerX) {
    if (centerX <= _minThumbCX + _hapticEdge && !_didMinHaptic) {
      _didMinHaptic = true;
      _didMaxHaptic = false;
      HapticFeedback.lightImpact();
    } else if (centerX >= _maxThumbCX - _hapticEdge && !_didMaxHaptic) {
      _didMaxHaptic = true;
      _didMinHaptic = false;
      HapticFeedback.mediumImpact();
    } else if (centerX > _minThumbCX + _hapticEdge * 2 &&
        centerX < _maxThumbCX - _hapticEdge * 2) {
      _didMinHaptic = false;
      _didMaxHaptic = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final centerY = _viewHeight / 2;

    // Track frame under the rubber band: it slides after the thumb, gains half the offset in
    // width, and loses a third of it in height.
    final trackShift = _rubber * 0.75 - _rubber.abs() * 0.25;
    final effTrackHeight = math.max(2.0, _trackHeight - _rubber.abs() / 3);
    final trackX = _trackMinX + trackShift;
    final trackW = _trackWidth + _rubber.abs() / 2;
    final trackY = centerY - effTrackHeight / 2;
    final trackRadius = effTrackHeight / 2;

    // The fill: ends exactly under the thumb's centre, easing to
    // exactly empty / exactly full inside the 10 px end zones.
    final kMin =
        ((_thumbCX - _minThumbCX) / _fillEndRamp).clamp(0.0, 1.0);
    final kMax =
        ((_maxThumbCX - _thumbCX) / _fillEndRamp).clamp(0.0, 1.0);
    final fillW = math.max(0.0, _thumbCX - trackX) * kMin * kMax +
        trackW * (1 - kMax);

    return SizedBox(
      width: _layout.width,
      height: _viewHeight,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          _EagerPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
            () => _EagerPanGestureRecognizer(debugOwner: this),
            (instance) {
              instance
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = (d) {
                  _handleDown(d.globalPosition);
                }
                ..onUpdate = (d) {
                  _handleMove(d.globalPosition);
                }
                ..onEnd = (_) {
                  _handleUp();
                }
                ..onCancel = _handleUp;
            },
          ),
        },
        child: LiquidGlassView.withPositionedLenses(
          controller: _viewController,
          honorBackdropAlpha: true,
          pixelRatio: widget.pixelRatio,
          realTimeCapture: true,
          useSync: true,
          backgroundWidget: Stack(
            children: [
              // Unfilled track.
              Positioned(
                left: trackX,
                top: trackY,
                child: Container(
                  width: trackW,
                  height: effTrackHeight,
                  decoration: BoxDecoration(
                    color: widget.inactiveColor,
                    borderRadius: BorderRadius.circular(trackRadius),
                  ),
                ),
              ),
              // Filled portion, sharing the track's deformed frame.
              Positioned(
                left: trackX,
                top: trackY,
                child: Container(
                  width: fillW,
                  height: effTrackHeight,
                  decoration: BoxDecoration(
                    color: widget.activeColor,
                    borderRadius: BorderRadius.circular(trackRadius),
                  ),
                ),
              ),
              if (widget.minimumIcon != null)
                Positioned(
                  left: _padX,
                  top: centerY - _iconSize / 2,
                  child: SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: widget.minimumIcon,
                  ),
                ),
              if (widget.maximumIcon != null)
                Positioned(
                  left: _layout.width - _padX - _iconSize,
                  top: centerY - _iconSize / 2,
                  child: SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: widget.maximumIcon,
                  ),
                ),
            ],
          ),
          children: const [],
          // The thumb is the shared LiquidGlassMotionPill in the view's
          // child: this slider hands it a centre and an active flag;
          // the morph, the acceleration squash/stretch and the
          // driven-lens rendering (rest-size shape stretched through
          // the shader, elliptical caps, band compensation) are the
          // component's. The white rest pill rides as its fading
          // cover; nothing in it takes pointers — the whole control is
          // one gesture surface.
          child: LiquidGlassMotionPill(
            center: Offset(_thumbCX, centerY),
            active: _thumbActive,
            restSize: Size(_contractedW, _contractedH),
            activeSize: Size(_expandedW, _expandedH),
            style: widget.style,
            shadow: widget.shadow,
            motion: widget.motion,
            cover: Container(
              decoration: BoxDecoration(
                color: widget.thumbColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// Copied from the shipped slider, where it is private: a pan recognizer
/// that claims the arena the instant a pointer lands, so the control is
/// never robbed by an ancestor scrollable and `onStart` fires at
/// touch-down, so the thumb expands the instant it is touched
/// rather than after the drag is recognised.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
