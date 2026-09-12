import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How a [LiquidGlassMorph] travels between shapes.
///
/// Pick a preset and stop there — they are the whole point:
///
/// ```dart
/// motion: LiquidGlassMorphMotion.fluid        // the default: a blob that leaps and drags a neck
/// motion: LiquidGlassMorphMotion.anchoredPop  // grows from its corner, no neck
/// motion: LiquidGlassMorphMotion.droplet      // born small, long neck
/// motion: LiquidGlassMorphMotion.calm         // no bounce, for sheets and cards
/// motion: LiquidGlassMorphMotion.plain        // one lens, one spring, no blending
/// ```
///
/// A morph is two blobs of one liquid, not a box being resized. The new
/// shape is born inside the old one and grows around its [anchor] while that
/// anchor travels to where it will finally sit; the old shape lingers, then
/// drains into it. The two stay joined by a neck until the new shape has
/// swallowed the old. This descriptor is the physics of that: one spring,
/// how far the leading blob runs ahead of its own size, and where it grows
/// from. The quantities that are set once and left alone live in
/// [LiquidGlassMorphAdvanced], behind [advanced].
///
/// [blended] is the exception: `false` drops the second blob and the blender
/// with it, and the morph is a single lens whose outline springs from the
/// old shape to the new — no neck, no drain, one backdrop pass. That is
/// what [plain] is; any other preset becomes the one-lens kind with
/// `copyWith(blended: false)`.
///
/// The morph's **duration** — what the content timing in [advanced] is a
/// fraction of — is the spring's own period, `2π / √stiffness`: the number
/// [LiquidGlassMorphMotion.spring] takes as `duration`, and 0.45 s for the
/// presets.
@immutable
class LiquidGlassMorphMotion {
  const LiquidGlassMorphMotion({
    this.stiffness = 195,
    this.damping = 19.5,
    this.stretch = 0.6,
    this.anchor = Alignment.center,
    this.blended = true,
    this.advanced = const LiquidGlassMorphAdvanced(),
  })  : assert(stiffness > 0),
        assert(damping >= 0),
        assert(stretch >= 0 && stretch <= 1);

  /// Spring constant, in units of 1/s². Higher arrives sooner.
  final double stiffness;

  /// Damping. Below `2·√stiffness` the outline overshoots and comes back;
  /// at or above it, it eases in and stops.
  final double damping;

  /// How far the leading blob runs ahead of its own size, `0`–`1`.
  ///
  /// Growing, the new blob's ANCHOR leaps toward where it is going while its
  /// SIZE follows on the plain spring, so it pulls a neck out of the old
  /// shape before it fills in. Shrinking the roles swap: the size collapses
  /// first and the anchor slides after it, so the surface deflates and then
  /// drains. `0` is a plain resize with no neck.
  final double stretch;

  /// The point the new shape grows around, and the point of the old shape
  /// it is born at — Apple's matched-geometry `anchor`.
  ///
  /// Together with the widget's `alignment` this sets the neck's direction.
  /// [Alignment.center] makes the blob leap from the old centre to the new
  /// one and drag a neck behind it. `null` uses the widget's own
  /// `alignment`, the corner that holds: the anchor then barely travels and
  /// the shape simply pops open from that corner, with no neck — which is
  /// how Apple's menus grow from a toolbar button.
  final Alignment? anchor;

  /// Whether the morph is two blobs joined by a `LiquidGlassBlender` — the
  /// default — or **one** lens.
  ///
  /// `false` is the one-lens morph: a single outline springs from the old
  /// shape to the new, its anchor leading its size by [stretch] the same
  /// way, with both children inside it. Nothing is born, nothing drains and
  /// there is no neck, so it costs a single backdrop pass — the right kind
  /// for a surface that changes size more than it changes place. See
  /// [plain].
  final bool blended;

  /// The knobs that are set once and forgotten.
  final LiquidGlassMorphAdvanced advanced;

