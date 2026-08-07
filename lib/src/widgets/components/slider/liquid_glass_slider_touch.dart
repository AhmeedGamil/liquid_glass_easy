import 'dart:math' as math;

import '../../utils/liquid_glass_jelly_spring.dart' show liquidGlassSpringStep;

/// **Experimental.** A second motion model for the glass slider thumb,
/// sitting beside the shipped jelly rather than replacing it: supply a
/// [LiquidGlassSliderTouch] to `LiquidGlassSlider.touch` and this drives
/// the thumb instead. Leave it null and nothing changes.
///
/// ## What it is
///
/// The jelly measures **speed**: drag fast, deform a lot. This measures
/// **distance** — how far your finger has got away from the handle — and
/// that difference is the whole point.
///
/// The handle does not sit exactly under your finger. It is towed toward
/// it by a spring ([followStiffness] / [followDamping]), so the faster
/// you drag the further it trails behind, and the gap between the two
/// opens up. That gap is what stretches the pill: it reaches toward your
/// finger, elongating along the track by as much as the gap is wide.
///
/// The squash is speed of a different kind: not how far the gap is, but
/// how fast it is **closing** ([squashRate]). Reverse, stop dead, or let
/// the handle land after a release and the gap collapses in a beat —
/// that collapse is what drives the pill under its rest width while
/// [recoil] hands the difference back as height. It cannot come from
/// distance alone: a shrinking gap only ever says "stretched less", and
/// by the time it points the other way the moment has passed. The
/// closing speed is instantaneous, so the squash is an event of its own,
/// landing exactly on the turn, the stop, and the touchdown.
///
/// The gap is also why the ends behave. Run the handle into 0 or 1 and it
/// stops, but your finger does not: the gap keeps widening and the pill
/// stretches after it, anchored at the end of the track. Unlike the lag
/// inside the track — bounded by the tow spring — the overrun grows with
/// your finger without limit, so it is fed through a rubber band
/// ([overrunGive]) first: diminishing returns, the iOS resistance, and
/// the ends peak near what a fast drag reaches instead of above it. Let
/// go and it snaps back.
///
/// Where you grabbed still matters. Pulling out past the side you are
/// holding stretches; pushing back into it compresses instead. [grip]
/// says how much of that decision belongs to the grab point, and it fades
/// out for a grab near the centre, which has no side to pull away from.
///
/// A press spring runs alongside all of it, swelling the pill while it is
/// held and letting it settle after — so the grab and the drop each land
/// with a little give of their own.
class LiquidGlassSliderTouch {
  /// Pixels of finger-to-handle gap at which the stretch saturates.
  /// Smaller → the pill reaches its full stretch sooner.
  final double maxPull;

  /// Rubber-band resistance of the overrun past a track end, as a
  /// multiple of [maxPull]: the overrun is compressed with diminishing
  /// returns and can never contribute more than `maxPull × overrunGive`
  /// effective pixels of gap, however far the finger runs off the track.
  /// Smaller → stiffer band, less stretch available at the ends. At
  /// `1.5` the ends asymptote to about nine tenths of the full stretch —
  /// near a fast drag's peak rather than past it.
  final double overrunGive;

  /// Pixels gained along the track at full outward load — the peak of
  /// the stretch.
  final double stretch;

  /// Pixels lost along the track at full inward load — the peak of the
  /// squash. Kept separate from [stretch] because a pill that squashes as
  /// far as it stretches reads as rubber rather than glass.
  final double squash;

  /// Cross-axis amplification of the squash. The width a compression
  /// takes is returned as height through [squeeze], scaled by this — the
  /// momentum-sided swell that makes the recoil READ as a squash (width
  /// down, height up) instead of the pill merely shrinking. `1` is the
  /// plain area exchange; the shipped jelly runs its equivalent at `3`.
  final double recoil;

  /// Gap-closing speed, in pixels/second, at which the squash saturates.
  /// The squash is driven by how fast the finger-to-handle gap collapses
  /// — a reversal, a dead stop, the handle landing after a release — so
  /// this is its sensitivity: lower → gentler closes already squash
  /// hard. A brisk reversal closes the gap at roughly 400–600 px/s.
  final double squashRate;

