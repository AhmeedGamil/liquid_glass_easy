import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// One scalar chasing a target through the package's own spring integrator.
///
/// Nothing outside this class writes [value]: callers set [target] and the
/// integrator does the rest. That single rule is what makes a morph continuous
/// — a shape cannot jump even if a control wants it to.
///
/// Shared by the demos that morph geometry (the blend lab, the menu morph), so
/// they all overshoot and settle identically.
class Spring {
  Spring(double v)
      : value = v,
        target = v;

  double value;
  double target;
  double vel = 0;

  void step(double dt, double stiffness, double damping) {
    final (double v, double a) = liquidGlassSpringStep(
      x: value,
      vel: vel,
      target: target,
      dt: dt,
      stiffness: stiffness,
      damping: damping,
    );
    value = v;
    vel = a;
  }

  double get remaining => (target - value).abs();

  bool get moving => remaining > 0.05 || vel.abs() > 0.5;

  /// Arrive instantly — for a first layout, which should not animate.
  void snap() {
    value = target;
    vel = 0;
  }
}