  /// The morph's duration, in seconds: the spring's period, `2π / √stiffness`.
  ///
  /// This is the clock the content timing in [advanced] runs on. It is the
  /// `duration` [spring] was given, and 0.45 s for the built-in presets.
  double get duration => 2 * math.pi / math.sqrt(stiffness);

  /// The spring SwiftUI would give you for `Spring(duration:bounce:)`, so a
  /// value copied from a design spec lands here unchanged.
  ///
  /// [duration] is the perceptual duration, not a hard stop: ω = 2π/duration.
  /// [bounce] is `0` for no overshoot, `0.3` for SwiftUI's `.bouncy`, and
  /// higher for livelier. Negative values overdamp.
  factory LiquidGlassMorphMotion.spring({
    Duration duration = const Duration(milliseconds: 450),
    double bounce = 0.3,
    double stretch = 0.6,
    Alignment? anchor = Alignment.center,
    bool blended = true,
    LiquidGlassMorphAdvanced advanced = const LiquidGlassMorphAdvanced(),
  }) {
    final double seconds = math.max(duration.inMicroseconds / 1e6, 0.001);
    final double omega = 2 * math.pi / seconds;
    // SwiftUI's mapping: bounce is 1 − damping ratio.
    final double zeta = (1 - bounce).clamp(0.05, 4.0);
    return LiquidGlassMorphMotion(
      stiffness: omega * omega,
      damping: 2 * zeta * omega,
      stretch: stretch,
      anchor: anchor,
      blended: blended,
      advanced: advanced,
    );
  }

  /// Damping ratio of the plain spring: 1 is critical, below it bounces.
  double get zeta => damping / (2 * math.sqrt(stiffness));

  LiquidGlassMorphMotion copyWith({
    double? stiffness,
    double? damping,
    double? stretch,
    Alignment? anchor,
    bool clearAnchor = false,
    bool? blended,
    LiquidGlassMorphAdvanced? advanced,
  }) =>
      LiquidGlassMorphMotion(
        stiffness: stiffness ?? this.stiffness,
        damping: damping ?? this.damping,
        stretch: stretch ?? this.stretch,
        anchor: clearAnchor ? null : (anchor ?? this.anchor),
        blended: blended ?? this.blended,
        advanced: advanced ?? this.advanced,
      );

  // ── Presets ───────────────────────────────────────────────────────────
  //
  // Apple's menu spring is `.bouncy(duration: 0.4)`: Spring(duration 0.4–0.5,
  // bounce 0.3). The constants below are that spring at 0.45 s, and at 0.4 s
  // critically damped for `calm`.

  /// A menu leaping out of a toolbar button: the blob's centre leaves first,
  /// the size follows, the old shape lingers and drains after it.
  static const LiquidGlassMorphMotion fluid = LiquidGlassMorphMotion();

  /// Grows from the corner that holds, the way Apple's own menus pop open
  /// from their button. The anchor barely travels, so there is no neck: the
  /// liquid read is the bounce, the thickening, and the content
  /// materialising around the corner.
  static const LiquidGlassMorphMotion anchoredPop = LiquidGlassMorphMotion(
    stretch: 0.2,
    anchor: null,
    advanced: LiquidGlassMorphAdvanced(
      leadBounce: 0,
      followDelay: 0,
      linger: 0,
      sourceFollows: true,
      newScaleFrom: 0.80,
    ),
  );

  /// One lens, one spring: the outline goes from the old shape to the new
  /// with a little lead in its anchor and nothing else — no second blob, no
  /// neck, no drain, a single backdrop pass. The content still cross-fades
  /// on the morph's clock.
  static const LiquidGlassMorphMotion plain = LiquidGlassMorphMotion(
    stretch: 0.35,
    blended: false,
    advanced: LiquidGlassMorphAdvanced(leadBounce: 0.05),
  );

  /// A droplet: born small inside the old shape, leaps hard, drags a long
  /// neck, and fills in late.
  static const LiquidGlassMorphMotion droplet = LiquidGlassMorphMotion(
    stretch: 0.9,
    advanced: LiquidGlassMorphAdvanced(
      leadBounce: 0.15,
      followDelay: 0.09,
      seedScale: 0.55,
      linger: 0.18,
      neckRamp: 16,
    ),
  );