  /// Cross-axis give-back, `0..1`. `1` conserves area exactly: whatever
  /// the pill gains along the track it loses in thickness, and vice
  /// versa. `0` leaves the thickness alone.
  final double squeeze;

  /// How much the **grab point** decides stretch-versus-squash, `0..1`.
  ///
  /// `0` ignores where you grabbed: any gap stretches. `1` hands the
  /// decision entirely to the grab — dragging **away from the pill's
  /// centre** stretches, dragging **toward it** squashes, for as long as
  /// the drag holds that direction. The handoff is smoothstepped over
  /// where the finger landed: clearly on a side → the rule outright,
  /// near the centre → the plain gap stretch, no diluted middle.
  final double grip;

  /// How far the elongation **leads toward the finger**, `0..1`.
  ///
  /// `0` grows the pill symmetrically about its centre — a box getting
  /// bigger, not something being pulled. `1` puts the whole gain on the
  /// edge facing your finger, so the pill reaches for it and the far edge
  /// stays put.
  final double lean;

  /// Signed fraction of its own size the pill swells to while held.
  /// `0` disables the press/release swell.
  final double holdScale;

  /// Stiffness of the spring towing the handle toward your finger.
  /// Higher → the handle sits closer to the finger and the gap — and so
  /// the stretch — is smaller. This is the knob that trades tracking
  /// accuracy for the effect.
  final double followStiffness;

  /// Damping of the tow spring. At/above `2·√followStiffness` the handle
  /// eases into place; below it, it overshoots and settles.
  final double followDamping;

  /// Stiffness of the stretch/squash spring.
  final double stiffness;

  /// Damping of the stretch/squash spring **while held**.
  final double damping;

  /// Damping of the stretch/squash spring **after release**. Lower than
  /// [damping] on purpose — the release is where the wobble belongs.
  final double releaseDamping;

  /// Stiffness of the press swell spring.
  final double pressStiffness;

  /// Damping of the press swell spring. Below critical
  /// (`2·√pressStiffness`) so grabbing and dropping both overshoot
  /// slightly instead of easing flatly into place.
  final double pressDamping;

  const LiquidGlassSliderTouch({
    this.maxPull = 44,
    this.overrunGive = 0.45,
    this.stretch = 14,
    this.squash = 18,
    this.recoil = 1.8,
    this.squashRate = 260,
    this.squeeze = 0.7,
    this.grip = 1.0,
    this.lean = 0.8,
    this.holdScale = 0.06,
    this.followStiffness = 620,
    this.followDamping = 40,
    this.stiffness = 300,
    this.damping = 16,
    this.releaseDamping = 11,
    this.pressStiffness = 420,
    this.pressDamping = 26,
  });

  LiquidGlassSliderTouch copyWith({
    double? maxPull,
    double? overrunGive,
    double? stretch,
    double? squash,
    double? recoil,
    double? squashRate,
    double? squeeze,
    double? grip,
    double? lean,
    double? holdScale,
    double? followStiffness,
    double? followDamping,
    double? stiffness,
    double? damping,
    double? releaseDamping,
    double? pressStiffness,
    double? pressDamping,
  }) {
    return LiquidGlassSliderTouch(
      maxPull: maxPull ?? this.maxPull,
      overrunGive: overrunGive ?? this.overrunGive,
      stretch: stretch ?? this.stretch,
      squash: squash ?? this.squash,
      recoil: recoil ?? this.recoil,
      squashRate: squashRate ?? this.squashRate,
      squeeze: squeeze ?? this.squeeze,
      grip: grip ?? this.grip,
      lean: lean ?? this.lean,
      holdScale: holdScale ?? this.holdScale,
      followStiffness: followStiffness ?? this.followStiffness,
      followDamping: followDamping ?? this.followDamping,
      stiffness: stiffness ?? this.stiffness,
      damping: damping ?? this.damping,
      releaseDamping: releaseDamping ?? this.releaseDamping,
      pressStiffness: pressStiffness ?? this.pressStiffness,
      pressDamping: pressDamping ?? this.pressDamping,
    );
  }
}

