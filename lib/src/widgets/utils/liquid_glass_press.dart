import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../liquid_glass_config.dart';
import 'liquid_glass_jelly_spring.dart';
import 'liquid_glass_shape.dart';

/// Touch-driven **soft-body deformation** for a lens that does not move.
///
/// Press a lens and it compresses under your finger; drag and it elongates
/// along the pull, pinches in the cross axis, and leans after your finger —
/// then springs back with a wobble when you let go.
///
/// ## The model: four independent edges
///
/// Unlike a scale transform — which can only grow symmetrically around one
/// anchor — this moves the lens's **left, right, top and bottom edges
/// independently**. That is what makes it read as *soft*: the half of the
/// shape nearest your finger deforms more than the far half.
///
/// The grab point drives that split. Grab near the right edge and pull
/// right: the right edge shoots out while the left barely follows. Grab
/// dead centre and the same pull elongates both sides evenly. [grip]
/// controls how localized this is (`0` = fully symmetric, `1` = fully
/// local).
///
/// ## Volume is preserved, not gained
///
/// Whatever the along-axis edges gain, the cross-axis edges give back:
/// `(w + g)·(h - loss) = w·h`. Elongate horizontally and it genuinely gets
/// *thinner*. [squeeze] scales that give-back (`1` = full preservation,
/// `0` = none).
///
/// ## Press deepens the refraction
///
/// A press with no drag is not a scale-up — it is a slight inset plus a
/// deeper refraction ([refractionBoost]), so the glass reads as being
/// compressed rather than as a rubber button popping.
///
/// ```dart
/// LiquidGlassLens(
///   press: const LiquidGlassPress(),
///   style: const LiquidGlassStyle(
///     shape: LiquidGlassShape.roundedRectangle(cornerRadius: 28),
///   ),
///   child: const Center(child: Text('press me')),
/// )
/// ```
@immutable
class LiquidGlassPress {
  /// Peak elongation along the pull axis, in logical pixels, reached as the
  /// drag saturates at [maxPull].
  final double stretch;

  /// How much of the along-axis gain is taken back from the cross axis.
  /// `1` preserves area exactly, `0` lets the lens simply grow.
  final double squeeze;

  /// How far the whole body slides after the finger, as a fraction of
  /// [stretch]. This is the "it is attached to my thumb" cue; `0` keeps the
  /// lens centred and only deforms it.
  final double lean;

  /// How localized the deformation is to the grab point, `0`–`1`.
  ///
  /// `0` — every edge shares the deformation equally, wherever you touched.
  /// `1` — the edges nearest your finger take all of it.
  final double grip;

  /// Inset applied to every edge on touch-down before any drag, in logical
  /// pixels, weighted toward the grab point by [grip].
  final double press;

  /// Drag distance in logical pixels at which the pull saturates.
  ///
  /// The raw drag is passed through `tanh(pull / maxPull)`, so small drags
  /// track the finger almost 1:1 while large ones stop dead at a
  /// predictable ceiling — the deformation never exceeds [stretch].
  final double maxPull;

  /// How strongly the lens's content follows the deformation, `0`–`1`.
  ///
  /// The child is always laid out at the lens's **rest** size and then
  /// scaled, so it stretches as pixels instead of re-flowing — text never
  /// re-wraps and rows never re-space. `0` leaves the content undisturbed
  /// (best for dense text), `1` makes it fully rubbery.
  final double childFollow;

  /// How much deeper the glass refracts while pressed, as a fraction.
  /// `0.15` means magnification and distortion rise by up to 15%.
  final double refractionBoost;

  /// Edge spring stiffness.
  final double stiffness;

  /// Edge spring damping while the finger is down. Higher → the edges
  /// track the drag more tightly.
  final double damping;

  /// Edge spring damping after release. Lower than [damping] on purpose:
  /// that is what produces the recoil wobble when you let go.
  final double releaseDamping;

  const LiquidGlassPress({
    this.stretch = 14,
    this.squeeze = 0.7,
    this.lean = 0.35,
    this.grip = 0.7,
    this.press = 2,
    this.maxPull = 48,
    this.childFollow = 0.6,
    this.refractionBoost = 0.15,
    this.stiffness = 320,
    this.damping = 24,
    this.releaseDamping = 17,
  });

