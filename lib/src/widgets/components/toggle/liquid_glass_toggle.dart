import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass.dart'
    show LiquidGlassAppearance, LiquidGlassRefraction;
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_blur.dart' show LiquidGlassBlur;
import '../../utils/liquid_glass_eager_pan.dart';
import '../../utils/liquid_glass_jelly_spring.dart' show liquidGlassSpringStep;
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_morph_pill.dart';
import '../liquid_glass_shadow.dart';
import 'liquid_glass_toggle_layout.dart';
import 'liquid_glass_toggle_track.dart';

export 'liquid_glass_toggle_layout.dart';
export 'liquid_glass_toggle_track.dart';

/// A drop-in liquid-glass switch, in the sliding style where the thumb
/// is picked up and carried rather than snapped between two ends.
///
/// You give it a [value] and an [onChanged] like a regular `Switch`; it
/// owns its own [LiquidGlassView], the colored track, the glass thumb
/// and the whole touch simulation.
///
/// The behaviour it carries:
///
///  * **A two-state thumb.** A contracted solid pill (37×24) morphs into
///    an expanded glass pill (58×38.33) the instant a touch lands
///    (0.4 s, ζ 0.6 — bouncy), and back on release (0.6 s, ζ 0.7). One
///    size + cover-fade morph, since both layers scale in lockstep.
///  * **The thumb rides the finger 1:1**, relative to where it was at
///    touch-down, with a `sqrt(overrun)` rubber band past the two
///    resting positions, saturating at
///    [LiquidGlassToggleLayout.overshootRoom] — the room the capture view
///    actually reserves, which an unbounded `sqrt` would spend under a
///    mouse. The track never deforms — the give is all in the thumb's
///    overshoot.
///  * **Dragging into an edge toggles early.** Carry the thumb to
///    within 5 px of the far position and the state flips right there —
///    haptic tick, track color cross-fading under your finger (0.25 s)
///    — while the thumb stays held. Dragging back can flip it again.
///  * **Tap vs drag by distance, then time.** A gesture that carried the
///    thumb past `kTouchSlop` is a drag however brief it was — a mouse
///    crosses the whole control inside any tap window. Anything else under
///    150 ms is a tap: haptic, color, thumb spring-gliding across (0.5 s,
///    critically damped), contraction 0.2 s later. A drag that never
///    reached an edge **always toggles on release**, so a
///    long-press-and-release flips the switch.
///  * **Programmatic changes stay calm.** A new [value] arriving from
///    outside while idle glides the thumb and cross-fades the track
///    without ever expanding the thumb.
///
/// ```dart
/// LiquidGlassToggle(
///   value: _on,
///   onChanged: (v) => setState(() => _on = v),
///   activeColor: const Color(0xFF34C759),
/// )
/// ```
///
/// ## Refraction & the overhang
/// The expanded thumb grows larger than the track, so its overhang
/// samples the (transparent) area around the capsule. The shader honors
/// the captured texel's alpha, so that overhang renders as transparent
/// passthrough instead of a black blob. On the Impeller backdrop path
/// the overhang refracts the live backdrop directly.
///
/// ## Sizing
/// Every measurement lives on [layout] — a [LiquidGlassToggleLayout]
/// giving the track's width and height, the thumb's resting size and the
/// size it swells to. The resting positions, the travel, the rubber
/// band's limits and the capture view are all derived from those, so
/// resizing the track is a one-line change:
///
/// ```dart
/// LiquidGlassToggle(
///   value: _on,
///   onChanged: (v) => setState(() => _on = v),
///   layout: const LiquidGlassToggleLayout(width: 84, height: 38),
/// )
/// ```
///
/// The control's layout footprint is the track alone (63×28 by default)
/// while the glass painted around it is larger: the expanded thumb and
/// its bounce overflow the footprint deliberately and are not clipped to
/// it. See [reserveSwellRoom] if an ancestor clips.
class LiquidGlassToggle extends StatefulWidget {
  /// Whether the switch is on.
  final bool value;

