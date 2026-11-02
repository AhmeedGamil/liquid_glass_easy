import 'dart:math' as math;

/// The glass pill's **events, timing and travel**. Lengths are in points of
/// a bar [barHeight] tall (a host scales by its own bar height over it),
/// durations in seconds; springs are given as a duration (`2π / ω`) and a
/// bounce (`1 − ζ`: `0` settles without overshooting, higher overshoots
/// more).
///
/// How it moves:
///
///  * A press lifts the pill **at once** — no hold — and sends it to the
///    pressed tab on the press itself.
///  * A finger that moves past [dragThreshold] scrubs: the pill keeps the
///    gap from where it was heading to the finger at that moment and moves
///    with the finger from there, on the drag spring ([dragDuration],
///    [dragBounce]), kept
///    within the first and last tab. Letting go selects the tab nearest
///    where the finger is pulling the pill (a tie keeps the current tab),
///    and the pill travels there from the position and velocity the scrub
///    left it with.
///  * The travel is one spring for every distance ([travelDuration],
///    [travelBounce]): at the target after ~0.33 s, a 0.6 % overshoot at
///    ~0.38 s, ended once under [settleDistance] remains past the overshoot.
///  * The lift rises on a critically damped [liftDuration] spring, holds
///    for as long as the finger is down and the pill is travelling, and is
///    released once the pill is within [dropDistance] of its tab, falling on
///    the same spring. The glass fades into the flat pill as the grey
///    platter returns, a critically damped [glassFadeDuration] spring.
///  * Every release ends in a small two-beat **wobble** of the pill's shape
///    (width +1.6 % then −1.5 %, height −2 % then +2.2 %, over ~0.6 s). It
///    plays at the landing, on [landingWobbleStrength], in place of the
///    acceleration squash's braking — which fades out over
///    [landingSquashFadeDuration].
class LiquidGlassTabPillBehavior {
  const LiquidGlassTabPillBehavior({
    this.barHeight = 62,
    this.liftDuration = 0.25,
    this.liftBounce = 0.0,
    this.dropDistance = 3.5,
    this.travelDuration = 0.4,
    this.travelBounce = 0.15,
    this.glassFadeDuration = 0.4,
    this.dragDuration = 0.25,
    this.dragBounce = 0.097,
    this.dragThreshold = 10,
    this.landingWobbleStrength = 1.939,
    this.landingWobbleDelay = 0.0,
    this.landingSquashFadeDuration = 0.138,
  });

  /// The bar height the points below are relative to: a host scales every
  /// length by its own bar height over this.
  final double barHeight;

  /// The lift spring, rise and fall alike: its duration and bounce (`0`
  /// rises without overshooting).
  final double liftDuration;
  final double liftBounce;

  /// Remaining travel below which the lift drops.
  final double dropDistance;

  /// The travel spring: its duration and bounce.
  final double travelDuration;
  final double travelBounce;

  /// How long the glass takes to fade into the flat pill after the lift
  /// drops.
  final double glassFadeDuration;

  /// The drag spring (the pill after the finger): its duration and bounce.
  final double dragDuration;
  final double dragBounce;

  /// A finger that moves this far from its press is scrubbing.
  final double dragThreshold;

  /// The landing: once the lift is released the acceleration squash fades
  /// out over [landingSquashFadeDuration] seconds and the release wobble
  /// plays in its place on [landingWobbleStrength], [landingWobbleDelay]
  /// seconds after the release. `1` plays the wobble at its table size
  /// (about ±2 %), `0` turns it off.
  final double landingWobbleStrength;
  final double landingWobbleDelay;
  final double landingSquashFadeDuration;

  /// Sample rate of the wobble table.
  static const double sampleHz = 60;

  /// The rising lift snaps to 1 once past this.
  static const double liftSnap = 0.975;

  /// Past its overshoot the travel ends once less than this remains.
  static const double settleDistance = 0.195;

  static double _omega(double duration) =>
      2 * math.pi / duration.clamp(0.02, 10);

  /// A bounce as the damping ratio ζ the springs step with.
  static double _zeta(double bounce) => (1 - bounce).clamp(0.05, 2.0);

  double get travelOmega => _omega(travelDuration);
  double get travelZeta => _zeta(travelBounce);
  double get travelStiffness => travelOmega * travelOmega;
  double get travelDamping => 2 * travelZeta * travelOmega;

  double get liftOmega => _omega(liftDuration);
  double get liftStiffness => liftOmega * liftOmega;
  double get liftDamping => 2 * _zeta(liftBounce) * liftOmega;

  double get platterOmega => _omega(glassFadeDuration);
  double get platterStiffness => platterOmega * platterOmega;
  double get platterDamping => 2 * platterOmega;

  double get dragOmega => _omega(dragDuration);
  double get dragStiffness => dragOmega * dragOmega;
  double get dragDamping => 2 * _zeta(dragBounce) * dragOmega;

  /// How long the landing wobble runs.
  static double get wobbleSeconds => (kWobbleX.length - 1) / sampleHz;

  /// Linear interpolation into a 60 Hz table, held at its ends.
  static double sample(List<double> table, double seconds) {
    if (seconds <= 0) return table.first;
    final double f = seconds * sampleHz;
    final int i = f.floor();
    if (i >= table.length - 1) return table.last;
    final double t = f - i;
    return table[i] + (table[i + 1] - table[i]) * t;
  }

  /// The landing wobble [seconds] after the lift's release: the release
  /// wobble on [landingWobbleStrength]; none outside it.
  LiquidGlassTabDeform landingWobble(double seconds) {
    if (seconds < 0 || seconds > wobbleSeconds || landingWobbleStrength == 0) {
      return LiquidGlassTabDeform.none;
    }
    return LiquidGlassTabDeform(
      scaleX: landingWobbleStrength * sample(kWobbleX, seconds),
      scaleY: landingWobbleStrength * sample(kWobbleY, seconds),
      lead: landingWobbleStrength * sample(kWobbleTx, seconds),
    );
  }

