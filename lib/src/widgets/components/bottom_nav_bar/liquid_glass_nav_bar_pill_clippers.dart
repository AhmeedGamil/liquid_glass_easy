import 'package:flutter/material.dart';

import '../../utils/liquid_glass_shape.dart';
import 'liquid_glass_nav_bar_pill.dart';

/// Clips its child to the inside of the moving pill's outline. Used by
/// the "selected icons" layer so each icon only paints in the area
/// currently under the pill. The outline follows [shape]'s corner family
/// (via [liquidGlassNavPillOutline]) so the reveal matches the pill —
/// falling back to a [pillRadius] capsule when [shape] is null.
class NavBarInsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;
  final LiquidGlassShape? shape;

  const NavBarInsidePillClipper({
    required this.pillRect,
    required this.pillRadius,
    this.shape,
  });

  @override
  Path getClip(Size size) =>
      liquidGlassNavPillOutline(pillRect.size, shape).shift(pillRect.topLeft);

  @override
  bool shouldReclip(NavBarInsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius ||
        oldClipper.shape != shape;
  }
}

/// Clips its child to "everything except the moving pill". Used by the
/// "unselected icons" layer so the parts of each icon not under the pill
/// stay outlined / dim. Uses the same [shape]-aware outline as
/// [NavBarInsidePillClipper].
class NavBarOutsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;
  final LiquidGlassShape? shape;

  const NavBarOutsidePillClipper({
    required this.pillRect,
    required this.pillRadius,
    this.shape,
  });

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final pill =
        liquidGlassNavPillOutline(pillRect.size, shape).shift(pillRect.topLeft);
    return Path.combine(PathOperation.difference, full, pill);
  }

  @override
  bool shouldReclip(NavBarOutsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius ||
        oldClipper.shape != shape;
  }
}