  /// Called at every state flip: a tap, a drag reaching an edge, or a
  /// released drag that toggled.
  final ValueChanged<bool> onChanged;

  /// Track color while on. Defaults to iOS system green.
  final Color activeColor;

  /// Track color while off.
  final Color inactiveColor;

  /// Color of the contracted rest thumb.
  final Color thumbColor;

  /// Size of the track and of the thumb that rides it. Defaults to the
  /// iOS-26 63×28 capsule; everything else — the resting positions, the
  /// travel, the rubber band, the capture view — is derived from it.
  final LiquidGlassToggleLayout layout;

  /// Glass look of the expanded thumb; null keeps the tuned default —
  /// a clear pill, refraction and rim only, with no tint washing over
  /// what it magnifies.
  final LiquidGlassStyle? style;

  /// Contact shadow around the thumb — the soft dark band that hugs its
  /// rim and pools underneath. `null` (the default) draws none.
  ///
  /// It **arrives with the glass**: its strength is tied to the morph, so
  /// the solid rest pill wears nothing and the shadow fades up as the
  /// thumb becomes a glass pill under your finger. It is also painted
  /// beneath the thumb, so the glass sits over its own shadow.
  final LiquidGlassShadow? shadow;

  /// Whether to claim layout space for the thumb's swell.
  ///
  /// By default the switch measures just its track and the expanded
  /// thumb paints **outside** it. The trade-off is that a clipping
  /// ancestor (a `ClipRRect`, a `Card`, a scroll view with
  /// `clipBehavior` on) cuts the swell off at the track's edge. Set this
  /// to `true` in that case: the switch then measures
  /// [LiquidGlassToggleLayout.viewWidth] × `viewHeight`, large enough to
  /// contain the swell and the rubber band's overrun.
  final bool reserveSwellRoom;

  /// Capture resolution for the inner view. `1.0` is a good default; use
  /// less for cheaper captures, `0.0` for the device pixel ratio.
  final double pixelRatio;

  const LiquidGlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFF34C759),
    this.inactiveColor = const Color(0x4C787880),
    this.thumbColor = Colors.white,
    this.layout = const LiquidGlassToggleLayout(),
    this.style,
    this.shadow,
    this.reserveSwellRoom = false,
    this.pixelRatio = 1.0,
  });

  @override
  State<LiquidGlassToggle> createState() => _LiquidGlassToggleState();
}