  LiquidGlassTabPillBehavior copyWith({
    double? barHeight,
    double? liftDuration,
    double? liftBounce,
    double? dropDistance,
    double? travelDuration,
    double? travelBounce,
    double? glassFadeDuration,
    double? dragDuration,
    double? dragBounce,
    double? dragThreshold,
    double? landingWobbleStrength,
    double? landingWobbleDelay,
    double? landingSquashFadeDuration,
  }) {
    return LiquidGlassTabPillBehavior(
      barHeight: barHeight ?? this.barHeight,
      liftDuration: liftDuration ?? this.liftDuration,
      liftBounce: liftBounce ?? this.liftBounce,
      dropDistance: dropDistance ?? this.dropDistance,
      travelDuration: travelDuration ?? this.travelDuration,
      travelBounce: travelBounce ?? this.travelBounce,
      glassFadeDuration: glassFadeDuration ?? this.glassFadeDuration,
      dragDuration: dragDuration ?? this.dragDuration,
      dragBounce: dragBounce ?? this.dragBounce,
      dragThreshold: dragThreshold ?? this.dragThreshold,
      landingWobbleStrength:
          landingWobbleStrength ?? this.landingWobbleStrength,
      landingWobbleDelay: landingWobbleDelay ?? this.landingWobbleDelay,
      landingSquashFadeDuration:
          landingSquashFadeDuration ?? this.landingSquashFadeDuration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassTabPillBehavior &&
          other.barHeight == barHeight &&
          other.liftDuration == liftDuration &&
          other.liftBounce == liftBounce &&
          other.dropDistance == dropDistance &&
          other.travelDuration == travelDuration &&
          other.travelBounce == travelBounce &&
          other.glassFadeDuration == glassFadeDuration &&
          other.dragDuration == dragDuration &&
          other.dragBounce == dragBounce &&
          other.dragThreshold == dragThreshold &&
          other.landingWobbleStrength == landingWobbleStrength &&
          other.landingWobbleDelay == landingWobbleDelay &&
          other.landingSquashFadeDuration == landingSquashFadeDuration;

  @override
  int get hashCode => Object.hashAll([
        barHeight,
        liftDuration,
        liftBounce,
        dropDistance,
        travelDuration,
        travelBounce,
        glassFadeDuration,
        dragDuration,
        dragBounce,
        dragThreshold,
        landingWobbleStrength,
        landingWobbleDelay,
        landingSquashFadeDuration,
      ]);
}

/// One frame of pill deformation: [scaleX] and [scaleY] are the scale
/// minus one about the pill's centre, [lead] the centre's offset along x
/// in points. Two independent channels — the wobble's height moves about
/// 1.4 times as far as its width, so this is not a volume-preserving pair.
class LiquidGlassTabDeform {
  const LiquidGlassTabDeform({
    required this.scaleX,
    required this.scaleY,
    required this.lead,
  });

  static const LiquidGlassTabDeform none =
      LiquidGlassTabDeform(scaleX: 0, scaleY: 0, lead: 0);

  final double scaleX;
  final double scaleY;
  final double lead;
}

// ── The release wobble, one sample per 1/60 s from its start ──
// (the lens's scaleX − 1, scaleY − 1 and centre offset in points).

const List<double> kWobbleX = <double>[
  0.0,
  0.0,
  0.0,
  0.00361,
  0.01156,
  0.01577,
  0.01579,
  0.01397,
  0.01188,
  0.0098,
  0.00795,
  0.0058,
  0.00341,
  0.00063,
  -0.00225,
  -0.00522,
  -0.00795,
  -0.01039,
  -0.01244,
  -0.01396,
  -0.01503,
  -0.01553,
  -0.01552,
  -0.01517,
  -0.01453,
  -0.01358,
  -0.01263,
  -0.01144,
  -0.01016,
  -0.00876,
  -0.00743,
  -0.00614,
  -0.00479,
  -0.00367,
  -0.00264,
  -0.00183,
  -0.00113,
  -0.00005
];

const List<double> kWobbleY = <double>[
  0.0,
  0.0,
  0.0,
  -0.00473,
  -0.01511,
  -0.0206,
  -0.02037,
  -0.01772,
  -0.01475,
  -0.0119,
  -0.00938,
  -0.00653,
  -0.00337,
  0.0003,
  0.00424,
  0.00825,
  0.01199,
  0.01525,
  0.01793,
  0.02006,
  0.0214,
  0.02202,
  0.02193,
  0.0214,
  0.02049,
  0.01915,
  0.01775,
  0.01604,
  0.01418,
  0.01233,
  0.01044,
  0.00863,
  0.00672,
  0.0051,
  0.00375,
  0.00255,
  0.00164,
  0.00007
];

const List<double> kWobbleTx = <double>[
  0.0,
  0.0,
  0.0,
  0.1684,
  0.5498,
  0.754,
  0.8391,
  0.8995,
  0.9182,
  0.8944,
  0.8411,
  0.7892,
  0.7481,
  0.7238,
  0.72,
  0.7283,
  0.7467,
  0.7583,
  0.7764,
  0.78,
  0.7717,
  0.7533,
  0.7252,
  0.6868,
  0.6394,
  0.5891,
  0.5339,
  0.4642,
  0.3859,
  0.3211,
  0.2607,
  0.201,
  0.1529,
  0.1125,
  0.0813,
  0.0608,
  0.0408,
  0.0017
];
