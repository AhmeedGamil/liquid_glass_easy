/// One integration step of an underdamped spring, sub-stepped at 240 Hz
/// for stability. Returns the new `(position, velocity)`.
///
/// The shared integrator behind every springy deformation in the
/// package — the slider thumb, the switch, the tab bar's moving pill and
/// the flex touch response all step their springs through it.
(double, double) liquidGlassSpringStep({
  required double x,
  required double vel,
  required double target,
  required double dt,
  double stiffness = 320,
  double damping = 22,
}) {
  var t = dt;
  var px = x;
  var pv = vel;
  while (t > 0) {
    final step = t > 1 / 240.0 ? 1 / 240.0 : t;
    final accel = -stiffness * (px - target) - damping * pv;
    pv += accel * step;
    px += pv * step;
    t -= step;
  }
  return (px, pv);
}