  /// Barely-there deformation for large surfaces (cards, sheets, bars),
  /// where a big wobble would look wrong.
  const LiquidGlassPress.subtle()
      : stretch = 6,
        squeeze = 0.8,
        lean = 0.25,
        grip = 0.5,
        press = 1.5,
        maxPull = 60,
        childFollow = 0.35,
        refractionBoost = 0.1,
        stiffness = 340,
        damping = 26,
        releaseDamping = 20;

  /// Symmetric, finger-following deformation that **ignores the grab
  /// point** ([grip] `0`): touch anywhere and the lens deforms the same
  /// way, leaning hard after the drag rather than yielding where you
  /// pressed it.
  ///
  /// It barely squashes ([squeeze] `0.33`), leans further than it stretches
  /// ([lean] above `1`), takes no optical boost, and lets the content go
  /// fully rubbery ([childFollow] `1`). The springs are slow and loose — a
  /// half-second, bouncy settle rather than a tight snap.
  ///
  /// The result reads as one soft body sliding under your thumb, closer to
  /// a rubber sheet than to pressed glass. Reach for it when the lens
  /// should feel uniformly squishy and the touch point is not meant to
  /// matter.
  const LiquidGlassPress.uniform()
      : stretch = 4.7,
        squeeze = 0.33,
        lean = 1.37,
        grip = 0,
        press = 0,
        maxPull = 26,
        childFollow = 1,
        refractionBoost = 0,
        stiffness = 158,
        damping = 22,
        releaseDamping = 18;

  /// Loose, obviously-soft deformation for small controls (buttons, chips,
  /// app icons) where the jelly is the point.
  const LiquidGlassPress.pronounced()
      : stretch = 22,
        squeeze = 0.65,
        lean = 0.45,
        grip = 0.85,
        press = 3,
        maxPull = 40,
        childFollow = 0.75,
        refractionBoost = 0.22,
        stiffness = 280,
        damping = 20,
        releaseDamping = 13;

