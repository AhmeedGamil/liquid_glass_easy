import 'dart:ui' show Offset;

/// The acceleration→deformation physics of a moving
/// glass body, extracted from the stretch slider's thumb into a
/// component-agnostic class.
///
/// Feed it the mover's position once per frame — a slider thumb's
/// centre, a nav-bar pill's centre, anything that travels — and read
/// back a signed **scale deviation**:
///
///     scaleX = 1 + deviation      scaleY = 1 − deviation
///
/// Accelerating into a drag stretches the body wide and flat; braking
/// (or arriving from a glide) squashes it narrow and tall; constant
/// speed leaves it undeformed — force, not speed, is what deforms it.
///
/// This class is physics only, the same layering as
/// `LiquidGlassJellySpring`: the caller owns the `Ticker`, calls
/// [start] when the effect goes live (the thumb lifts, the pill starts
/// moving), [track] every frame with the current position, and [stop]
/// the moment the effect ends (an instant reset, masked by whatever
/// animation runs over it). How the deviation maps to pixels is each
/// component's business.
///
/// Positions are 2-D on purpose: the two axes combine as `avgX − avgY`,
/// since a vertical acceleration deforms the opposite way (Y-stretch is
/// a *negative* deviation). A horizontal mover passes `Offset(x, 0)`
/// and gets the collapsed one-axis behaviour.
class LiquidGlassLensMotionSpec {
  /// Time window for calculating average acceleration, in seconds.
  final double window;

  /// Coefficient converting acceleration (px/s²) to scale deviation.
  final double coefficient;

  /// Maximum |deviation| (clamped for visual stability).
  final double maxDeviation;

  /// Seconds for the deviation to ease toward the acceleration's
  /// answer, instead of snapping to it every frame.
  /// `0` restores the frame-locked response; higher = slower, dreamier.
  final double responseTau;

  /// The stretch slider's tuned values (a coefficient of 0.00005
  /// with no response ease is the undamped equivalent).
  const LiquidGlassLensMotionSpec({
    this.window = 0.3,
    this.coefficient = 0.00007,
    this.maxDeviation = 0.3,
    this.responseTau = 0.18,
  });

  LiquidGlassLensMotionSpec copyWith({
    double? window,
    double? coefficient,
    double? maxDeviation,
    double? responseTau,
  }) {
    return LiquidGlassLensMotionSpec(
      window: window ?? this.window,
      coefficient: coefficient ?? this.coefficient,
      maxDeviation: maxDeviation ?? this.maxDeviation,
      responseTau: responseTau ?? this.responseTau,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassLensMotionSpec &&
          other.window == window &&
          other.coefficient == coefficient &&
          other.maxDeviation == maxDeviation &&
          other.responseTau == responseTau;

  @override
  int get hashCode =>
      Object.hash(window, coefficient, maxDeviation, responseTau);
}

/// The running simulation behind [LiquidGlassLensMotionSpec]. One
/// instance per moving body; see the library doc for the calling
/// contract.
class LiquidGlassLensMotion {
  LiquidGlassLensMotion({this.spec = const LiquidGlassLensMotionSpec()});

  /// Live tuning; takes effect from the next [track].
  LiquidGlassLensMotionSpec spec;

  /// `(position, timestamp seconds)` samples inside the window.
  final List<(Offset, double)> _history = [];

  bool _tracking = false;
  double _deviation = 0;

  /// Whether the effect is live ([start] without a [stop] yet).
  bool get isTracking => _tracking;

  /// The current eased scale deviation, signed. `0` at rest.
  double get deviation => _deviation;

  /// Clears the history and samples from here on. Call when the effect
  /// goes live.
  void start() {
    _history.clear();
    _deviation = 0;
    _tracking = true;
  }

  /// Stops sampling and drops the deformation in the same breath — an
  /// instant reset, masked by whatever animation runs over it.
  void stop() {
    _tracking = false;
    _history.clear();
    _deviation = 0;
  }

  /// Samples [position], prunes the window, and eases the deviation
  /// toward the averaged acceleration's answer. Call once per frame
  /// while tracking, with the caller's monotonic clock [now] (seconds)
  /// and the [dt] since the previous frame. Returns the new deviation.
  double track(Offset position, {required double now, required double dt}) {
    if (!_tracking) return _deviation;
    _history.add((position, now));
    final cutoff = now - spec.window;
    _history.removeWhere((s) => s.$2 < cutoff);
    final raw = (_averageAcceleration() * spec.coefficient)
        .clamp(-spec.maxDeviation, spec.maxDeviation);
    final ease = spec.responseTau <= 0
        ? 1.0
        : (dt / spec.responseTau).clamp(0.0, 1.0);
    _deviation += (raw - _deviation) * ease;
    return _deviation;
  }

  /// Velocities between consecutive position samples, accelerations
  /// between consecutive
  /// velocities, averaged per axis, then combined as `avgX − avgY`.
  double _averageAcceleration() {
    final h = _history;
    if (h.length < 3) return 0;

    final velocities = <(Offset, double)>[]; // (velocity, mid-timestamp)
    for (var i = 1; i < h.length; i++) {
      final dt = h[i].$2 - h[i - 1].$2;
      if (dt <= 0) continue;
      velocities.add((
        (h[i].$1 - h[i - 1].$1) / dt,
        (h[i].$2 + h[i - 1].$2) / 2,
      ));
    }
    if (velocities.length < 2) return 0;

    var total = Offset.zero;
    var count = 0;
    for (var i = 1; i < velocities.length; i++) {
      final dt = velocities[i].$2 - velocities[i - 1].$2;
      if (dt <= 0) continue;
      total += (velocities[i].$1 - velocities[i - 1].$1) / dt;
      count++;
    }
    if (count == 0) return 0;
    return (total.dx - total.dy) / count;
  }
}