class _LiquidGlassToggleState extends State<LiquidGlassToggle>
    with TickerProviderStateMixin {
  static const double _tapTimeThreshold = 0.15; // seconds
  static const double _edgeToggleThreshold = 5; // px

  // ── Springs, fitted so that they
  // SETTLES within `duration` (ζ·ω ≈ ln(1/0.001)/D underdamped,
  // ω·D ≈ 9.2 critically damped) — NOT ω = 2π/D, the "response"
  // reading, which made every morph float about twice as long as the
  // control's.
  static const double _expandStiffness = 826, _expandDamping = 34.5; // .4 ζ.6
  static const double _contractStiffness = 270, _contractDamping = 23; // .6 ζ.7
  static const double _positionStiffness = 339, _positionDamping = 36.8; // .5 ζ1

  /// A clear pill: rim and refraction, no tint. The glass shows what is
  /// behind it rather than washing over it, so the solid body — not a
  /// milky fill — is what reads as the thumb.
  static const LiquidGlassStyle _clearStyle = LiquidGlassStyle(
    appearance: LiquidGlassAppearance(
      color: Color(0x00FFFFFF),
      blur: LiquidGlassBlur(sigmaX: 0.5, sigmaY: 0.5),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.12,
      distortionWidth: 14,
      chromaticAberration: 0.002,
    ),
  );

  /// The one shape every **non-glass** surface wears: the track capsule, the
  /// shrunken copy of it behind the lens, and the solid rest pill. They are
  /// painted in three different places at three different radii, so what is
  /// shared is the corner family — the single thing that has to agree for
  /// the control to read as one object.
  ///
  /// The glass pill carries the other shape, resolved from its own style.
  static const LiquidGlassCornerStyle _surfaceCorner =
      LiquidGlassCornerStyle.roundedRectangle;

  final LiquidGlassViewController _viewController = LiquidGlassViewController();

  /// The track's own box, which finger positions are read against. Held
  /// by key because [reserveSwellRoom] puts a larger box at the root.
  final GlobalKey _trackKey = GlobalKey();

  /// The switch's own state — the source of truth between the touch
  /// that flips it and the parent echoing it back through [widget].
  bool _isOn = false;

  /// Thumb centre X in TRACK-local coordinates (0..`layout.width`).
  /// Set directly while dragging, spring-driven otherwise.
  double _thumbCX = 0;
  double _thumbVel = 0;
  double? _thumbSpringTarget;

  /// Morph progress: 0 = contracted white pill, 1 = expanded glass.
  double _morph = 0;
  double _morphVel = 0;
  double _morphTarget = 0;

  /// Whether any glass is showing — the morph off rest. The capture runs
  /// across exactly this window; at 0 the opaque rest pill covers the
  /// lens completely and there is nothing to refract.
  bool _glassVisible = false;

  bool _pointerDown = false;
  bool _isDragging = false;
  bool _didToggleDuringDrag = false;

  /// Whether the pointer has travelled far enough to be a drag rather than a
  /// held tap, by DISTANCE.
  ///
  /// Time alone cannot decide this. A mouse crosses the whole control inside
  /// the tap window, so a 600 px flick was being classified as a tap and
  /// toggled a second time — undoing the flip its own edge had just made.
  /// [kTouchSlop] is wide enough that finger jitter during a real tap never
  /// trips it.
  bool _didMoveFar = false;
  DateTime _downTime = DateTime.now();
  double _startFingerX = 0;
  double _startThumbCX = 0;

  /// Generation guard for the tap's delayed contraction.
  int _contractGen = 0;

  Ticker? _ticker;
  Duration? _tickerLast;

  // ── Geometry, all read off the layout ─────────────────────────────
  LiquidGlassToggleLayout get _l => widget.layout;
  double get _minThumbCX => _l.minThumbCenterX;
  double get _maxThumbCX => _l.maxThumbCenterX;

  double get _targetThumbCX => _isOn ? _maxThumbCX : _minThumbCX;

  @override
  void initState() {
    super.initState();
    _isOn = widget.value;
    _thumbCX = _targetThumbCX;
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LiquidGlassToggle oldWidget) {
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
    // A resized track moves both resting positions, so a thumb sitting
    // at rest would be stranded at the old one. Idle, it is placed at
    // the new position outright; mid-gesture the finger still owns it
    // and only the spring's destination is refreshed.
    final resized = oldWidget.layout.minThumbCenterX != _minThumbCX ||
        oldWidget.layout.maxThumbCenterX != _maxThumbCX;
    if (resized && !_pointerDown) {
      if (_thumbSpringTarget == null) {
        _thumbCX = _targetThumbCX;
      } else {
        _thumbSpringTarget = _targetThumbCX;
        _ensureTicking();
      }
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

    // The capture follows the glass, not the finger. The morph is the
    // only thing that moves it off — and back to — rest, so both edges
    // of the window are read from right here.
    _syncCapture(_morph != 0);

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

  /// Runs the background capture only while glass is on screen. Called
  /// from the ticker (never paint), so answering with `setState` inside
  /// the view is safe.
  void _syncCapture(bool glassVisible) {
    if (glassVisible == _glassVisible) return;
    _glassVisible = glassVisible;
    if (glassVisible) {
      _viewController.startRealtimeCapture();
      // The view's per-frame listener may already have run by the time
      // this fires, which would push its first capture a frame past the
      // glass. The one-shot lands it at the end of THIS frame either way.
      _viewController.captureOnce();
    } else {
      _viewController.stopRealtimeCapture();
    }
  }

  // ── Touch handling: down / move / up ──────────────────────────────

  /// Finger X in track-local coordinates. Read against the track's own
  /// box, so the reading is switch-local whether or not the control
  /// reserved room for the swell.
  double _localX(Offset globalPosition) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return _thumbCX;
    return box.globalToLocal(globalPosition).dx;
  }

  void _handleDown(Offset globalPosition) {
    _pointerDown = true;
    _isDragging = false;
    _didToggleDuringDrag = false;
    _didMoveFar = false;
    _downTime = DateTime.now();
    _startFingerX = _localX(globalPosition);
    // Relative drag: the thumb continues from wherever it is, even
    // mid-glide from a previous toggle.
    _startThumbCX = _thumbCX;
    _thumbSpringTarget = null;
    _thumbVel = 0;
    _contractGen++;
    _morphTarget = 1; // expand immediately, tap or drag alike
    // No capture is started here: the pill is still the solid rest pill
    // with no glass showing. The morph turns it on as it lifts.
    _ensureTicking();
    setState(() {});
  }

  void _handleMove(Offset globalPosition) {
    if (!_pointerDown) return;
    final elapsed = DateTime.now().difference(_downTime).inMicroseconds / 1e6;
    if (!_isDragging && elapsed >= _tapTimeThreshold) _isDragging = true;

    final double fingerTravel = _localX(globalPosition) - _startFingerX;
    if (fingerTravel.abs() > kTouchSlop) _didMoveFar = true;
    final newCenterX = _startThumbCX + fingerTravel;

    // The sqrt rubber band: past a resting position the thumb advances by the
    // square root of the overrun — capped at the room the layout actually
    // reserves for it. sqrt is unbounded, and a mouse can drag far enough to
    // spend it: 400 px past the end already reaches the full allowance, and
    // beyond that the thumb was painting outside the capture view and
    // clipping. Below the cap the band is bit-for-bit what it always was.
    final double room = _l.overshootRoom;
    double clamped = newCenterX;
    if (newCenterX < _minThumbCX) {
      clamped =
          _minThumbCX - math.min(math.sqrt(_minThumbCX - newCenterX), room);
    } else if (newCenterX > _maxThumbCX) {
      clamped =
          _maxThumbCX + math.min(math.sqrt(newCenterX - _maxThumbCX), room);
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
    final elapsed = DateTime.now().difference(_downTime).inMicroseconds / 1e6;

    // Distance decides first, time second. A gesture that carried the thumb
    // is a drag however briefly it lasted — the tap window is no guide at
    // mouse speeds.
    if (!_didMoveFar && elapsed < _tapTimeThreshold) {
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
    final elapsed = DateTime.now().difference(_downTime).inMicroseconds / 1e6;
    if (_didMoveFar || elapsed >= _tapTimeThreshold) {
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
    final l = _l;
    final padX = l.padX;
    final viewWidth = l.viewWidth;
    final viewHeight = l.viewHeight;
    final trackTop = viewHeight / 2 - l.height / 2;

    // The thumb morph: one pill whose size runs contracted → expanded
    // with the spring (overshoot included), while the solid rest pill
    // fades out over the glass beneath it.
    final pillW = l.thumbWidth + (l.expandedThumbWidth - l.thumbWidth) * _morph;
    final pillH =
        l.thumbHeight + (l.expandedThumbHeight - l.thumbHeight) * _morph;
    final restOpacity = (1.0 - _morph).clamp(0.0, 1.0);
    final LiquidGlassShadow? shadow = widget.shadow;

    // The pill's outline, resolved the same way `buildLiquidGlassMorphPill`
    // resolves it below. Three things have to agree on it: the glass, the
    // solid rest pill riding on top of the glass, and the hole the track
    // cuts underneath — so it is derived once, here.
    final LiquidGlassShape? styleShape = (widget.style ?? _clearStyle).shape;
    final LiquidGlassCornerStyle pillCorner =
        styleShape?.cornerStyle ?? LiquidGlassCornerStyle.roundedRectangle;
    final double pillRadius = styleShape?.cornerRadius ?? pillH / 2;

    // The track cuts its hole from a travel fraction, so hand it the one
    // that inverts to the thumb's actual centre. Outside 0..1 while the
    // rubber band is stretched, which is exactly right — the hole has to
    // follow the thumb out there too.
    final travelFraction =
        l.travel > 0 ? (_thumbCX - _minThumbCX) / l.travel : 0.0;

    final Widget view = SizedBox(
      width: viewWidth,
      height: viewHeight,
      child: LiquidGlassView.withPositionedLenses(
        controller: _viewController,
        honorBackdropAlpha: true,
        pixelRatio: widget.pixelRatio,
        // The capture lives exactly as long as the glass does: off at
        // rest, started the frame the pill lifts off it, stopped once the
        // pill is solid again. The view still snapshots once on mount.
        realTimeCapture: false,
        useSync: true,
        backgroundWidget: Stack(
          children: [
            // The track: a static capsule whose colour cross-fades over
            // 0.25 s on every toggle, carrying the pinch under the glass.
            Positioned(
              left: padX,
              top: trackTop,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                tween: Tween<double>(end: _isOn ? 1.0 : 0.0),
                builder: (context, t, _) => LiquidGlassToggleTrack(
                  key: _trackKey,
                  value: _isOn,
                  layout: l,
                  tint: widget.activeColor,
                  offColor: widget.inactiveColor,
                  // The rest pill rides INSIDE the lens instead, so it
                  // sits on top of the glass rather than under it.
                  showRestThumb: false,
                  // No hole at rest: the track is one plain capsule until
                  // the thumb starts to lift.
                  pinchFraction: _morph,
                  travelFraction: travelFraction,
                  pillWidth: pillW,
                  pillHeight: pillH,
                  // Two families, not one: the capsule and its shrunken copy
                  // are surfaces; the hole belongs to the pill it is cut for.
                  cornerStyle: _surfaceCorner,
                  holeCornerStyle: pillCorner,
                  // Time-driven, not travel-driven: the colour belongs to
                  // the state flip, and crosses under a held thumb.
                  fraction: t,
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
            left: padX + _thumbCX - pillW / 2,
            bottom: (viewHeight - pillH) / 2,
            extraHeight: 0,
            style: widget.style ?? _clearStyle,
            // Keep the refraction band proportional while the pill
            // is below its full (expanded) size.
            refractionWidthScale:
                (pillH / l.expandedThumbHeight).clamp(0.0, 1.0),
            defaultCornerStyle: LiquidGlassCornerStyle.roundedRectangle,
            defaultBorderWidth: 0.6,
            // The contracted rest pill rides on top of the glass
            // and fades with the morph; the whole control is one
            // gesture surface, so it takes no pointers.
            child: IgnorePointer(
              child: Opacity(
                opacity: restOpacity,
                // Cut to the shared surface corner, not a capsule of its
                // own: the families have to agree or the fill shows a gap
                // at the caps against the glass beneath it. The radius is
                // still the pill's, since this fills the pill's rect —
                // only the family is shared.
                child: liquidGlassClip(
                  shape: LiquidGlassShape(
                    cornerStyle: _surfaceCorner,
                    cornerRadius: pillRadius,
                    clipQuality: LiquidGlassClipQuality.exact,
                  ),
                  child: ColoredBox(color: widget.thumbColor),
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
                    left: padX + _thumbCX - pillW / 2,
                    bottom: (viewHeight - pillH) / 2,
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
    );

    // The footprint is the track alone; the capture paints around it
    // through the OverflowBox, clipped by nobody — the Flutter reading
    // of unclipped. The gesture surface is the track either way.
    final Widget control = SizedBox(
      width: l.width,
      height: l.height,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: liquidGlassEagerPanGestures(
          debugOwner: this,
          onDown: _handleDown,
          onMove: _handleMove,
          onUp: _handleUp,
          onCancel: _handleCancel,
        ),
        child: OverflowBox(
          maxWidth: viewWidth,
          maxHeight: viewHeight,
          child: view,
        ),
      ),
    );

    if (!widget.reserveSwellRoom) return control;
    // Same painting, but the room the swell needs is claimed from the
    // parent instead of overflowing into it.
    return SizedBox(
      width: viewWidth,
      height: viewHeight,
      child: Center(child: control),
    );
  }
}
