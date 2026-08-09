import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../src/controllers/liquid_glass_view_controller.dart';
import '../src/widgets/components/liquid_glass_morph_pill.dart';
import '../src/widgets/components/liquid_glass_shadow.dart';
import '../src/widgets/liquid_glass_style.dart';
import '../src/widgets/liquid_glass_view.dart';
import '../src/widgets/utils/liquid_glass_jelly_spring.dart'
    show liquidGlassSpringStep;
import '../src/widgets/utils/liquid_glass_shape.dart'
    show LiquidGlassCornerStyle;

/// **Experimental.** A switch in the iOS-26 sliding style, where the
/// thumb is picked up and carried rather than snapped between two ends.
/// Sibling of the shipped [LiquidGlassSlider]; nothing here touches or
/// is exported by the package.
///
/// The behaviour it carries:
///
///  * **The same two-state thumb as the slider.** A contracted solid
///    pill (37×24) morphs into an expanded glass pill (58×38.33) the
///    instant a touch lands (0.4 s, ζ 0.6 — bouncy), and back on
///    release (0.6 s, ζ 0.7). One size + cover-fade morph here, since
///    both layers scale in lockstep.
///  * **The thumb rides the finger 1:1**, relative to where it was at
///    touch-down, with a `sqrt(overrun)` rubber band past the two
///    resting positions. The track never deforms on the switch — the
///    give is all in the thumb's overshoot.
///  * **Dragging into an edge toggles early.** Carry the thumb to
///    within 5 px of the far position and the state flips right there —
///    haptic tick, track color cross-fading under your finger (0.25 s)
///    — while the thumb stays held. Dragging back can flip it again.
///  * **Tap vs drag at 150 ms.** A tap toggles immediately: haptic,
///    color, thumb spring-gliding across (0.5 s, critically damped),
///    contraction 0.2 s later. A longer hold is a drag — and a drag
///    that never reached an edge **always toggles on release**, so a
///    long-press-and-release flips the switch.
///  * **Programmatic changes stay calm.** A new [value] arriving from
///    outside while idle glides the thumb and cross-fades the track
///    without ever expanding the thumb.
///
/// The control's layout footprint is 63×28, while the glass capture
/// painted around it is larger: the expanded thumb and its bounce
/// overflow the footprint deliberately, and are not clipped to it.
class LiquidGlassSwitchExperimental extends StatefulWidget {
  /// Whether the switch is on.
  final bool value;

  /// Called at every state flip: a tap, a drag reaching an edge, or a
  /// released drag that toggled.
  final ValueChanged<bool> onChanged;

  /// Track color while on. Defaults to iOS system green.
  final Color activeTrackColor;

  /// Track color while off.
  final Color inactiveTrackColor;

  /// Color of the contracted rest thumb.
  final Color thumbColor;

  /// Glass look of the expanded thumb; null keeps the tuned default.
  final LiquidGlassStyle? style;

  /// Contact shadow around the thumb — the soft dark band that hugs its
  /// rim and pools underneath. `null` (the default) draws none.
  ///
  /// It **arrives with the glass**: its strength is tied to the morph, so
  /// the solid rest pill wears nothing and the shadow fades up as the
  /// thumb becomes a glass pill under your finger. It is also painted
  /// beneath the thumb, so the glass sits over its own shadow.
  final LiquidGlassShadow? shadow;

  /// Capture resolution for the inner view.
  final double pixelRatio;

  const LiquidGlassSwitchExperimental({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor = const Color(0xFF34C759),
    this.inactiveTrackColor = const Color(0x4C787880),
    this.thumbColor = Colors.white,
    this.style,
    this.shadow,
    this.pixelRatio = 1.0,
  });

  @override
  State<LiquidGlassSwitchExperimental> createState() =>
      _LiquidGlassSwitchExperimentalState();
}