/// One frame of [LiquidGlassSliderTouch] deformation, in logical pixels
/// added to the thumb's rest size. All three may be negative.
class LiquidGlassSliderTouchDeform {
  /// Added along the track axis (the pill's width).
  final double along;

  /// Added across it (the pill's height).
  final double cross;

  /// Horizontal shift of the pill's centre, in logical pixels.
  ///
  /// This is what turns a width change into a stretch. The elongation is
  /// split unevenly between the two ends — most of it on the edge facing
  /// your finger — and moving the centre by half that difference is the
  /// same thing as moving the two edges by different amounts, for free.
  final double bias;

  const LiquidGlassSliderTouchDeform({
    this.along = 0,
    this.cross = 0,
    this.bias = 0,
  });

  static const LiquidGlassSliderTouchDeform none =
      LiquidGlassSliderTouchDeform();

  bool get isNone => along == 0 && cross == 0 && bias == 0;
}

/// Runs the [LiquidGlassSliderTouch] simulation.
///
/// Driven like the shipped jelly — [start] on grab, [pump] on every value
/// change, [release] on let-go, [tick] once per frame — with two
/// additions the model needs: [pump] wants the **unclamped** value under
/// the finger (so running off the end still opens a gap), and the host
/// draws the handle at [renderValue] rather than at the slider's value.
class LiquidGlassSliderTouchDriver {
  LiquidGlassSliderTouchDriver({this.spec = const LiquidGlassSliderTouch()});

  /// Live tuning. Reassign freely; the next [tick] picks it up.
  LiquidGlassSliderTouch spec;

  /// Track length in logical pixels — how a gap in value units becomes a
  /// gap in pixels. Kept current by the host each build.
  double travel = 1;

  /// Signed stretch/squash spring — positive stretches, negative squashes.
  double _deform = 0;
  double _deformVel = 0;

  /// Press swell spring, `0..1`.
  double _press = 0;
  double _pressVel = 0;

  /// The handle's drawn position, towed toward [_target]. This is the lag
  /// that opens the gap; without it the handle would sit exactly under
  /// the finger and there would be nothing to stretch.
  double _render = 0;
  double _renderVel = 0;

  /// The **unclamped** value under the finger. Past the ends of the track
  /// this keeps going while [_render] cannot, which is what makes the
  /// pill stretch against the end instead of simply stopping.
  double _target = 0;

  /// Where the finger landed on the handle: `-1` at its left edge, `0`
  /// dead centre, `+1` at its right edge.
  double _grab = 0;

  /// Smoothed direction of the gap, `-1..1` — which way the pill reaches.
  double _direction = 0;

  /// The gap's magnitude last tick and its smoothed closing speed in
  /// px/s — the squash drive's signal.
  double _prevGapAbs = 0;
  double _approach = 0;

  bool _down = false;

  /// Where the host should draw the handle: the towed position, held
  /// inside the track.
  double get renderValue => _render.clamp(0.0, 1.0).toDouble();

  /// Whether the deformation has decayed past its violent phase — the
  /// host's cue that the glass may start morphing back to the rest pill
  /// (the tail of the wobble is gentle enough to finish under it).
  bool get isCalm => _deform.abs() < 0.3 && _deformVel.abs() < 2.5;

  /// The current deformation. Exactly zero at rest.
  LiquidGlassSliderTouchDeform deformFor({
    required double thumbWidth,
    required double thumbHeight,
  }) {
    final s = spec;
    // Stretch and squash get their own magnitudes, so the spring's own
    // overshoot past zero reads as the other half of the gesture rather
    // than as a mirrored copy of it.
    final double elongation =
        _deform >= 0 ? s.stretch * _deform : s.squash * _deform;
    double along = elongation;

    // Give-back: what the pill gains along the track it loses in
    // thickness. Denominator is the deformed width, so the exchange stays
    // sane as the pill approaches its floor. A compression is amplified
    // by [recoil]: the extra height is what makes the squash read as a
    // squash — width down, height up — not the pill merely shrinking.
    final double denom = math.max(thumbWidth + along, thumbWidth * 0.25);
    final double crossGain = elongation < 0 ? s.recoil : 1.0;
    double cross = -s.squeeze * thumbHeight * along / denom * crossGain;

    // The press swells both axes together — a plain scale of its own
    // size, so it reads as the pill inflating under the finger rather
    // than deforming.
    if (s.holdScale != 0 && _press != 0) {
      along += s.holdScale * thumbWidth * _press;
      cross += s.holdScale * thumbHeight * _press;
    }

    // Floors: never let the pill collapse through itself. The cross
    // ceiling bounds the recoil swell to the host's vertical budget.
    along = math.max(along, -thumbWidth * 0.45);
    cross = math.max(cross, -thumbHeight * 0.4);
    cross = math.min(cross, thumbHeight * 0.5);

    // The lean. Only the elongation leads — the press swell is a plain
    // inflation with no direction. Half the difference between the two
    // ends IS the centre shift, so the reach costs no extra transform.
    final double bias = 0.5 * elongation * s.lean * _direction;

    return LiquidGlassSliderTouchDeform(
      along: along,
      cross: cross,
      bias: bias,
    );
  }

