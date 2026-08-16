import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_shape.dart';
import 'liquid_glass_nav_bar_layout.dart';

/// Builds the moving liquid-glass selection pill that slides across
/// the bar. Returns a [LiquidGlass] you place in the `children:` list
/// of the OUTER `LiquidGlassView`.
///
/// **Not exported yet** — this is part of the animated bottom nav
/// bar, whose motion work is still in progress. It is consumed only
/// by the package's own example/showcase.
///
/// Pass [animatedIndex] as a fractional value between `0` and
/// `items.length - 1` so the pill can be animated between tabs by
/// the caller (typically via an `AnimationController` running a
/// `Tween<double>` between the previous and next index).
///
/// [extraHeight] overrides the layout's default pill-extra-height
/// for this single frame. Animate it from `0` →
/// `layout.pillExtraHeight` → `0` to make the pill grow out of and
/// shrink back into the static selection highlight, the way iOS
/// does on tap.
///
/// [extraWidth] adds horizontal stretch to the pill — useful for
/// the jelly effect during a drag. Always grows symmetrically (left
/// and right) so the pill stays centered on its base index.
LiquidGlass buildLiquidGlassBottomNavPill({
  required LiquidGlassTabBarLayout layout,
  required double animatedIndex,
  required double parentWidth,

  /// Stable key for the pill lens. Pass a constant key so the pill
  /// keeps its own `State` when it is added to / removed from the
  /// outer view's `children` (it is only present while moving), instead
  /// of being matched by list index — which would otherwise let it
  /// reuse a sibling lens's `State`.
  Key? key,
  double? extraHeight,
  double extraWidth = 0,

  /// Horizontal shift applied to the whole bar (0 = centered). Lets the
  /// pill track a bar that's been moved off-center by a custom position.
  double dx = 0,

  /// Blur behind the moving pill. Defaults to **none** so the glass
  /// reads crisp; pass a [LiquidGlassBlur] to soften it.
  LiquidGlassBlur blur = const LiquidGlassBlur(),

  /// Refraction strength of the pill's glass. Higher = more bending.
  double distortion = 0.06,

  /// Width of the pill's refraction band, in logical pixels.
  double distortionWidth = 10,

  /// Complete refraction configuration. When set, this supersedes
  /// [distortion], [distortionWidth], and [magnification].
  LiquidGlassRefraction? refraction,

  /// Magnification of the content seen through the pill (`1` = none).
  double magnification = 1,

  /// When `true`, the pill's inner (non-distorted) area is transparent,
  /// revealing the background directly through the center.
  bool enableInnerRadiusTransparent = false,

  /// Overrides the pill's glass shape. When `null` the default
  /// **Apple capsule-style** [LiquidGlassShape] is used,
  /// with its corner radius tracking the pill's current height so it
  /// stays a clean capsule as the pill grows/squashes. Pass a custom
  /// [LiquidGlassShape] (e.g. a rounded or a
  /// continuous variant with a smaller radius) to give the
  /// pill visible continuous corners or a different rim.
  LiquidGlassShape? shape,

  /// Fill tint of the pill's glass. When `null`, the historic default
  /// (white at ~11% opacity) is used.
  Color? color,

  /// Overall opacity of the pill (`1` = opaque). Drives a true fade of the
  /// WHOLE pill (refraction + rim + tint) — used by the bar to fade the
  /// glass pill out before the static rest pill fades in.
  double opacity = 1.0,
}) {
  final extra = extraHeight ?? layout.pillExtraHeight;
  final cellW = layout.cellWidth;
  final barLeft = (parentWidth - layout.width) / 2 + dx;
  final pillLeft = barLeft + layout.padding + animatedIndex * cellW;
  // Center the pill (which may be taller than the cell) vertically
  // over the bar's inner row.
  final pillBottom = layout.bottomMargin + layout.padding - extra / 2;
  final pillH = layout.cellHeight + extra;
  final pillW = layout.pillWidth + extraWidth;
  // Center the extra width on the index so the pill doesn't drift
  // when stretching.
  final adjustedLeft = pillLeft - extraWidth / 2;

  return LiquidGlass(
    key: key,
    geometry: LiquidGlassGeometry(
      position: LiquidGlassOffsetPosition(
        left: adjustedLeft,
        bottom: pillBottom,
      ),
      width: pillW,
      height: pillH,
      // The grown pill is centered on its cell and so naturally overhangs
      // the bar/parent at the end tabs. Allow that overhang instead of
      // letting the lens get clamped back inside — clamping shifts the
      // pill off its cell (most visible on a bar with no side margin).
      outOfBoundaries: true,
    ),
    shape: shape ??
        LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: pillH / 2,
          borderWidth: 1.0,
          lightIntensity: 1.3,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.4,
            ambientIntensity: 1.0,
            borderSolidity: 0.5,
          ),
        ),
    refraction: refraction ??
        LiquidGlassRefraction(
          magnification: magnification,
          distortion: distortion,
          distortionWidth: distortionWidth,
          chromaticAberration: 0.002,
        ),
    appearance: LiquidGlassAppearance(
      color: color ?? Colors.white.withAlpha(28),
      blur: blur,
      enableInnerRadiusTransparent: enableInnerRadiusTransparent,
    ),
    opacity: opacity,
  );
}

