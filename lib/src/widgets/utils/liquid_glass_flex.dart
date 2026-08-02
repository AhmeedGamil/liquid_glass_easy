import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../liquid_glass_config.dart';
import 'liquid_glass_jelly_spring.dart';
import 'liquid_glass_refraction_type.dart';

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
/// ## Hold and tap are separate responses
///
/// [holdScale] resizes the lens for as long as the finger stays down — the
/// swell of a control being held. [tapScale] is a one-shot pop fired the
/// moment a tap *completes*, so a quick click still reads as a click even
/// though nothing was held long enough for the hold to arrive. Both are
/// signed: positive swells, negative yields inward.
///
/// A press also deepens the optics
/// ([LiquidGlassFlexTuning.refractionBoost]), which is what makes the
/// surface read as glass being compressed rather than as a rubber button
/// popping.
///
/// ## Only nine knobs
///
/// Everything you would reach for while dialling in a feel is a direct
/// parameter. The five that are set once and forgotten — content follow,
/// optical boost, and the three spring constants — live in
/// [LiquidGlassFlexTuning] behind [tuning], so they stay out of the
/// way without being out of reach.
///
/// ```dart
/// LiquidGlassLens(
///   touch: const LiquidGlassTouch.flexing(LiquidGlassFlex()),
///   style: const LiquidGlassStyle(
///     shape: LiquidGlassShape.roundedRectangle(cornerRadius: 28),
///   ),
///   child: const Center(child: Text('press me')),
/// )
/// ```
@immutable
class LiquidGlassFlex {
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

  /// Whether driving the grabbed edge **into** the body compresses it.
  ///
  /// The deformation assumes the finger grips the surface and the far side
  /// lags. Pull an edge away from the middle and the body elongates. Push
  /// that same edge inward and the far side still lags, so with this on the
  /// body **squashes** — and [squeeze] then bulges the cross axis outward,
  /// since its give-back is signed both ways.
  ///
  /// `false` restores the original response, where the pull's *magnitude*
  /// drove the elongation and the shape grew whichever way it was pushed.
  /// That path is bit-identical to the pre-compression behaviour, not an
  /// approximation of it.
  ///
  /// How directional it is fades with how far off-centre the grab is and
  /// with [grip]: a grab on the exact middle has no near edge to push into,
  /// so it stretches symmetrically either way regardless of this flag.
  final bool compressInward;

  /// How much the lens resizes **while the finger stays down**, before any
  /// drag — a **signed fraction** of its own size, weighted toward the grab
  /// point by [grip].
  ///
  /// **Positive grows it**, the way a glass control swells under a press:
  /// `0.03` makes it 3% bigger on both axes. **Negative compresses it**, for
  /// a surface that yields inward instead. `0` leaves the size alone and lets
  /// [LiquidGlassFlexTuning.refractionBoost] carry the press on its own.
  ///
  /// This is the *tap-and-hold* response: it arrives on a spring and stays
  /// for as long as you hold. For the response to a quick click, see
  /// [tapScale].
  ///
  /// A fraction rather than pixels so the same value reads identically on a
  /// 56pt button and a 320pt bar — a fixed pixel inset would be invisible on
  /// one and enormous on the other.
  final double holdScale;

  /// A one-shot size **pop** fired when a tap completes — the click
  /// feedback. Same signed-fraction units as [holdScale]; `0` disables it.
  ///
  /// A tap is a release with no meaningful drag (under [kTouchSlop]) inside
  /// [kLongPressTimeout] — Flutter's own definition, so this fires on exactly
  /// the gestures a `GestureDetector.onTap` would. Hold past that, or drag,
  /// and only [holdScale] applies.
  ///
  /// It exists because [holdScale] alone cannot express a click: a fast tap
  /// releases before the hold spring has arrived anywhere, so the lens barely
  /// moves. The pop is injected at release and decays over ~90 ms, and the
  /// edge springs turn that into a rebound.
  final double tapScale;