  /// Grab.
  ///
  /// [value] is the slider's value at the moment of the grab — the handle
  /// starts drawn exactly there, with no gap. [grab] is where on the
  /// handle the finger landed, normalised `-1..1` about its own centre.
  void start(double value, {double grab = 0}) {
    _down = true;
    _target = value;
    _render = value;
    _renderVel = 0;
    _grab = grab.clamp(-1.0, 1.0).toDouble();
    _direction = 0;
    _prevGapAbs = 0;
    _approach = 0;
  }

  /// The unclamped value under the finger. Values outside `0..1` are
  /// meaningful and wanted: they are the overrun at the track's ends.
  void pump(double rawValue) => _target = rawValue;

  /// Hard-positions the handle at [value], no glide. For programmatic
  /// value changes while idle: with the ticker stopped nothing else
  /// would ever move [renderValue], so the host calls this from build
  /// when no gesture or settle is in flight. A no-op mid-gesture.
  void syncTo(double value) {
    if (_down) return;
    _target = value;
    _render = value;
    _renderVel = 0;
    // The gap is zero by construction now; forget the old one, or the
    // next tick would read the jump as a collapse and squash.
    _prevGapAbs = 0;
    _approach = 0;
  }

  /// Let go. The handle finishes its travel and the springs settle.
  void release() {
    _down = false;
    // Drop the overrun: there is no finger holding it out past the end
    // any more, so the handle's target is a real position again.
    _target = _target.clamp(0.0, 1.0).toDouble();
  }