class _LiquidGlassSwitchExperimentalState
    extends State<LiquidGlassSwitchExperimental>
    with TickerProviderStateMixin {
  // ── Layout constants ──────────────────────────────────────────────
  static const double _switchW = 63;
  static const double _switchH = 28;
  static const double _contractedW = 37;
  static const double _contractedH = 24;
  static const double _expandedW = 58;
  static const double _expandedH = 38.333;
  static const double _thumbPadding = 2;
  static const double _tapTimeThreshold = 0.15; // seconds
  static const double _edgeToggleThreshold = 5; // px

  /// The capture view around the 63×28 footprint: the expanded pill
  /// overhangs the switch on every side (and the rubber band adds
  /// more), and a glass capture must actually contain what it renders.
  static const double _padX = 28;
  static const double _viewHeight = 46;
  static const double _viewWidth = _switchW + _padX * 2;

  // ── Springs, fitted so that they
  // SETTLES within `duration` (ζ·ω ≈ ln(1/0.001)/D underdamped,
  // ω·D ≈ 9.2 critically damped) — NOT ω = 2π/D, the "response"
  // reading, which made every morph float about twice as long as the
  // control's.
  static const double _expandStiffness = 826, _expandDamping = 34.5; // .4 ζ.6
  static const double _contractStiffness = 270, _contractDamping = 23; // .6 ζ.7
  static const double _positionStiffness = 339, _positionDamping = 36.8; // .5 ζ1

  final LiquidGlassViewController _viewController = LiquidGlassViewController();

  /// The switch's own state — the source of truth between the touch
  /// that flips it and the parent echoing it back through [widget].
  bool _isOn = false;

  /// Thumb centre X in SWITCH-local coordinates (0..63), like the
  /// Set directly while dragging, spring-driven otherwise.
  double _thumbCX = 0;
  double _thumbVel = 0;
  double? _thumbSpringTarget;

  /// Morph progress: 0 = contracted white pill, 1 = expanded glass.
  double _morph = 0;
  double _morphVel = 0;
  double _morphTarget = 0;

  bool _pointerDown = false;
  bool _isDragging = false;
  bool _didToggleDuringDrag = false;
  DateTime _downTime = DateTime.now();
  double _startFingerX = 0;
  double _startThumbCX = 0;

  /// Generation guard for the tap's delayed contraction.
  int _contractGen = 0;

  Ticker? _ticker;
  Duration? _tickerLast;

  // ── Geometry ──────────────────────────────────────────────────────
  static const double _minThumbCX = _thumbPadding + _contractedW / 2;
  static const double _maxThumbCX = _switchW - _minThumbCX;

  double get _targetThumbCX => _isOn ? _maxThumbCX : _minThumbCX;

  @override
  void initState() {
    super.initState();
    _isOn = widget.value;
    _thumbCX = _targetThumbCX;
    _ticker = createTicker(_onTick);
    // Warm the capture from startup, same as the sibling slider — the
    // first touch must not pay the cold-start raster stall.
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
  void didUpdateWidget(LiquidGlassSwitchExperimental oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A parent echoing back our own onChanged arrives with
    // widget.value == _isOn and must be a no-op. A genuinely external
    // change animates like a programmatic set: glide and
    // cross-fade, but never expand the thumb.
    if (widget.value != _isOn && !_pointerDown) {
      _isOn = widget.value;
      _thumbSpringTarget = _targetThumbCX;
      _ensureTicking();
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

    // The thumb morph — expand and contract carry the two different
    // springs, chosen by which way the target points.
    final bool expanding = _morphTarget > 0.5;
    final (m, mv) = liquidGlassSpringStep(
      x: _morph,
      vel: _morphVel,
      target: _morphTarget,
      dt: dt,
      stiffness: expanding ? _expandStiffness : _contractStiffness,
      damping: expanding ? _expandDamping : _contractDamping,
    );
    _morph = m;
    _morphVel = mv;
    if ((_morph - _morphTarget).abs() < 0.001 && _morphVel.abs() < 0.01) {
      _morph = _morphTarget;
      _morphVel = 0;
    } else {
      busy = true;
    }

    // The position glide (tap travel, drag release, programmatic set).
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

    if (!busy) _ticker?.stop();
    if (mounted) setState(() {});
  }

  // ── Touch handling: down / move / up ──────────────────────────────

  /// Finger X in switch-local coordinates. The detector's box is the
  /// 63×28 footprint itself, so its local X IS switch-local.
  double _localX(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return _thumbCX;
    return box.globalToLocal(globalPosition).dx;
  }

  void _handleDown(Offset globalPosition) {
    _pointerDown = true;
    _isDragging = false;
    _didToggleDuringDrag = false;
    _downTime = DateTime.now();
    _startFingerX = _localX(globalPosition);
    // Relative drag: the thumb continues from wherever it is, even
    // mid-glide from a previous toggle.
    _startThumbCX = _thumbCX;
    _thumbSpringTarget = null;
    _thumbVel = 0;
    _contractGen++;
    _morphTarget = 1; // expand immediately, tap or drag alike
    _viewController.startRealtimeCapture();
    _ensureTicking();
    setState(() {});
  }

  void _handleMove(Offset globalPosition) {
    if (!_pointerDown) return;
    final elapsed =
        DateTime.now().difference(_downTime).inMicroseconds / 1e6;
    if (!_isDragging && elapsed >= _tapTimeThreshold) _isDragging = true;

    final newCenterX = _startThumbCX + (_localX(globalPosition) - _startFingerX);

    // The sqrt rubber band: past a resting position the thumb
    // advances by the square root of the overrun.
    double clamped = newCenterX;
    if (newCenterX < _minThumbCX) {
      clamped = _minThumbCX - math.sqrt(_minThumbCX - newCenterX);
    } else if (newCenterX > _maxThumbCX) {
      clamped = _maxThumbCX + math.sqrt(newCenterX - _maxThumbCX);
    }
    _thumbCX = clamped;

    _checkEdgeToggle(clamped);
    setState(() {});
  }

  /// Carrying the thumb to within 5 px of the far position flips the
  /// state right there — the color crosses under the held thumb, and
  /// dragging back across can flip it again. Keyed on the state
  /// itself, so each edge only fires while it is the OPPOSITE edge.
  void _checkEdgeToggle(double centerX) {
    final hitLeft = centerX <= _minThumbCX + _edgeToggleThreshold && _isOn;
    final hitRight = centerX >= _maxThumbCX - _edgeToggleThreshold && !_isOn;
    if (hitLeft || hitRight) {
      final newState = hitRight;
      if (newState != _isOn) {
        _didToggleDuringDrag = true;
        HapticFeedback.lightImpact();
        _isOn = newState;
        widget.onChanged(_isOn);
      }
    }
  }

  void _handleUp() {
    if (!_pointerDown) return;
    _pointerDown = false;
    final elapsed =
        DateTime.now().difference(_downTime).inMicroseconds / 1e6;

    if (elapsed < _tapTimeThreshold) {
      // A tap: toggle immediately, glide across, contract 0.2 s later.
      HapticFeedback.lightImpact();
      _isOn = !_isOn;
      widget.onChanged(_isOn);
      _thumbSpringTarget = _targetThumbCX;

      final gen = ++_contractGen;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || gen != _contractGen || _pointerDown) return;
        _morphTarget = 0;
        _ensureTicking();
      });
    } else {
      // A drag. One that never reached an edge ALWAYS toggles on
      // release — the rule that makes a
      // long-press-and-release flip the switch.
      _isDragging = false;
      if (!_didToggleDuringDrag) {
        HapticFeedback.lightImpact();
        _isOn = !_isOn;
        widget.onChanged(_isOn);
      }
      _morphTarget = 0;
      _thumbSpringTarget = _targetThumbCX;
    }
    _ensureTicking();
    setState(() {});
  }

  /// A cancelled interaction: an established drag finishes as a drag
  /// (toggling); a not-yet-drag just settles home.
  void _handleCancel() {
    if (!_pointerDown) return;
    final elapsed =
        DateTime.now().difference(_downTime).inMicroseconds / 1e6;
    if (elapsed >= _tapTimeThreshold) {
      _handleUp();
      return;
    }
    _pointerDown = false;
    _morphTarget = 0;
    _thumbSpringTarget = _targetThumbCX;
    _ensureTicking();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const viewCenterY = _viewHeight / 2;
    const switchTop = viewCenterY - _switchH / 2;

    // The thumb morph: one pill whose size runs contracted → expanded
    // with the spring (overshoot included), while the solid rest pill
    // fades out over the glass beneath it.
    final pillW = _contractedW + (_expandedW - _contractedW) * _morph;
    final pillH = _contractedH + (_expandedH - _contractedH) * _morph;
    final whiteOpacity = (1.0 - _morph).clamp(0.0, 1.0);
    final LiquidGlassShadow? shadow = widget.shadow;

    // Footprint is 63×28; the capture paints
    // around it through the OverflowBox, clipped by nobody — the
    // Flutter reading of unclipped.
    return SizedBox(
      width: _switchW,
      height: _switchH,
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
                ..onCancel = _handleCancel;
            },
          ),
        },
        child: OverflowBox(
          maxWidth: _viewWidth,
          maxHeight: _viewHeight,
          child: SizedBox(
            width: _viewWidth,
            height: _viewHeight,
            child: LiquidGlassView.withPositionedLenses(
              controller: _viewController,
              honorBackdropAlpha: true,
              pixelRatio: widget.pixelRatio,
              realTimeCapture: true,
              useSync: true,
              backgroundWidget: Stack(
                children: [
                  // The track: a static capsule whose colour cross-fades
                  // over 0.25 s on every toggle.
                  Positioned(
                    left: _padX,
                    top: switchTop,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: _switchW,
                      height: _switchH,
                      decoration: BoxDecoration(
                        color: _isOn
                            ? widget.activeTrackColor
                            : widget.inactiveTrackColor,
                        borderRadius: BorderRadius.circular(_switchH / 2),
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                buildLiquidGlassMorphPill(
                  spec: LiquidGlassMorphPillSpec(
                    width: pillW,
                    restHeight: pillH,
                    extraHeight: 0,
                    restRadius: pillH / 2,
                  ),
                  left: _padX + _thumbCX - pillW / 2,
                  bottom: (_viewHeight - pillH) / 2,
                  extraHeight: 0,
                  style: widget.style,
                  // Keep the refraction band proportional while the pill
                  // is below its full (expanded) size.
                  refractionWidthScale: (pillH / _expandedH).clamp(0.0, 1.0),
                  defaultCornerStyle:
                      LiquidGlassCornerStyle.continuousRoundedRectangle,
                  defaultBorderWidth: 0.6,
                  // The contracted rest pill rides on top of the glass
                  // and fades with the morph; the whole control is one
                  // gesture surface, so it takes no pointers.
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: whiteOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.thumbColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // Beneath the thumb lens, above the captured track: the
              // contact shadow, faded in with the morph so only the glass
              // pill ever casts one.
              child: shadow == null || _morph <= 0.001
                  ? null
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: _padX + _thumbCX - pillW / 2,
                          bottom: (_viewHeight - pillH) / 2,
                          width: pillW,
                          height: pillH,
                          child: IgnorePointer(
                            child: LiquidGlassShadow(
                              blur: shadow.blur,
                              opacity: shadow.opacity * _morph,
                              color: shadow.color,
                              offset: shadow.offset,
                              cornerRadius: shadow.cornerRadius ?? pillH / 2,
                              inset: shadow.inset,
                              visible: shadow.visible,
                            ),
                          ),
                        ),
                      ],
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
/// immediately.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