  /// Drag distance in logical pixels at which the pull saturates.
  ///
  /// The raw drag is passed through `tanh(pull / maxPull)`, so small drags
  /// track the finger almost 1:1 while large ones stop dead at a
  /// predictable ceiling — the deformation never exceeds [stretch].
  final double maxPull;

  /// Confines the **drag** to one axis: [Axis.horizontal] pins the top and
  /// bottom edges against a pull, [Axis.vertical] pins the left and right.
  /// `null` (the default) leaves all four free.
  ///
  /// For a shape whose proportions carry meaning — a bottom nav capsule, a
  /// segmented control, a slider track — the cross axis is not a free
  /// dimension. A bar that thickens under a sideways drag, or slides up off
  /// its own bottom margin, reads as broken rather than as soft.
  ///
  /// It covers everything the *pull* produces on that axis: elongation,
  /// lean, and the volume give-back — so a horizontally locked lens widens
  /// without thinning.
  ///
  /// It does **not** touch [holdScale] or [tapScale]. Those stay uniform on
  /// both axes, because a press is a swell rather than a stretch: flattening
  /// it onto one axis reads as the surface warping instead of yielding. So a
  /// locked bar still grows in both directions under a finger; it just will
  /// not change shape when dragged.
  ///
  /// Enforced on the spring *targets*, so a locked edge never loads a spring
  /// from the drag at all.
  final Axis? lockAxis;

  /// The set-once knobs: content follow, optical boost, spring constants.
  /// Kept out of this constructor so the ones that matter stay visible.
  final LiquidGlassFlexTuning tuning;

  /// See [LiquidGlassFlexTuning.childFollow].
  double get childFollow => tuning.childFollow;

  /// See [LiquidGlassFlexTuning.refractionBoost].
  double get refractionBoost => tuning.refractionBoost;

  /// See [LiquidGlassFlexTuning.magnificationBoost].
  double get magnificationBoost => tuning.magnificationBoost;

  /// See [LiquidGlassFlexTuning.stiffness].
  double get stiffness => tuning.stiffness;

  /// See [LiquidGlassFlexTuning.damping].
  double get damping => tuning.damping;

  /// See [LiquidGlassFlexTuning.releaseDamping].
  double get releaseDamping => tuning.releaseDamping;

  const LiquidGlassFlex({
    this.stretch = 11,
    this.squeeze = 0.70,
    this.lean = 0.70,
    this.grip = 0.70,
    this.compressInward = true,
    this.holdScale = 0.030,
    this.tapScale = 0.020,
    this.maxPull = 48,
    this.lockAxis,
    this.tuning = const LiquidGlassFlexTuning(),
  });

  /// Barely-there deformation for large surfaces (cards, sheets, bars),
  /// where a big wobble would look wrong.
  const LiquidGlassFlex.subtle()
      : stretch = 6,
        squeeze = 0.8,
        lean = 0.25,
        grip = 0.5,
        compressInward = true,
        holdScale = 0.015,
        tapScale = 0.010,
        maxPull = 60,
        lockAxis = null,
        tuning = const LiquidGlassFlexTuning(
          refractionBoost: 0.1,
          stiffness: 340,
          damping: 26,
          releaseDamping: 20,
        );

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
  const LiquidGlassFlex.uniform()
      : stretch = 4.7,
        squeeze = 0.33,
        lean = 1.37,
        grip = 0,
        compressInward = true,
        holdScale = 0.05,
        tapScale = 0.03,
        maxPull = 26,
        lockAxis = null,
        tuning = const LiquidGlassFlexTuning(
          refractionBoost: 0,
          stiffness: 158,
          damping: 22,
          releaseDamping: 18,
        );

  /// Loose, obviously-soft deformation for small controls (buttons, chips,
  /// app icons) where the jelly is the point.
  const LiquidGlassFlex.pronounced()
      : stretch = 22,
        squeeze = 0.65,
        lean = 0.45,
        grip = 0.85,
        compressInward = true,
        holdScale = 0.05,
        tapScale = 0.035,
        maxPull = 40,
        lockAxis = null,
        tuning = const LiquidGlassFlexTuning(
          refractionBoost: 0.22,
          stiffness: 280,
          damping: 20,
          releaseDamping: 13,
        );