  /// No overshoot and a short neck: for sheets and large cards, where a
  /// wobble looks wrong.
  static const LiquidGlassMorphMotion calm = LiquidGlassMorphMotion(
    stiffness: 247,
    damping: 31.4,
    stretch: 0.25,
    advanced: LiquidGlassMorphAdvanced(leadBounce: 0),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassMorphMotion &&
          other.stiffness == stiffness &&
          other.damping == damping &&
          other.stretch == stretch &&
          other.anchor == anchor &&
          other.blended == blended &&
          other.advanced == advanced;

  @override
  int get hashCode =>
      Object.hash(stiffness, damping, stretch, anchor, blended, advanced);
}

/// The knobs of [LiquidGlassMorphMotion] that are set once and then left
/// alone — grouped so they stay out of the way without being out of reach.
///
/// Reach for them when the preset is nearly right but one thing is off:
/// the old shape hangs around too long ([linger]), the new content lands
/// too early ([contentInStart]), the neck is too fat too soon ([neckRamp]).
@immutable
class LiquidGlassMorphAdvanced {
  const LiquidGlassMorphAdvanced({
    this.leadBounce = 0.10,
    this.followDelay = 0.04,
    this.seedScale = 1.0,
    this.linger = 0.12,
    this.drainSpeed = 1.5,
    this.drainInward = 0.35,
    this.sourceFollows = false,
    this.neckRamp = 24,
    this.contentOutEnd = 0.40,
    this.contentInStart = 0.30,
    this.contentInEnd = 0.80,
    this.newScaleFrom = 0.90,
    this.oldScaleTo = 0.92,
    this.contentBlur = 8,
    this.contentFollow = 0.0,
    this.contentSlide = 0,
    this.thickenBlur = 0.35,
    this.thickenRefraction = 0.30,
  });

  // ── Travel ────────────────────────────────────────────────────────────

  /// Extra bounce for the leading pair only. A little makes the leading blob
  /// overshoot its mark and snap back — the string-pull of a drop landing.
  final double leadBounce;

  /// Seconds the following pair waits before it starts. Growing, the size
  /// holds while the anchor has already left, which lengthens the neck.
  final double followDelay;

  /// Size of the new blob at birth as a fraction of the old shape, 0.2–1.
  /// `1` is Apple's matched geometry: the new shape starts as the old frame.
  /// Smaller births a droplet inside the old shape that grows as it leaves.
  final double seedScale;

  // ── The old shape ─────────────────────────────────────────────────────

  /// Seconds the old shape holds still before it starts to drain away.
  final double linger;

  /// Stiffness multiplier of the drain. Higher empties the old shape sooner.
  final double drainSpeed;

  /// Where the old shape drains to, 0–1: `0` shrinks in place, `1` shrinks
  /// toward the new shape's centre. Some inward pull keeps its last pixels
  /// inside the new shape, so no stray rim is left at the edge.
  final double drainInward;

  /// `true` flows the old shape INTO the new one instead of draining it to
  /// nothing. Reads as one body of liquid changing shape, with less of a
  /// droplet.
  final bool sourceFollows;

  // ── Neck ──────────────────────────────────────────────────────────────

  /// Over how many px of separation the neck reaches the widget's full
  /// `smoothness`. Coincident blobs get none — a union of two identical
  /// outlines would otherwise sit a quarter of the radius outside the true
  /// one — and parted blobs get all of it.
  final double neckRamp;

  // ── Content ───────────────────────────────────────────────────────────
  //
  // All three are fractions of the MORPH's duration — the spring's period,
  // `LiquidGlassMorphMotion.duration` — so "the new child shows at 0.3"
  // means 0.3 of the way through the glass motion, whatever the spring.

  /// Fraction of the morph's duration by which the old child is gone.
  final double contentOutEnd;

  /// Fraction of the morph's duration at which the new child starts to
  /// appear — faint, blurred and scaled down, inside the glass wherever
  /// the glass has reached by then.
  final double contentInStart;