  LiquidGlassPress copyWith({
    double? stretch,
    double? squeeze,
    double? lean,
    double? grip,
    double? press,
    double? maxPull,
    double? childFollow,
    double? refractionBoost,
    double? stiffness,
    double? damping,
    double? releaseDamping,
  }) {
    return LiquidGlassPress(
      stretch: stretch ?? this.stretch,
      squeeze: squeeze ?? this.squeeze,
      lean: lean ?? this.lean,
      grip: grip ?? this.grip,
      press: press ?? this.press,
      maxPull: maxPull ?? this.maxPull,
      childFollow: childFollow ?? this.childFollow,
      refractionBoost: refractionBoost ?? this.refractionBoost,
      stiffness: stiffness ?? this.stiffness,
      damping: damping ?? this.damping,
      releaseDamping: releaseDamping ?? this.releaseDamping,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassPress &&
          other.stretch == stretch &&
          other.squeeze == squeeze &&
          other.lean == lean &&
          other.grip == grip &&
          other.press == press &&
          other.maxPull == maxPull &&
          other.childFollow == childFollow &&
          other.refractionBoost == refractionBoost &&
          other.stiffness == stiffness &&
          other.damping == damping &&
          other.releaseDamping == releaseDamping;

  @override
  int get hashCode => Object.hash(stretch, squeeze, lean, grip, press, maxPull,
      childFollow, refractionBoost, stiffness, damping, releaseDamping);
}

/// One resolved frame of [LiquidGlassPress] deformation.
///
/// The four edge values are how far each edge has moved **outward** from
/// rest, in logical pixels; negative means the edge has moved inward.
@immutable
class LiquidGlassPressDeform {
  /// Outward travel of the left edge (grows the lens leftward).
  final double left;

  /// Outward travel of the right edge.
  final double right;

  /// Outward travel of the top edge.
  final double top;

  /// Outward travel of the bottom edge.
  final double bottom;

  /// Horizontal pixel scale for the lens's content.
  final double childScaleX;

  /// Vertical pixel scale for the lens's content.
  final double childScaleY;

  /// The point the content scales about — the grab point, pulled toward
  /// centre by [LiquidGlassPress.grip].
  final Alignment childAnchor;

  /// Smoothed "finger is down" amount, `0`–`1`. Drives
  /// [LiquidGlassPress.refractionBoost].
  final double pressAmount;

  const LiquidGlassPressDeform({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.childScaleX,
    required this.childScaleY,
    required this.childAnchor,
    required this.pressAmount,
  });

  /// The untouched, fully settled state.
  static const LiquidGlassPressDeform none = LiquidGlassPressDeform(
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    childScaleX: 1,
    childScaleY: 1,
    childAnchor: Alignment.center,
    pressAmount: 0,
  );

  /// Whether there is nothing to draw differently — lets callers skip every
  /// wrapper widget entirely when the lens is at rest.
  bool get isRest =>
      left == 0 &&
      right == 0 &&
      top == 0 &&
      bottom == 0 &&
      childScaleX == 1 &&
      childScaleY == 1;

  /// Total width gained (left + right travel).
  double get widthDelta => left + right;

  /// Total height gained (top + bottom travel).
  double get heightDelta => top + bottom;

  /// The deformed size for a lens whose rest size is [rest].
  Size sizeFrom(Size rest) => Size(
        math.max(0.0, rest.width + widthDelta),
        math.max(0.0, rest.height + heightDelta),
      );

  /// How far the deformed lens's top-left sits from the rest top-left.
  /// Negative on each axis when the leading edges push outward.
  Offset get originShift => Offset(-left, -top);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassPressDeform &&
          other.left == left &&
          other.right == right &&
          other.top == top &&
          other.bottom == bottom &&
          other.childScaleX == childScaleX &&
          other.childScaleY == childScaleY &&
          other.childAnchor == childAnchor &&
          other.pressAmount == pressAmount;

  @override
  int get hashCode => Object.hash(left, right, top, bottom, childScaleX,
      childScaleY, childAnchor, pressAmount);
}

/// Owns the physics behind [LiquidGlassPress]: five springs (one per edge,
/// plus one tracking the press itself) driven by a `Ticker`.
///
/// Feed it pointer events — [down], [move], [up] — keep [restSize] current,
/// and listen to [value] for the resolved [LiquidGlassPressDeform]. While
/// nothing is touching the lens the ticker is stopped, so an idle lens
/// costs nothing.
///
/// The four edges spring **independently** toward their own targets. They
/// share one tuning so the motion stays coherent, but because their targets
/// differ they settle slightly out of phase — the lens jiggles back to rest
/// instead of snapping as one rigid block.
class LiquidGlassPressDriver extends ValueNotifier<LiquidGlassPressDeform> {
  LiquidGlassPressDriver({
    required TickerProvider vsync,
    required LiquidGlassPress spec,
  })  : _vsync = vsync,
        _spec = spec,
        super(LiquidGlassPressDeform.none);

  final TickerProvider _vsync;

  LiquidGlassPress _spec;

  /// Live tuning. Changing it does not interrupt an in-flight deformation;
  /// the springs simply chase the new targets.
  LiquidGlassPress get spec => _spec;
  set spec(LiquidGlassPress value) {
    if (_spec == value) return;
    _spec = value;
    if (_running) _retarget();
  }

  /// The lens's undeformed size. Keep this in sync with layout — the
  /// deformation is resolved against it every tick.
  Size restSize = Size.zero;

  Ticker? _ticker;
  bool _running = false;
  Duration _lastTick = Duration.zero;

  /// Grab point in normalized lens coordinates (`0`–`1` on each axis).
  Offset _grab = const Offset(0.5, 0.5);

  /// Accumulated drag since touch-down, in logical pixels.
  ///
  /// Accumulated from `PointerEvent.delta` rather than measured against
  /// `localPosition`: the lens is deforming *underneath* the finger, so a
  /// position measured in lens-local space would feed the deformation back
  /// into its own input.
  Offset _pull = Offset.zero;

  bool _down = false;

  // Edge spring state — position and velocity per edge, in pixels.
  double _l = 0, _r = 0, _t = 0, _b = 0;
  double _lv = 0, _rv = 0, _tv = 0, _bv = 0;

  // Press spring state, 0..1.
  double _p = 0, _pv = 0;

  // Latest targets, recomputed each tick from the raw gesture state.
  double _lT = 0, _rT = 0, _tT = 0, _bT = 0;

  /// Whether a finger is currently on the lens.
  bool get isPressed => _down;

  /// Begins a press. [local] is the touch position in lens-local
  /// coordinates and [size] the lens's rest size.
  void down(Offset local, Size size) {
    restSize = size;
    _grab = size.isEmpty
        ? const Offset(0.5, 0.5)
        : Offset(
            (local.dx / size.width).clamp(0.0, 1.0),
            (local.dy / size.height).clamp(0.0, 1.0),
          );
    _pull = Offset.zero;
    _down = true;
    _retarget();
    _start();
  }

  /// Accumulates a drag delta. No-op unless a press is active.
  void move(Offset delta) {
    if (!_down) return;
    _pull += delta;
    _retarget();
  }

  /// Ends the press. The springs carry the recoil from here.
  void up() {
    if (!_down) return;
    _down = false;
    _pull = Offset.zero;
    _retarget();
    _start();
  }

  void _start() {
    if (_running) return;
    _running = true;
    _lastTick = Duration.zero;
    (_ticker ??= _vsync.createTicker(_onTick)).start();
  }

  /// Recomputes the four edge targets from the current gesture state.
  ///
  /// This is the whole deformation model, and it runs in four steps:
  /// elongate along the pull, lean the body after the finger, take the
  /// gained area back out of the cross axis, then inset under the press.
  void _retarget() {
    final double w = restSize.width;
    final double h = restSize.height;
    if (w <= 0 || h <= 0) {
      _lT = _rT = _tT = _bT = 0;
      return;
    }

    final s = _spec;
    final double maxPull = math.max(1e-3, s.maxPull);
    final double grip = s.grip.clamp(0.0, 1.0);

    // Saturating drive: linear near zero, hard ceiling at ±1.
    final double ux = _tanh(_pull.dx / maxPull);
    final double uy = _tanh(_pull.dy / maxPull);

    // Grab-point edge weights. Each opposing pair sums to 1, so the total
    // elongation is conserved however it is split.
    final double gx = _grab.dx;
    final double gy = _grab.dy;
    final double wR = _lerp(0.5, gx, grip);
    final double wL = _lerp(0.5, 1 - gx, grip);
    final double wB = _lerp(0.5, gy, grip);
    final double wT = _lerp(0.5, 1 - gy, grip);

    // 1. Elongation along each pull axis, split by grab proximity.
    final double gainX = s.stretch * ux.abs();
    final double gainY = s.stretch * uy.abs();
    double dl = gainX * wL;
    double dr = gainX * wR;
    double dt = gainY * wT;
    double db = gainY * wB;

    // 2. Lean — a translation expressed as opposing edge travel.
    final double leanX = s.stretch * s.lean * ux;
    final double leanY = s.stretch * s.lean * uy;
    dr += leanX;
    dl -= leanX;
    db += leanY;
    dt -= leanY;

    // 3. Volume: solve (w + gainX)·(h - lossH) = w·h for the give-back,
    // then scale it by `squeeze`. Self-scaling, so a wide pill pinches by
    // the same *proportion* as a small square.
    final double lossH = s.squeeze * h * gainX / (w + gainX);
    final double lossW = s.squeeze * w * gainY / (h + gainY);
    dt -= lossH * wT;
    db -= lossH * wB;
    dl -= lossW * wL;
    dr -= lossW * wR;

    // 4. Press inset, biased toward the grab point.
    if (_down) {
      final double p = s.press;
      dl -= p * math.max(0.0, _lerp(1, 2 * (1 - gx), grip));
      dr -= p * math.max(0.0, _lerp(1, 2 * gx, grip));
      dt -= p * math.max(0.0, _lerp(1, 2 * (1 - gy), grip));
      db -= p * math.max(0.0, _lerp(1, 2 * gy, grip));
    }

    // Floor each edge so the lens can never collapse through itself.
    final double floorX = -w * 0.375;
    final double floorY = -h * 0.375;
    _lT = math.max(dl, floorX);
    _rT = math.max(dr, floorX);
    _tT = math.max(dt, floorY);
    _bT = math.max(db, floorY);
  }

  void _onTick(Duration elapsed) {
    final double dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // Clamp so a dropped frame cannot explode the springs.
    final double step = dt.clamp(0.0, 1 / 30);

    _retarget();

    final s = _spec;
    // Release is deliberately less damped than the drag — that asymmetry
    // is the recoil wobble.
    final double damping = _down ? s.damping : s.releaseDamping;

    final left = liquidGlassSpringStep(
        x: _l,
        vel: _lv,
        target: _lT,
        dt: step,
        stiffness: s.stiffness,
        damping: damping);
    final right = liquidGlassSpringStep(
        x: _r,
        vel: _rv,
        target: _rT,
        dt: step,
        stiffness: s.stiffness,
        damping: damping);
    final top = liquidGlassSpringStep(
        x: _t,
        vel: _tv,
        target: _tT,
        dt: step,
        stiffness: s.stiffness,
        damping: damping);
    final bottom = liquidGlassSpringStep(
        x: _b,
        vel: _bv,
        target: _bT,
        dt: step,
        stiffness: s.stiffness,
        damping: damping);

    // The press scalar rides a stiffer, well-damped spring: the optical
    // boost should follow the finger, not wobble with the geometry.
    final pressed = liquidGlassSpringStep(
      x: _p,
      vel: _pv,
      target: _down ? 1.0 : 0.0,
      dt: step,
      stiffness: 420,
      damping: 34,
    );

    _l = left.$1;
    _lv = left.$2;
    _r = right.$1;
    _rv = right.$2;
    _t = top.$1;
    _tv = top.$2;
    _b = bottom.$1;
    _bv = bottom.$2;
    _p = pressed.$1;
    _pv = pressed.$2;

    final bool settled = !_down &&
        _l.abs() < 0.05 &&
        _r.abs() < 0.05 &&
        _t.abs() < 0.05 &&
        _b.abs() < 0.05 &&
        _lv.abs() < 0.5 &&
        _rv.abs() < 0.5 &&
        _tv.abs() < 0.5 &&
        _bv.abs() < 0.5 &&
        _p < 0.002;

    if (settled) {
      _l = _r = _t = _b = 0;
      _lv = _rv = _tv = _bv = 0;
      _p = _pv = 0;
      _ticker?.stop();
      _running = false;
      _lastTick = Duration.zero;
      value = LiquidGlassPressDeform.none;
      return;
    }

    value = _resolve();
  }

  LiquidGlassPressDeform _resolve() {
    final double w = restSize.width;
    final double h = restSize.height;
    final s = _spec;
    final double follow = s.childFollow.clamp(0.0, 1.0);
    final double grip = s.grip.clamp(0.0, 1.0);

    // Content scales with the box but at its own strength, and about the
    // grab point rather than the centre — so content near the pressed edge
    // travels further than content on the far side.
    final double sx = w > 0
        ? (1 + follow * (_l + _r) / w).clamp(0.25, 4.0).toDouble()
        : 1.0;
    final double sy = h > 0
        ? (1 + follow * (_t + _b) / h).clamp(0.25, 4.0).toDouble()
        : 1.0;

    return LiquidGlassPressDeform(
      left: _l,
      right: _r,
      top: _t,
      bottom: _b,
      childScaleX: sx,
      childScaleY: sy,
      childAnchor: Alignment(
        (grip * (2 * _grab.dx - 1)).clamp(-1.0, 1.0),
        (grip * (2 * _grab.dy - 1)).clamp(-1.0, 1.0),
      ),
      pressAmount: _p.clamp(0.0, 1.0),
    );
  }

  @override
  void dispose() {
    // Stop before disposing: `Ticker.dispose` asserts when it is still
    // active, which is exactly the case if the lens is removed from the
    // tree mid-press.
    _ticker?.stop(canceled: true);
    _ticker?.dispose();
    _ticker = null;
    _running = false;
    super.dispose();
  }
}

/// Lays [child] out at [restSize] and scales its pixels by the deformation.
///
/// This is what makes the lens's content *stretch* rather than re-flow: the
/// child keeps its rest constraints, so text never re-wraps and a row never
/// re-spaces — only the painted result is scaled.
Widget liquidGlassPressChild({
  required Widget child,
  required LiquidGlassPressDeform deform,
  required Size restSize,
}) {
  if (deform.isRest || restSize.isEmpty) return child;
  return OverflowBox(
    alignment: Alignment.center,
    minWidth: restSize.width,
    maxWidth: restSize.width,
    minHeight: restSize.height,
    maxHeight: restSize.height,
    child: Transform.scale(
      scaleX: deform.childScaleX,
      scaleY: deform.childScaleY,
      alignment: deform.childAnchor,
      child: child,
    ),
  );
}

/// Wraps a layout-driven lens so it keeps a stable [restSize] footprint
/// while the deformed glass overflows around it — neighbouring widgets
/// never shift as the lens wobbles.
///
/// Deliberately pure layout (`Stack` + `Positioned`, no `Transform`): the
/// lens reads its own size from layout and its position from
/// `localToGlobal`, so growing the box is the only way to make the shader
/// actually refract at the deformed dimensions.
Widget liquidGlassPressBox({
  required Widget child,
  required LiquidGlassPressDeform deform,
  required Size restSize,
}) {
  if (deform.isRest) return child;
  final Size deformed = deform.sizeFrom(restSize);
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: deform.originShift.dx,
        top: deform.originShift.dy,
        width: deformed.width,
        height: deformed.height,
        child: child,
      ),
    ],
  );
}