  /// Mirrors the constructor. To change one of the set-once knobs, go
  /// through the group: `copyWith(tuning: e.tuning.copyWith(damping: 20))`.
  LiquidGlassFlex copyWith({
    double? stretch,
    double? squeeze,
    double? lean,
    double? grip,
    bool? compressInward,
    double? holdScale,
    double? tapScale,
    double? maxPull,
    Axis? lockAxis,
    LiquidGlassFlexTuning? tuning,
  }) {
    return LiquidGlassFlex(
      stretch: stretch ?? this.stretch,
      squeeze: squeeze ?? this.squeeze,
      lean: lean ?? this.lean,
      grip: grip ?? this.grip,
      compressInward: compressInward ?? this.compressInward,
      holdScale: holdScale ?? this.holdScale,
      tapScale: tapScale ?? this.tapScale,
      maxPull: maxPull ?? this.maxPull,
      lockAxis: lockAxis ?? this.lockAxis,
      tuning: tuning ?? this.tuning,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassFlex &&
          other.stretch == stretch &&
          other.squeeze == squeeze &&
          other.lean == lean &&
          other.grip == grip &&
          other.compressInward == compressInward &&
          other.holdScale == holdScale &&
          other.tapScale == tapScale &&
          other.maxPull == maxPull &&
          other.lockAxis == lockAxis &&
          other.tuning == tuning;

  @override
  int get hashCode => Object.hash(stretch, squeeze, lean, grip,
      compressInward, holdScale, tapScale, maxPull, lockAxis, tuning);
}

/// The knobs of [LiquidGlassFlex] that are set once and then left
/// alone — grouped so they stay out of the main constructor.
///
/// Reach for them when the *feel* is right but something else is off: the
/// content is fighting the glass ([childFollow]), the optics are too shallow
/// ([refractionBoost]), or the settle is too tight or too loose (the three
/// spring constants).
@immutable
class LiquidGlassFlexTuning {
  /// How strongly the lens's content follows the deformation, `0`–`1`.
  ///
  /// The child is always laid out at the lens's **rest** size and then
  /// scaled, so it stretches as pixels instead of re-flowing — text never
  /// re-wraps and rows never re-space. `0` leaves the content undisturbed
  /// (best for dense text), `1` makes it fully rubbery.
  final double childFollow;

  /// How much harder the glass BENDS while pressed, as a fraction. `0.15`
  /// means the refraction strength rises by up to 15% at full press.
  ///
  /// Only the bending. The separate [magnificationBoost] carries the zoom,
  /// because they are different effects and only one of them is refraction.
  final double refractionBoost;

  /// How much the backdrop is ZOOMED while pressed, as a fraction of
  /// [LiquidGlassRefraction.magnification]. `0.15` magnifies what is behind
  /// the glass by up to 15% at full press.
  ///
  /// **Off by default**, and deliberately separate from [refractionBoost].
  /// Magnification is not a refraction depth — it scales the content behind
  /// the lens about its centre, so a press reads as the background sliding
  /// rather than as glass bending. Apple keys lensing to a surface's SIZE,
  /// not to a finger being down, and its press cue is light instead. Turn
  /// this up only if you want that zoom on purpose.
  final double magnificationBoost;

  /// Edge spring stiffness.
  final double stiffness;

  /// Edge spring damping while the finger is down. Higher → the edges
  /// track the drag more tightly.
  final double damping;

  /// Edge spring damping after release. Lower than [damping] on purpose:
  /// that is what produces the recoil wobble when you let go.
  final double releaseDamping;

  const LiquidGlassFlexTuning({
    this.childFollow = 1,
    this.refractionBoost = 0.15,
    this.magnificationBoost = 0,
    this.stiffness = 320,
    this.damping = 24,
    this.releaseDamping = 17,
  });

  LiquidGlassFlexTuning copyWith({
    double? childFollow,
    double? refractionBoost,
    double? magnificationBoost,
    double? stiffness,
    double? damping,
    double? releaseDamping,
  }) {
    return LiquidGlassFlexTuning(
      childFollow: childFollow ?? this.childFollow,
      refractionBoost: refractionBoost ?? this.refractionBoost,
      magnificationBoost: magnificationBoost ?? this.magnificationBoost,
      stiffness: stiffness ?? this.stiffness,
      damping: damping ?? this.damping,
      releaseDamping: releaseDamping ?? this.releaseDamping,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassFlexTuning &&
          other.childFollow == childFollow &&
          other.refractionBoost == refractionBoost &&
          other.magnificationBoost == magnificationBoost &&
          other.stiffness == stiffness &&
          other.damping == damping &&
          other.releaseDamping == releaseDamping;

  @override
  int get hashCode => Object.hash(childFollow, refractionBoost,
      magnificationBoost, stiffness, damping, releaseDamping);
}

/// One resolved frame of [LiquidGlassFlex] deformation.
///
/// The four edge values are how far each edge has moved **outward** from
/// rest, in logical pixels; negative means the edge has moved inward.
@immutable
class LiquidGlassFlexDeform {
  /// Outward travel of the left edge (grows the lens leftward).
  final double left;

  /// Outward travel of the right edge.
  final double right;

  /// Outward travel of the top edge.
  final double top;

  /// Outward travel of the bottom edge.
  final double bottom;

  /// Horizontal component of the content's transform.
  ///
  /// Together with [childTranslateX] this is the **glass's own** map,
  /// blended toward identity by [LiquidGlassFlex.childFollow]. See
  /// [childTransform].
  final double childScaleX;

  /// Vertical component of the content's transform. See [childTransform].
  final double childScaleY;

  /// Horizontal offset of the content's transform, in logical pixels,
  /// measured from the **deformed** box's top-left. See [childTransform].
  final double childTranslateX;

  /// Vertical offset of the content's transform. See [childTransform].
  final double childTranslateY;

  /// Smoothed "finger is down" amount, `0`–`1`. Drives
  /// [LiquidGlassFlex.refractionBoost].
  final double pressAmount;

  const LiquidGlassFlexDeform({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.childScaleX,
    required this.childScaleY,
    required this.childTranslateX,
    required this.childTranslateY,
    required this.pressAmount,
  });

  /// The untouched, fully settled state.
  static const LiquidGlassFlexDeform none = LiquidGlassFlexDeform(
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    childScaleX: 1,
    childScaleY: 1,
    childTranslateX: 0,
    childTranslateY: 0,
    pressAmount: 0,
  );

  /// The content's transform, anchored at the **deformed** box's top-left.
  ///
  /// At [LiquidGlassFlex.childFollow] `1` this is *literally* the map
  /// the glass performs on itself, so the content cannot drift away from the
  /// surface — they are the same transform, not two tuned approximations.
  ///
  /// Derivation, per axis, in rest coordinates: the glass sends the rest span
  /// `[0, w]` to `[-left, w + right]`, which is the linear map
  /// `x' = sx·x - left` with `sx = (w + left + right) / w`. Expressed from
  /// the deformed box's own origin (which sits at rest `-left`) that becomes
  /// `x' = sx·x`, and blending toward identity by `f` gives
  /// `scale = 1 + f·(sx - 1)`, `translate = (1 - f)·left`.
  /// Column-major, so the last column carries the translation. Built
  /// literally rather than through `translate`/`scale` so the order of the
  /// two is unambiguous: scale first, then offset.
  Matrix4 get childTransform => Matrix4(
        childScaleX, 0, 0, 0, //
        0, childScaleY, 0, 0, //
        0, 0, 1, 0, //
        childTranslateX, childTranslateY, 0, 1, //
      );

  /// Whether there is nothing to draw differently — lets callers skip every
  /// wrapper widget entirely when the lens is at rest.
  bool get isRest =>
      left == 0 &&
      right == 0 &&
      top == 0 &&
      bottom == 0 &&
      childScaleX == 1 &&
      childScaleY == 1 &&
      childTranslateX == 0 &&
      childTranslateY == 0;

  /// Total width gained (left + right travel).
  double get widthDelta => left + right;

  /// Total height gained (top + bottom travel).
  double get heightDelta => top + bottom;

  /// The deformed size for a lens whose rest size is [rest].
  Size sizeFrom(Size rest) => Size(
        math.max(0.0, rest.width + widthDelta),
        math.max(0.0, rest.height + heightDelta),
      );

  /// Deformed size ÷ [rest] size, as the shader's `u_shapeScale`.
  ///
  /// `(1, 1)` when undeformed. The shader evaluates the shape at REST size in
  /// a domain divided by this, so the deformation stretches the whole outline
  /// -- a circle becomes an ellipse instead of a stadium with flat runs.
  Offset scaleFrom(Size rest) {
    if (debugLiquidGlassFlexOutline ==
        LiquidGlassFlexOutline.legacy) {
      return const Offset(1, 1);
    }
    if (rest.isEmpty) return const Offset(1, 1);
    final Size d = sizeFrom(rest);
    return Offset(
      d.width <= 0 ? 1.0 : d.width / rest.width,
      d.height <= 0 ? 1.0 : d.height / rest.height,
    );
  }

  /// [scaleFrom], but for the CLIPS rather than the shader.
  ///
  /// Identical in normal use. They part company only under
  /// [LiquidGlassFlexOutline.shaderOnly], which stretches the shader's
  /// outline while pinning the clips circular -- the combination that eats the
  /// rim at a cap apex.
  Offset clipScaleFrom(Size rest) =>
      debugLiquidGlassFlexOutline == LiquidGlassFlexOutline.full
          ? scaleFrom(rest)
          : const Offset(1, 1);

  /// How far the deformed lens's top-left sits from the rest top-left.
  /// Negative on each axis when the leading edges push outward.
  Offset get originShift => Offset(-left, -top);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassFlexDeform &&
          other.left == left &&
          other.right == right &&
          other.top == top &&
          other.bottom == bottom &&
          other.childScaleX == childScaleX &&
          other.childScaleY == childScaleY &&
          other.childTranslateX == childTranslateX &&
          other.childTranslateY == childTranslateY &&
          other.pressAmount == pressAmount;

  @override
  int get hashCode => Object.hash(left, right, top, bottom, childScaleX,
      childScaleY, childTranslateX, childTranslateY, pressAmount);
}


/// How much of the stretched-outline behaviour is active. **Debug only.**
///
/// Exists so the fix can be judged against what it replaced on a running
/// device -- a rim is one logical pixel wide, and the difference is not
/// something a screenshot settles.
enum LiquidGlassFlexOutline {
  /// Pre-fix. The shape keeps its authored pixel radius against the DEFORMED
  /// box, so a stretched circle grows flat runs and reads as a stadium.
  legacy,

  /// The shader stretches the outline, but the clips stay circular. They then
  /// CROSS rather than nest: near a cap apex the clip sits inside the glass
  /// and shaves the rim off. This is the intermediate state, kept because it
  /// is the one that looks broken and is worth being able to point at.
  shaderOnly,

  /// Shader and clips both stretch. The shipped behaviour.
  full,
}

/// Switches [LiquidGlassFlexOutline]. **Debug only** -- ships as
/// [LiquidGlassFlexOutline.full] and nothing in the package writes it.
LiquidGlassFlexOutline debugLiquidGlassFlexOutline =
    LiquidGlassFlexOutline.full;

/// Owns the physics behind [LiquidGlassFlex]: five springs (one per edge,
/// plus one tracking the press itself) driven by a `Ticker`.
///
/// Feed it pointer events — [down], [move], [up] — keep [restSize] current,
/// and listen to [value] for the resolved [LiquidGlassFlexDeform]. While
/// nothing is touching the lens the ticker is stopped, so an idle lens
/// costs nothing.
///
/// The four edges spring **independently** toward their own targets. They
/// share one tuning so the motion stays coherent, but because their targets
/// differ they settle slightly out of phase — the lens jiggles back to rest
/// instead of snapping as one rigid block.
class LiquidGlassFlexDriver extends ValueNotifier<LiquidGlassFlexDeform> {
  LiquidGlassFlexDriver({
    required TickerProvider vsync,
    required LiquidGlassFlex spec,
  })  : _vsync = vsync,
        _spec = spec,
        super(LiquidGlassFlexDeform.none);

  final TickerProvider _vsync;

  LiquidGlassFlex _spec;

  /// Live tuning. Changing it does not interrupt an in-flight deformation;
  /// the springs simply chase the new targets.
  LiquidGlassFlex get spec => _spec;
  set spec(LiquidGlassFlex value) {
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

  /// Decaying tap pulse, `1` the instant a tap completes and `0` once it has
  /// died out. Not a spring: it is the *input* the edge springs chase, so the
  /// rebound comes from them rather than from a second oscillator fighting
  /// the first.
  double _tap = 0;

  /// Decay time constant of [_tap], in seconds. Short enough that the pop
  /// reads as a click rather than as a second press.
  static const double _tapTau = 0.09;

  /// When the current press started — half of the tap test.
  DateTime _downAt = DateTime.now();

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
    _downAt = DateTime.now();
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
  ///
  /// If the gesture was a **tap** — released inside [kLongPressTimeout]
  /// without dragging past [kTouchSlop], which is what Flutter's own tap
  /// recognizer accepts — the [LiquidGlassFlex.tapScale] pulse is fired
  /// here. Anything longer or draggier was a hold or a drag, and only the
  /// hold response applies.
  void up() {
    if (!_down) return;
    final bool wasTap = _pull.distance <= kTouchSlop &&
        DateTime.now().difference(_downAt) <= kLongPressTimeout;
    _down = false;
    _pull = Offset.zero;
    if (wasTap && _spec.tapScale != 0) _tap = 1;
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

    // 1. Elongation along each pull axis, split by grab proximity — SIGNED
    // by whether the pull leaves the grabbed edge or drives into it.
    //
    // The model is that the finger grips the surface and the far side lags.
    // Grab an edge and pull away and the body elongates; push the same edge
    // toward the middle and the far side still lags, so the body has to
    // COMPRESS. Using the magnitude alone made both stretch, which reads as
    // the shape inflating whichever way you shove it.
    final double gainX = _axisGain(s.stretch, ux, gx, grip, s.compressInward);
    final double gainY = _axisGain(s.stretch, uy, gy, grip, s.compressInward);
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
    //
    // Signed both ways: a NEGATIVE gain makes the loss negative too, so the
    // cross axis bulges outward instead of pinching in. Compression pushing
    // the body sideways falls out of the same equation.
    //
    // The denominators are floored because a gain can now be negative: on a
    // lens narrower than `stretch`, `w + gainX` would reach zero and the
    // give-back would explode through the edge floors.
    final double lossH =
        s.squeeze * h * gainX / math.max(w + gainX, w * 0.25);
    final double lossW =
        s.squeeze * w * gainY / math.max(h + gainY, h * 0.25);
    dt -= lossH * wT;
    db -= lossH * wB;
    dl -= lossW * wL;
    dr -= lossW * wR;

    // 4. Axis lock — applied to the PULL-DRIVEN deformation only (the three
    // steps above), so a locked shape never changes proportion under a drag.
    // The touch resize below is deliberately left free: a press is a
    // uniform swell, not a stretch, and squashing it onto one axis would
    // read as the surface warping rather than yielding.
    if (s.lockAxis == Axis.horizontal) {
      dt = db = 0;
    } else if (s.lockAxis == Axis.vertical) {
      dl = dr = 0;
    }

    // 5. Touch resize — signed, so it swells (positive) or yields inward
    // (negative). Two additive sources: `holdScale` for as long as the
    // finger is down, and the decaying `tapScale` pop once a tap has
    // completed. They overlap for a frame or two on release, which is what
    // makes a click read as one continuous gesture rather than two events.
    //
    // Proportional to the lens's own size, split by the same grab-point
    // weights, which sum to 1: the total gain is exactly `scale * extent`
    // however it is distributed. Both axes always, lock or no lock.
    final double scale =
        (_down ? s.holdScale : 0.0) + s.tapScale * _tap;
    if (scale != 0) {
      final double growX = scale * w;
      final double growY = scale * h;
      dl += growX * wL;
      dr += growX * wR;
      dt += growY * wT;
      db += growY * wB;
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

    // Decay the tap pop BEFORE retargeting, so this frame's targets already
    // reflect it dying away.
    if (_tap > 0) {
      _tap *= math.exp(-step / _tapTau);
      if (_tap < 0.002) _tap = 0;
    }

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
        _tap == 0 &&
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
      _tap = 0;
      _ticker?.stop();
      _running = false;
      _lastTick = Duration.zero;
      value = LiquidGlassFlexDeform.none;
      return;
    }

    value = _resolve();
  }

  LiquidGlassFlexDeform _resolve() {
    final double w = restSize.width;
    final double h = restSize.height;
    final double f = _spec.childFollow.clamp(0.0, 1.0);

    // The content rides the GLASS'S OWN map, blended toward identity by
    // `childFollow` — not a scale about some separately-chosen anchor. At
    // f == 1 the two transforms are the same expression, so the content
    // cannot drift off the surface however hard the lens is pulled. See
    // [LiquidGlassFlexDeform.childTransform] for the derivation.
    final double glassX = w > 0 ? (w + _l + _r) / w : 1.0;
    final double glassY = h > 0 ? (h + _t + _b) / h : 1.0;

    return LiquidGlassFlexDeform(
      left: _l,
      right: _r,
      top: _t,
      bottom: _b,
      childScaleX: (1 + f * (glassX - 1)).clamp(0.05, 8.0).toDouble(),
      childScaleY: (1 + f * (glassY - 1)).clamp(0.05, 8.0).toDouble(),
      childTranslateX: (1 - f) * _l,
      childTranslateY: (1 - f) * _t,
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

/// Lays [child] out at [restSize] and deforms its pixels with the glass.
///
/// This is what makes the lens's content *stretch* rather than re-flow: the
/// child keeps its rest constraints, so text never re-wraps and a row never
/// re-spaces — only the painted result is transformed.
///
/// The box is pinned to the deformed box's **top-left**, because that is the
/// origin [LiquidGlassFlexDeform.childTransform] is expressed from. Any
/// other alignment would offset the content out from under the glass.
///
/// The wrappers are emitted **even at rest** (as an identity transform).
/// Swapping them in and out with the deformation would change the widget
/// tree's shape mid-gesture, and Flutter would unmount everything below —
/// including the `GestureDetector` tracking the finger, which drops the tap.
/// Only a lens with no flex at all skips them, via [restSize] being
/// empty, and that is a decision that never changes while the lens lives.
Widget liquidGlassFlexChild({
  required Widget child,
  required LiquidGlassFlexDeform deform,
  required Size restSize,
}) {
  if (restSize.isEmpty) return child;
  return OverflowBox(
    alignment: Alignment.topLeft,
    minWidth: restSize.width,
    maxWidth: restSize.width,
    minHeight: restSize.height,
    maxHeight: restSize.height,
    child: Transform(
      // No `alignment`/`origin`: the matrix is already anchored at the
      // child's own top-left, which is where it must be applied.
      transform: deform.childTransform,
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
///
/// Emitted unconditionally — at rest it is simply a `Positioned` at the rest
/// rect. See [liquidGlassFlexChild] for why the shape must not change
/// when the deformation starts.
Widget liquidGlassFlexBox({
  required Widget child,
  required LiquidGlassFlexDeform deform,
  required Size restSize,
}) {
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
/// smoothed press scalar from [LiquidGlassFlexDeform.pressAmount].
///
/// Two independent knobs, because they are two different effects.
/// [LiquidGlassFlexTuning.refractionBoost] bends harder;
/// [LiquidGlassFlexTuning.magnificationBoost] zooms the backdrop about the
/// lens centre. Only the first is on by default — magnification is not a
/// refraction depth, and raising it reads as the content behind the glass
/// sliding, i.e. a scale-up of the picture instead of the frame.
///
/// Which dial carries it depends on the configuration: the legacy `distortion`
/// when no [LiquidGlassRefractionType] is set, otherwise the type's own
/// strength via [LiquidGlassRefractionType.withEffectFactor], since a type
/// overrides the legacy field entirely.
LiquidGlassRefraction liquidGlassFlexRefraction(
  LiquidGlassRefraction refraction,
  LiquidGlassFlex spec,
  double amount,
) {
  final double t = amount.clamp(0.0, 1.0);
  final double k = spec.refractionBoost * t;
  final double m = spec.magnificationBoost * t;
  if (k <= 0 && m <= 0) return refraction;
  final LiquidGlassRefractionType? type = refraction.refractionType;
  return refraction.copyWith(
    // Legacy controls only when no type is configured; a type overrides them
    // and carries its own strength, so scale that instead.
    distortion:
        k > 0 && type == null ? refraction.distortion * (1 + k) : null,
    refractionType: k > 0 ? type?.withEffectFactor(1 + k) : null,
    // Null leaves it untouched, which is the default: magnificationBoost is 0
    // unless a caller asks for the zoom.
    magnification: m > 0 ? refraction.magnification * (1 + m) : null,
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
/// as [LiquidGlassFlexDeform.originShift] so the deformation never leaks
/// into the position bookkeeping that resolves and clamps the rest layout.
LiquidGlass liquidGlassFlexConfig(
  LiquidGlass config,
  LiquidGlassFlex spec,
  LiquidGlassFlexDeform deform,
) {
  if (deform.isRest && deform.pressAmount <= 0) return config;

  final Size rest = Size(config.geometry.width, config.geometry.height);
  final Size size = deform.sizeFrom(rest);
  final LiquidGlassRefraction refraction = liquidGlassFlexRefraction(
      config.effectiveRefraction, spec, deform.pressAmount);

  // The SHAPE is left exactly as authored. The shader evaluates it at rest
  // size and divides the domain by `u_shapeScale`, so capping the radius
  // against the deformed size here would shrink it a second time.
  return config.copyWith(
    geometry: config.geometry.copyWith(width: size.width, height: size.height),
    refraction: refraction,
    style: config.style?.copyWith(refraction: refraction),
  );
}

/// Hyperbolic tangent — the saturation curve behind [LiquidGlassFlex.maxPull].
/// Not in `dart:math`, so it is derived from `exp` here.
double _tanh(double x) {
  if (x > 20) return 1;
  if (x < -20) return -1;
  final double e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Signed elongation for one axis: `+` stretches, `-` compresses.
///
/// [u] is the saturated pull on this axis and [g] the grab point on it
/// (`0`–`1`). A pull that leaves the grabbed edge stretches the body; one that
/// drives that edge toward the middle compresses it, because the far side lags
/// either way.
///
/// How *directional* that is fades with two things, so the rule never snaps:
///
///  * how far off-centre the grab is — a grab on the exact middle has no near
///    edge to push into, so it stretches symmetrically whichever way it goes,
///  * [grip], which is already the parameter saying whether the grab point
///    matters at all.
///
/// At `grip: 0` this is exactly `stretch * u.abs()` — the behaviour before
/// compression existed — so that setting is the way back to it.
double _axisGain(
    double stretch, double u, double g, double grip, bool compressInward) {
  // Magnitude only — the original response, reproduced exactly rather than
  // approached, so `compressInward: false` is a true way back.
  if (!compressInward) return stretch * u.abs();
  final double offCentre = 2 * g - 1; // -1 at the min edge, +1 at the max
  final double directional = grip * offCentre.abs();
  if (directional <= 0) return stretch * u.abs();
  // +1 when the pull leaves the grabbed edge, -1 when it drives into it.
  final double outward = (u.sign * offCentre.sign);
  return stretch * u.abs() * _lerp(1.0, outward, directional);
}