  /// Fraction of the morph's duration by which the new child is fully
  /// there: opaque, sharp and at scale. Below 1 it lands before the glass
  /// settles, which is what keeps the blur off the end of the morph.
  final double contentInEnd;

  /// The new child's scale when it starts to appear; it settles at 1.
  final double newScaleFrom;

  /// The old child's scale as it vanishes. Below 1 it recedes; above 1 it
  /// bursts.
  final double oldScaleTo;

  /// Blur, in px, at the faintest point of each child's fade.
  final double contentBlur;

  /// `0` pins content where it finally sits and lets the glass travel over
  /// it; `1` rides it along with the blob that carries it.
  final double contentFollow;

  /// Px the new child slides in from, along the direction of travel.
  final double contentSlide;

  // ── Material ──────────────────────────────────────────────────────────

  /// How much thicker the blur reads at the large size, as a fraction of the
  /// style's own sigma. Apple: "a thicker, more substantial material".
  final double thickenBlur;

  /// Same, for the refraction band and depth.
  final double thickenRefraction;

  LiquidGlassMorphAdvanced copyWith({
    double? leadBounce,
    double? followDelay,
    double? seedScale,
    double? linger,
    double? drainSpeed,
    double? drainInward,
    bool? sourceFollows,
    double? neckRamp,
    double? contentOutEnd,
    double? contentInStart,
    double? contentInEnd,
    double? newScaleFrom,
    double? oldScaleTo,
    double? contentBlur,
    double? contentFollow,
    double? contentSlide,
    double? thickenBlur,
    double? thickenRefraction,
  }) =>
      LiquidGlassMorphAdvanced(
        leadBounce: leadBounce ?? this.leadBounce,
        followDelay: followDelay ?? this.followDelay,
        seedScale: seedScale ?? this.seedScale,
        linger: linger ?? this.linger,
        drainSpeed: drainSpeed ?? this.drainSpeed,
        drainInward: drainInward ?? this.drainInward,
        sourceFollows: sourceFollows ?? this.sourceFollows,
        neckRamp: neckRamp ?? this.neckRamp,
        contentOutEnd: contentOutEnd ?? this.contentOutEnd,
        contentInStart: contentInStart ?? this.contentInStart,
        contentInEnd: contentInEnd ?? this.contentInEnd,
        newScaleFrom: newScaleFrom ?? this.newScaleFrom,
        oldScaleTo: oldScaleTo ?? this.oldScaleTo,
        contentBlur: contentBlur ?? this.contentBlur,
        contentFollow: contentFollow ?? this.contentFollow,
        contentSlide: contentSlide ?? this.contentSlide,
        thickenBlur: thickenBlur ?? this.thickenBlur,
        thickenRefraction: thickenRefraction ?? this.thickenRefraction,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassMorphAdvanced &&
          other.leadBounce == leadBounce &&
          other.followDelay == followDelay &&
          other.seedScale == seedScale &&
          other.linger == linger &&
          other.drainSpeed == drainSpeed &&
          other.drainInward == drainInward &&
          other.sourceFollows == sourceFollows &&
          other.neckRamp == neckRamp &&
          other.contentOutEnd == contentOutEnd &&
          other.contentInStart == contentInStart &&
          other.contentInEnd == contentInEnd &&
          other.newScaleFrom == newScaleFrom &&
          other.oldScaleTo == oldScaleTo &&
          other.contentBlur == contentBlur &&
          other.contentFollow == contentFollow &&
          other.contentSlide == contentSlide &&
          other.thickenBlur == thickenBlur &&
          other.thickenRefraction == thickenRefraction;

  @override
  int get hashCode => Object.hash(
        leadBounce,
        followDelay,
        seedScale,
        linger,
        drainSpeed,
        drainInward,
        sourceFollows,
        neckRamp,
        contentOutEnd,
        contentInStart,
        contentInEnd,
        newScaleFrom,
        oldScaleTo,
        contentBlur,
        contentFollow,
        contentSlide,
        thickenBlur,
        thickenRefraction,
      );
}