  /// Advances one frame. Returns `true` once everything has come to rest
  /// and the host can stop its ticker.
  bool tick(double dt) {
    if (dt <= 0) return false;
    final s = spec;

    // Tow the handle toward the finger. Its target is clamped — the
    // handle stays in the track — while the gap below is measured against
    // the unclamped finger, so overrunning an end still stretches.
    final (nextRender, nextRenderVel) = liquidGlassSpringStep(
      x: _render,
      vel: _renderVel,
      target: _target.clamp(0.0, 1.0).toDouble(),
      dt: dt,
      stiffness: s.followStiffness,
      damping: s.followDamping,
    );
    _render = nextRender;
    _renderVel = nextRenderVel;

    // The gap — computed whether or not the finger is down: after a
    // release the handle still glides, and the collapse of THAT gap is
    // what lands the touchdown squash. Split at the track edge: the lag
    // inside the track is bounded by the tow spring, but the overrun
    // past an end grows with the finger without limit, so it goes
    // through a rubber band first (diminishing returns, capped at
    // maxPull × overrunGive effective pixels) — or any decent pull off
    // an end would out-stretch the drag itself.
    final double clampedTarget = _target.clamp(0.0, 1.0).toDouble();
    final double lagPx = (clampedTarget - renderValue) * travel;
    final double overPx = (_target - clampedTarget) * travel;
    final double overCap = s.maxPull * s.overrunGive;
    final double softOverPx =
        overCap > 0 ? overPx / (1 + overPx.abs() / overCap) : 0.0;
    final double gap = lagPx + softOverPx;
    final double u = s.maxPull > 0 ? _tanh(gap / s.maxPull) : 0.0;

    // Approach: how fast the gap is CLOSING, in px/s, lightly smoothed.
    // This is the squash's whole signal. A distance is always too late —
    // a shrinking gap only ever reads "stretched less" — but the closing
    // speed spikes the instant of a reversal, a dead stop, or a landing,
    // which is exactly where the squash belongs.
    final double gapAbs = gap.abs();
    final double rawApproach = (_prevGapAbs - gapAbs) / dt;
    _prevGapAbs = gapAbs;
    // Fast rise, slow fall: the collapse itself is over in a few frames,
    // far quicker than the deform spring can answer — holding its tail
    // ~100 ms is what gives the squash time to actually develop.
    final double smoothTau = rawApproach > _approach ? 0.02 : 0.10;
    _approach += (rawApproach - _approach) * (dt / smoothTau).clamp(0.0, 1.0);
    final double squashU = _approach > 0 && s.squashRate > 0
        ? _tanh(_approach / s.squashRate)
        : 0.0;

    // The pill reaches toward the finger, so the lean follows the gap,
    // not the travel. Smoothed so crossing over hands the lead from one
    // end to the other instead of flipping it.
    if (u != 0) {
      final double a = (dt / 0.12).clamp(0.0, 1.0);
      _direction += (u.sign - _direction) * a;
    }

    // Stretch from distance, squash from closing speed — weighted so a
    // hard close buries whatever stretch is left of the old leg.
    double target = (u.abs() - 1.6 * squashU).clamp(-1.0, 1.0).toDouble();

    if (_down) {
      // Which way the pull points relative to the side being held. `+1` →
      // away from the pill's centre → stretch. `-1` → toward it → squash.
      final double outward =
          u == 0 || _grab == 0 ? 1.0 : (u.sign * _grab.sign);

      // THE drag rule: grab a SIDE of the pill and the deformation's
      // sign is the drag direction against the centre — away stretches,
      // toward it squashes, for as long as you drag that way. The
      // smoothstep keeps it decisive: a grab clearly on a side obeys the
      // rule outright, a centre grab keeps the plain gap stretch, and
      // nothing lingers in a diluted middle where the two cancel to
      // an unreadable nothing.
      final double t = ((_grab.abs() - 0.15) / 0.4).clamp(0.0, 1.0);
      final double sideness = t * t * (3 - 2 * t);
      final double authority = (s.grip * sideness).clamp(0.0, 1.0);
      final double grabTarget = u.abs() * outward;
      target = (target + (grabTarget - target) * authority)
          .clamp(-1.0, 1.0)
          .toDouble();
    }

    // Asymmetric damping: firm while the finger is on it, looser after,
    // so the release is where the give shows.
    final (nextDeform, nextDeformVel) = liquidGlassSpringStep(
      x: _deform,
      vel: _deformVel,
      target: target,
      dt: dt,
      stiffness: s.stiffness,
      damping: _down ? s.damping : s.releaseDamping,
    );
    _deform = nextDeform;
    _deformVel = nextDeformVel;

    final (nextPress, nextPressVel) = liquidGlassSpringStep(
      x: _press,
      vel: _pressVel,
      target: _down ? 1.0 : 0.0,
      dt: dt,
      stiffness: s.pressStiffness,
      damping: s.pressDamping,
    );
    _press = nextPress;
    _pressVel = nextPressVel;

    if (_down) return false;
    final bool settled = _deform.abs() < 0.001 &&
        _deformVel.abs() < 0.01 &&
        _press.abs() < 0.001 &&
        _pressVel.abs() < 0.01 &&
        (_render - _target).abs() < 0.0002 &&
        _renderVel.abs() < 0.002;
    if (settled) {
      // Snap to exact zero so the thumb's rest geometry is bit-identical
      // to the untouched path.
      _deform = 0;
      _deformVel = 0;
      _press = 0;
      _pressVel = 0;
      _render = _target;
      _renderVel = 0;
      _direction = 0;
      _prevGapAbs = 0;
      _approach = 0;
    }
    return settled;
  }

  /// `tanh`, hand-rolled — `dart:math` has no hyperbolic functions.
  static double _tanh(double x) {
    if (x > 10) return 1;
    if (x < -10) return -1;
    final double e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
}
