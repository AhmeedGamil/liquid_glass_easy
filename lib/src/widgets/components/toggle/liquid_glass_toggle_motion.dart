import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import '../../utils/liquid_glass_jelly_spring.dart';

/// One 1-D spring channel: a value that chases a target every frame.
///
/// Tuned by stiffness + damping *ratio* rather than a raw damping
/// coefficient, so a channel reads as "how bouncy" (`< 1` overshoots,
/// `1` settles without wobble) independently of how stiff it is.
class _MotionSpring {
  _MotionSpring({
    required this.stiffness,
    required double dampingRatio,
    double initial = 0,
  })  : damping = 2 * dampingRatio * math.sqrt(stiffness),
        value = initial,
        target = initial;

  final double stiffness;
  final double damping;

  double value;
  double velocity = 0;
  double target;

  bool get settled => (value - target).abs() < 0.001 && velocity.abs() < 0.001;

  void snapTo(double v) {
    value = v;
    target = v;
    velocity = 0;
  }

  void step(double dt) {
    final (x, v) = liquidGlassSpringStep(
      x: value,
      vel: velocity,
      target: target,
      dt: dt,
      stiffness: stiffness,
      damping: damping,
    );
    value = x;
    velocity = v;
  }
}

/// Press + drag motion for the toggle handle.
///
/// Five springs run in parallel off one ticker:
///
///  • [value] — where the handle sits, `0`..`1`. It chases the raw drag
///    fraction through a stiff critically-damped spring, so the handle
///    trails the finger slightly instead of being welded to it.
///  • [pressProgress] — `0` at rest, `1` while held. Drives the handoff
///    from the solid handle to the glass one.
///  • [scaleX] / [scaleY] — the handle swells to [pressedScale] on
///    touch-down. Both are underdamped, and X is bouncier than Y, so the
///    swell arrives with a little wobble rather than a dead stop.
///  • [velocity] — the smoothed momentum of [value], which the scale
///    getters fold back in as squash & stretch: moving fast stretches
///    the handle along its travel and thins it against it.
///
/// [release] deliberately does **not** shrink the handle straight away —
/// it waits until the value has essentially reached its target, so the
/// handle stays swollen for the whole trip and only relaxes once it has
/// landed.
///
/// This is a self-contained driver: it owns its ticker and only *calls*
/// the shared spring integrator, so retuning it can't disturb the jelly
/// physics the slider and nav bar share.
class LiquidGlassToggleMotion {
  LiquidGlassToggleMotion({
    required TickerProvider vsync,
    required double initialValue,
    required this.onTick,
    this.restScale = 1.0,
    this.pressedScale = 1.5,
  })  : _value = _MotionSpring(
          stiffness: 1000,
          dampingRatio: 1,
          initial: initialValue,
        ) {
    _scaleX.snapTo(restScale);
    _scaleY.snapTo(restScale);
    _ticker = vsync.createTicker(_tick);
  }

  /// Called after every simulation step so the host can rebuild.
  final VoidCallback onTick;

  /// Handle scale at rest.
  final double restScale;

  /// Handle scale while held.
  final double pressedScale;

  /// How close to its target the value must get before a released
  /// handle is allowed to shrink back — 2.5% of the travel.
  static const double _arrivalThreshold = 0.025;

  /// Momentum (value-units/second) that maps to the full squash &
  /// stretch. Higher → the handle only deforms on a real flick.
  static const double _momentumScale = 50;

  final _MotionSpring _value;
  final _MotionSpring _press = _MotionSpring(stiffness: 1000, dampingRatio: 1);
  final _MotionSpring _scaleX = _MotionSpring(stiffness: 250, dampingRatio: 0.6);
  final _MotionSpring _scaleY = _MotionSpring(stiffness: 250, dampingRatio: 0.7);
  final _MotionSpring _velocity = _MotionSpring(
    stiffness: 300,
    dampingRatio: 0.5,
  );

  late final Ticker _ticker;
  Duration? _lastElapsed;
  bool _releasePending = false;

  /// Where the handle currently is, `0`..`1`.
  double get value => _value.value;

  /// Where the handle is heading — the raw drag fraction, before the
  /// spring lag. This is what a drag-end should snap on.
  double get targetValue => _value.target;

  /// `0` at rest, `1` while held.
  double get pressProgress => _press.value;

  /// Smoothed momentum of [value], in value-units/second.
  double get velocity => _velocity.value;

  /// Horizontal handle scale, with momentum stretch folded in.
  double get scaleX {
    final v = _velocity.value / _momentumScale;
    return _scaleX.value / (1 - (v * 0.75).clamp(-0.2, 0.2));
  }

  /// Vertical handle scale, with momentum squash folded in.
  double get scaleY {
    final v = _velocity.value / _momentumScale;
    return _scaleY.value * (1 - (v * 0.25).clamp(-0.2, 0.2));
  }

  /// Touch-down: swell the handle and hand over to the glass.
  void press() {
    _releasePending = false;
    _press.target = 1;
    _scaleX.target = pressedScale;
    _scaleY.target = pressedScale;
    _ensureTicking();
  }

  /// Touch-up: keep the handle swollen until it lands, then relax.
  void release() {
    _releasePending = true;
    _ensureTicking();
  }

  /// Points the handle at a new position without touching the press
  /// state. Call on every drag update.
  void updateValue(double v) {
    _value.target = v.clamp(0.0, 1.0);
    _ensureTicking();
  }

  /// A move the user didn't drag — tapping the track, or the value
  /// being changed from outside. Runs the whole press/travel/relax
  /// cycle so it reads the same as a flick.
  void animateToValue(double v) {
    press();
    updateValue(v);
    release();
  }

  void dispose() => _ticker.dispose();

  void _ensureTicking() {
    if (_ticker.isTicking) return;
    _lastElapsed = null;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final last = _lastElapsed ?? elapsed;
    _lastElapsed = elapsed;
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) return;
    // A dropped frame shouldn't teleport the springs.
    if (dt > 1 / 30) dt = 1 / 30;

    _value.step(dt);
    // Momentum comes from the value spring's OWN integrated velocity,
    // not from differencing its position. A per-frame `(Δvalue)/dt` is
    // noisy — dt jitters a few percent every frame, and that noise lands
    // straight on the squash/stretch, wobbling the handle (and the hole
    // cut to match it) by about a pixel per frame. The integrated
    // velocity is smooth by construction and already in value-units per
    // second. Measured off the *animated* value either way, so a spring
    // overshoot still deforms the handle.
    _velocity.target = _value.velocity;
    _velocity.step(dt);
    _press.step(dt);
    _scaleX.step(dt);
    _scaleY.step(dt);

    if (_releasePending &&
        (_value.value - _value.target).abs() < _arrivalThreshold) {
      _releasePending = false;
      _press.target = 0;
      _scaleX.target = restScale;
      _scaleY.target = restScale;
    }

    if (!_releasePending &&
        _value.settled &&
        _velocity.settled &&
        _press.settled &&
        _scaleX.settled &&
        _scaleY.settled) {
      _ticker.stop();
    }
    onTick();
  }
}