/// Builds the long bar-capsule lens. Place it in the `children:`
/// list of the INNER `LiquidGlassView`. It refracts the wallpaper
/// that the inner view captures, and contributes its glass
/// appearance to the outer view's snapshot — so the selection pill
/// (built with [buildLiquidGlassBottomNavPill]) running in the
/// OUTER view refracts the bar's glass output.
LiquidGlass buildLiquidGlassBottomNavCapsule({
  required LiquidGlassTabBarLayout layout,

  /// Overrides the default bottom-center placement. When non-null the
  /// capsule lens uses this position directly (so the whole animated
  /// bar can honor a caller-supplied position).
  LiquidGlassPosition? position,

  /// Overrides the bar-capsule glass shape (e.g. a
  /// [LiquidGlassShape] or a custom radius/clip). When null,
  /// the default 40-radius optical capsule is used.
  LiquidGlassShape? shape,

  /// Refraction of the capsule glass. When `null`, the default optical
  /// capsule refraction is used.
  LiquidGlassRefraction? refraction,

  /// Appearance (tint + blur) of the capsule glass. When `null`, the
  /// default ~9% white frost is used.
  LiquidGlassAppearance? appearance,
}) {
  return LiquidGlass(
    geometry: LiquidGlassGeometry(
      position: position ??
          LiquidGlassAlignPosition(
            alignment: Alignment.bottomCenter,
            margin: EdgeInsets.only(bottom: layout.bottomMargin),
          ),
      width: layout.width,
      height: layout.height,
    ),
    shape: shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: 40,
          borderWidth: 1.2,
          lightIntensity: 1.1,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        ),
    refraction: refraction ??
        const LiquidGlassRefraction(
          distortion: 0.07,
          distortionWidth: 28,
          chromaticAberration: 0.002,
        ),
    appearance: appearance ??
        LiquidGlassAppearance(
          color: Colors.white.withAlpha(22),
          blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
        ),
  );
}

/// Plain (non-shader) version of the selection pill, used while the
/// pill is at rest. Mirrors the moving glass pill's silhouette (corner
/// [shape]) and fill ([color]) so swapping between the two is
/// unnoticeable. A rim is drawn **only when** [shape] sets a
/// `borderColor` (default: a borderless soft highlight) — there is no
/// drop shadow, so the rest and moving pills read identically.
class LiquidGlassBottomNavPillStatic extends StatelessWidget {
  final double width;
  final double height;

  /// Fill of the rest highlight.
  final Color color;

  /// Corner shape (and optional border) of the rest highlight. When
  /// `null` a plain capsule is used. Only the corner family + radius and
  /// the `borderColor`/`borderWidth` are honored — the optical/refractive
  /// fields don't apply to this non-shader pill.
  final LiquidGlassShape? shape;

  const LiquidGlassBottomNavPillStatic({
    super.key,
    required this.width,
    required this.height,
    this.color = const Color(0x26FFFFFF),
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(width, height),
        painter: LiquidGlassNavPillSurfacePainter(
          color: color,
          shape: shape,
        ),
      ),
    );
  }
}

/// The outline of a non-shader nav selection pill of [size], following
/// [shape]'s corner family — circular, L^n squircle, or the Apple
/// capsule-style continuous curve — so a CPU-painted pill or a clip
/// lines up with the glass pill the shader draws. A `null` shape yields
/// a plain capsule (radius = half the short side).
Path liquidGlassNavPillOutline(Size size, LiquidGlassShape? shape) {
  final s = shape;
  final double maxR = math.min(size.width, size.height) / 2;
  final double radius = s != null ? math.min(s.cornerRadius, maxR) : maxR;
  switch (s?.cornerStyle) {
    case LiquidGlassCornerStyle.continuousRoundedRectangle:
      return liquidGlassContinuousRoundedRectPath(size, radius);
    case LiquidGlassCornerStyle.squircle:
      // Full, fixed smoothing to match the shader's squircle branch
      // (u_cornerStyle == 1).
      return liquidGlassSquirclePath(size, radius, 1.0);
    case LiquidGlassCornerStyle.roundedRectangle:
    case null:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ));
  }
}

/// Paints a non-shader nav selection pill: just the [color] fill,
/// following [liquidGlassNavPillOutline] so the corners match the glass
/// pill. Shared by the static rest pill and the non-glass nav tiers.
///
/// There is deliberately **no drop shadow and no rim** — the pill reads
/// from its fill alone. The edge/rim treatment is intentionally left out
/// for now (revisit later).
class LiquidGlassNavPillSurfacePainter extends CustomPainter {
  final Color color;
  final LiquidGlassShape? shape;

  const LiquidGlassNavPillSurfacePainter({
    required this.color,
    this.shape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = liquidGlassNavPillOutline(size, shape);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(LiquidGlassNavPillSurfacePainter old) =>
      old.color != color || old.shape != shape;
}