/// Deepens the optics while the lens is pressed.
///
/// A press is not a scale-up here — it is a slight inset plus *more*
/// refraction, which is what makes the surface read as glass being
/// compressed rather than as a rubber button popping. [amount] is the
/// smoothed press scalar from [LiquidGlassPressDeform.pressAmount].
///
/// [LiquidGlassRefraction.magnification] always responds. The legacy
/// `distortion` is only boosted when no [LiquidGlassRefractionType] is
/// configured, because a configured type carries its own strength and
/// overrides that field.
LiquidGlassRefraction liquidGlassPressRefraction(
  LiquidGlassRefraction refraction,
  LiquidGlassPress spec,
  double amount,
) {
  final double k = spec.refractionBoost * amount.clamp(0.0, 1.0);
  if (k <= 0) return refraction;
  return refraction.copyWith(
    magnification: refraction.magnification * (1 + k),
    distortion: refraction.refractionType == null
        ? refraction.distortion * (1 + k)
        : null,
  );
}

/// Applies [deform] to a position-driven lens config — the deformed size, a
/// corner radius capped to that size, and the pressed-in refraction.
///
/// Both the plain [LiquidGlass.shape] / [LiquidGlass.refraction] groups and
/// a [LiquidGlassStyle] override are rewritten, because `effectiveShape` and
/// `effectiveRefraction` read the style first whenever one is set.
///
/// The lens's *position* is deliberately untouched: it is carried separately
/// as [LiquidGlassPressDeform.originShift] so the deformation never leaks
/// into the position bookkeeping that resolves and clamps the rest layout.
LiquidGlass liquidGlassPressConfig(
  LiquidGlass config,
  LiquidGlassPress spec,
  LiquidGlassPressDeform deform,
) {
  if (deform.isRest && deform.pressAmount <= 0) return config;

  final Size rest = Size(config.geometry.width, config.geometry.height);
  final Size size = deform.sizeFrom(rest);
  final LiquidGlassShape shape =
      liquidGlassPressShape(config.effectiveShape, size);
  final LiquidGlassRefraction refraction = liquidGlassPressRefraction(
      config.effectiveRefraction, spec, deform.pressAmount);

  return config.copyWith(
    geometry: config.geometry.copyWith(width: size.width, height: size.height),
    shape: shape,
    refraction: refraction,
    style: config.style?.copyWith(shape: shape, refraction: refraction),
  );
}

/// Keeps a shape valid at a deformed [size] by capping its corner radius to
/// half the shorter side — without this a squeezed capsule stops being a
/// capsule and the rim self-intersects.
///
/// Applied only along the press path, so a lens with no [LiquidGlassPress]
/// keeps its authored radius exactly.
LiquidGlassShape liquidGlassPressShape(LiquidGlassShape shape, Size size) {
  if (size.isEmpty) return shape;
  final double cap = math.min(size.width, size.height) / 2;
  if (shape.cornerRadius <= cap) return shape;
  return LiquidGlassShape(
    cornerStyle: shape.cornerStyle,
    cornerRadius: cap,
    clipQuality: shape.clipQuality,
    borderWidth: shape.borderWidth,
    borderColor: shape.borderColor,
    lightIntensity: shape.lightIntensity,
    lightColor: shape.lightColor,
    lightDirection: shape.lightDirection,
    lightMode: shape.lightMode,
    borderType: shape.borderType,
  );
}

/// Hyperbolic tangent — the saturation curve behind [LiquidGlassPress.maxPull].
/// Not in `dart:math`, so it is derived from `exp` here.
double _tanh(double x) {
  if (x > 20) return 1;
  if (x < -20) return -1;
  final double e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
