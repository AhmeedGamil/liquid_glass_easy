import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'liquid_glass_border_mode.dart';
import 'liquid_glass_light_mode.dart';

/// The corner curve of a [LiquidGlassShape].
///
/// Selects which corner SDF the shader draws and which exact clip path the
/// renderers use. The single axis of variation between the old
/// `RoundedRectangleShape` / `SquircleShape` / `ContinuousRoundedRectangleShape`
/// classes, now an explicit value.
enum LiquidGlassCornerStyle {
  /// Plain **circular** rounded rectangle — corners are circular arcs of
  /// `cornerRadius`. The cheapest style.
  roundedRectangle,

  /// **L^n squircle** — the corners use the superellipse (`L^n`-norm)
  /// continuous-curvature profile, full iOS-style smoothing. The shader draws
  /// the matching `squircle*` SDF.
  squircle,

  /// **Apple capsule-style** continuous rounded rectangle — each corner is an
  /// exact circle "belly" plus a tuned G2 shoulder onto each flat edge. The
  /// shader draws the matching `continuousRoundedRect*` SDF; at full radius it
  /// degrades to a clean capsule. **The default corner style.**
  continuousRoundedRectangle,
}

/// The geometry, border and lighting of a liquid-glass lens.
///
/// One concrete class: the corner curve is chosen by [cornerStyle] (or one of
/// the [LiquidGlassShape.rounded] / [LiquidGlassShape.squircle] /
/// [LiquidGlassShape.continuous] convenience constructors). Border styling is
/// shared across both classic and optical border modes; mode-specific
/// parameters are encapsulated in [borderType].
class LiquidGlassShape {
  /// The corner curve. See [LiquidGlassCornerStyle].
  final LiquidGlassCornerStyle cornerStyle;

  /// The corner radius in logical pixels.
  final double cornerRadius;

  /// Whether the lens is clipped with the cheap circular rounded rectangle
  /// (`ClipRRect`) or an exact `ClipPath` matching this shape's shader corner.
  /// See [LiquidGlassClipQuality]. Defaults to
  /// [LiquidGlassClipQuality.roundedRectangle].
  final LiquidGlassClipQuality clipQuality;

  /// The thickness of the lens border in logical pixels.
  ///
  /// Increasing this value makes the border appear thicker
  /// around the lens perimeter.
  final double borderWidth;

  /// The base color of the lens border.
  ///
  /// If not `null`, this will replace the light and shadow color. It's a solid color.
  final Color? borderColor;

  /// The brightness multiplier for lens lighting and reflections.
  ///
  /// Controls how strongly highlights and shadows appear on the border.
  /// - Typical range: `0.0` (no lighting) → `1.0` (normal brightness) → `>1.0` (strong glow).
  final double lightIntensity;

  /// The primary highlight color applied to illuminated areas of the lens border.
  ///
  /// Used in both classic mode (sweep gradient highlight) and optical mode
  /// (specular boost highlights). Usually a lighter tint such as white or pale yellow.
  final Color lightColor;

  /// The directional angle (in degrees) from which the simulated light hits the lens.
  ///
  /// - `0°` means light comes from the right.
  /// - `90°` means light comes from the top.
  /// - `180°` from the left, and `270°` from the bottom.
  ///
  /// Used to compute where highlights and shadows fall on the border.
  final double lightDirection;

  /// Defines how lighting is calculated along the liquid glass border.
  ///
  /// • [LiquidGlassLightMode.edge] — Uses the shape's edge gradient
  ///   as the surface normal, producing lighting that follows the
  ///   contour of the glass border and the light to expand along
  ///   straight edges. This results in more physically
  ///   accurate edge highlights.
  ///
  /// • [LiquidGlassLightMode.radial] — Uses a radial direction from
  ///   the center of the glass to each fragment, causing the light to expand naturally
  ///   along curved edges creating a uniform,
  ///   lens-like lighting sweep around the border.
  final LiquidGlassLightMode lightMode;

  /// Defines the rendering style and mode-specific parameters for the border.
  ///
  /// - [ClassicBorder] — Sweep gradient with light/shadow colors and softness.
  /// - [OpticalBorder] — Apple-style SDF rim light with ambient tinting and saturation.
  ///
  /// Defaults to [OpticalBorder].
  final LiquidGlassBorderType borderType;

  const LiquidGlassShape({
    this.cornerStyle = LiquidGlassCornerStyle.continuousRoundedRectangle,
    this.cornerRadius = 50.0,
    this.clipQuality = LiquidGlassClipQuality.roundedRectangle,
    this.borderWidth = 1.0,
    this.borderColor,
    this.lightIntensity = 1.0,
    this.lightColor = const Color(0xB2FFFFFF),
    this.lightDirection = 0.0,
    this.lightMode = LiquidGlassLightMode.edge,
    this.borderType = const OpticalBorder(),
  });

  /// A plain **circular** rounded rectangle
  /// ([LiquidGlassCornerStyle.roundedRectangle]). The cheapest style.
  const LiquidGlassShape.roundedRectangle({
    double cornerRadius = 50.0,
    LiquidGlassClipQuality clipQuality = LiquidGlassClipQuality.roundedRectangle,
    double borderWidth = 1.0,
    Color? borderColor,
    double lightIntensity = 1.0,
    Color lightColor = const Color(0xB2FFFFFF),
    double lightDirection = 0.0,
    LiquidGlassLightMode lightMode = LiquidGlassLightMode.edge,
    LiquidGlassBorderType borderType = const OpticalBorder(),
  }) : this(
          cornerStyle: LiquidGlassCornerStyle.roundedRectangle,
          cornerRadius: cornerRadius,
          clipQuality: clipQuality,
          borderWidth: borderWidth,
          borderColor: borderColor,
          lightIntensity: lightIntensity,
          lightColor: lightColor,
          lightDirection: lightDirection,
          lightMode: lightMode,
          borderType: borderType,
        );

  /// An **L^n squircle** rounded rectangle ([LiquidGlassCornerStyle.squircle]) —
  /// iOS-style continuous-curvature corners.
  const LiquidGlassShape.squircle({
    double cornerRadius = 50.0,
    LiquidGlassClipQuality clipQuality = LiquidGlassClipQuality.roundedRectangle,
    double borderWidth = 1.0,
    Color? borderColor,
    double lightIntensity = 1.0,
    Color lightColor = const Color(0xB2FFFFFF),
    double lightDirection = 0.0,
    LiquidGlassLightMode lightMode = LiquidGlassLightMode.edge,
    LiquidGlassBorderType borderType = const OpticalBorder(),
  }) : this(
          cornerStyle: LiquidGlassCornerStyle.squircle,
          cornerRadius: cornerRadius,
          clipQuality: clipQuality,
          borderWidth: borderWidth,
          borderColor: borderColor,
          lightIntensity: lightIntensity,
          lightColor: lightColor,
          lightDirection: lightDirection,
          lightMode: lightMode,
          borderType: borderType,
        );

  /// An **Apple capsule-style** continuous rounded rectangle
  /// ([LiquidGlassCornerStyle.continuousRoundedRectangle]).
  const LiquidGlassShape.continuousRoundedRectangle({
    double cornerRadius = 50.0,
    LiquidGlassClipQuality clipQuality = LiquidGlassClipQuality.roundedRectangle,
    double borderWidth = 1.0,
    Color? borderColor,
    double lightIntensity = 1.0,
    Color lightColor = const Color(0xB2FFFFFF),
    double lightDirection = 0.0,
    LiquidGlassLightMode lightMode = LiquidGlassLightMode.edge,
    LiquidGlassBorderType borderType = const OpticalBorder(),
  }) : this(
          cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
          cornerRadius: cornerRadius,
          clipQuality: clipQuality,
          borderWidth: borderWidth,
          borderColor: borderColor,
          lightIntensity: lightIntensity,
          lightColor: lightColor,
          lightDirection: lightDirection,
          lightMode: lightMode,
          borderType: borderType,
        );

  // ── Convenience getters for the painter to extract values ──

  /// The one-sided specular highlight intensity.
  ///
  /// Classic-only: returns the value from [ClassicBorder.oneSideLightIntensity]
  /// in classic mode, and `0.0` for optical mode (which derives its rim from
  /// the glass shape and does not use this specular term).
  double get oneSideLightIntensity => switch (borderType) {
        ClassicBorder(oneSideLightIntensity: final v) => v,
        OpticalBorder() => 0.0,
      };

  /// The double-sided specular highlight intensity.
  ///
  /// Classic-only: returns the value from
  /// [ClassicBorder.doubleSideLightIntensity] in classic mode, and `0.0` for
  /// optical mode (which derives its rim from the glass shape and does not use
  /// this specular term).
  double get doubleSideLightIntensity => switch (borderType) {
        ClassicBorder(doubleSideLightIntensity: final v) => v,
        OpticalBorder() => 0.0,
      };

  /// The border softness (classic only, returns 1.0 for optical).
  double get borderSoftness => switch (borderType) {
        ClassicBorder(borderSoftness: final s) => s,
        OpticalBorder() => 1.0,
      };

  /// The shadow color (classic only, returns transparent black for optical).
  Color get shadowColor => switch (borderType) {
        ClassicBorder(shadowColor: final c) => c,
        OpticalBorder() => const Color(0x1A000000),
      };

  /// The ambient intensity used by the shader for the optical rim.
  ///
  /// Returns the user-configurable value from [OpticalBorder.ambientIntensity]
  /// when in optical mode, and `0.0` for classic mode (which doesn't use
  /// the ambient term).
  double get ambientIntensity => switch (borderType) {
        OpticalBorder(ambientIntensity: final a) => a,
        ClassicBorder() => 0.0,
      };

  /// The border saturation (optical only, returns 1.0 for classic).
  double get borderSaturation => switch (borderType) {
        OpticalBorder(borderSaturation: final s) => s,
        ClassicBorder() => 1.0,
      };

  /// The optical-mode rim solidity. `0.0` for classic mode (unused there).
  double get borderSolidity => switch (borderType) {
        OpticalBorder(borderSolidity: final s) => s,
        ClassicBorder() => 0.0,
      };

  /// The optical-mode rim highlight spread. `0.5` (neutral) for classic mode,
  /// which doesn't use the directional-rim term.
  double get lightSpread => switch (borderType) {
        OpticalBorder(lightSpread: final s) => s,
        ClassicBorder() => 0.5,
      };

  /// Whether the border mode is optical.
  bool get isOpticalBorder => borderType.isOptical;

  /// The border mode as the enum value (for shader uniform).
  LiquidGlassBorderMode get borderMode => borderType.isOptical
      ? LiquidGlassBorderMode.optical
      : LiquidGlassBorderMode.classic;
}

/// For backward compatibility — the enum is still used internally
/// by the shader dispatch logic.
enum LiquidGlassBorderMode { classic, optical }

/// How a lens is **clipped** to its outline. Every [LiquidGlassShape] carries
/// its own [LiquidGlassShape.clipQuality].
enum LiquidGlassClipQuality {
  /// Cheapest: a plain circular rounded-rectangle clip (`ClipRRect`). The
  /// historic default. Its silhouette is a circular corner even when the shader
  /// draws a squircle/continuous corner, so for those shapes the clipped
  /// child/blur edge may not perfectly hug the refraction.
  roundedRectangle,

  /// An exact `ClipPath` that matches this shape's shader corner: the squircle
  /// L^n curve for [LiquidGlassCornerStyle.squircle], the Apple capsule-style
  /// curve for [LiquidGlassCornerStyle.continuous], and a circular rounded rect
  /// for [LiquidGlassCornerStyle.circular]. Slightly pricier (adds a save
  /// layer) but the clipped silhouette lines up exactly with the refraction.
  exact,
}

/// The shader corner-style selector (`u_cornerStyle`), derived from
/// [LiquidGlassShape.cornerStyle]:
///   * `2.0` — Apple capsule-style ([LiquidGlassCornerStyle.continuous]).
///   * `1.0` — L^n squircle ([LiquidGlassCornerStyle.squircle], full smoothing).
///   * `0.0` — plain circular ([LiquidGlassCornerStyle.circular]).
double liquidGlassCornerStyle(LiquidGlassShape shape) =>
    switch (shape.cornerStyle) {
      LiquidGlassCornerStyle.continuousRoundedRectangle => 2.0,
      LiquidGlassCornerStyle.squircle => 1.0,
      LiquidGlassCornerStyle.roundedRectangle => 0.0,
    };

/// The corner radius used to **clip** a lens to its outline.
double liquidGlassClipCornerRadius(LiquidGlassShape shape) => shape.cornerRadius;

/// Whether the shape uses a rounded clip for its blur-backdrop and child clips.
/// Every [LiquidGlassShape] is a rounded-rectangle family shape, so this is
/// always `true` — kept as a named predicate for the renderers' call sites.
bool liquidGlassUsesRoundedClip(LiquidGlassShape shape) => true;

/// Wraps [child] in the clip that matches [shape]'s outline, honoring its
/// [LiquidGlassShape.clipQuality]: a circular `ClipRRect`, a shader-matched
/// squircle `ClipPath`, or an Apple capsule-style continuous `ClipPath`. Used
/// by the renderers so the clipped blur/child silhouette agrees with the SDF
/// the shader draws.
Widget liquidGlassClip({
  required LiquidGlassShape shape,
  required Widget child,
  Offset shapeScale = const Offset(1, 1),
}) {
  final double radius = liquidGlassClipCornerRadius(shape);
  final double sx = shapeScale.dx <= 0 ? 1.0 : shapeScale.dx;
  final double sy = shapeScale.dy <= 0 ? 1.0 : shapeScale.dy;
  if (liquidGlassUsesExactClipPath(shape)) {
    switch (shape.cornerStyle) {
      case LiquidGlassCornerStyle.continuousRoundedRectangle:
        return ClipPath(
          clipper: _LiquidGlassContinuousClipper(
              radius: radius, scaleX: sx, scaleY: sy),
          child: child,
        );
      case LiquidGlassCornerStyle.squircle:
        return ClipPath(
          // Full, fixed smoothing — matches the shader's squircle branch.
          clipper: _LiquidGlassSquircleClipper(
              radius: radius, smoothing: 1.0, scaleX: sx, scaleY: sy),
          child: child,
        );
      case LiquidGlassCornerStyle.roundedRectangle:
        // The exact clip is just the (possibly elliptical) RRect below.
        break;
    }
  }
  // Elliptical radii under deformation: the shader stretches the OUTLINE, so
  // a circular clip would sit outside the glass and leak the blur beneath it.
  // ClipRRect takes this natively, so the fast RRect clip is kept.
  return ClipRRect(
    borderRadius: (sx == 1.0 && sy == 1.0)
        ? BorderRadius.circular(radius)
        : BorderRadius.all(Radius.elliptical(radius * sx, radius * sy)),
    child: child,
  );
}

/// Whether [shape] is clipped with an exact [Path] rather than an `RRect`.
///
/// True only for the squircle and continuous corner curves at
/// [LiquidGlassClipQuality.exact] — a plain rounded rectangle's exact outline
/// IS the `RRect`, so it stays on the cheaper path.
@internal
bool liquidGlassUsesExactClipPath(LiquidGlassShape shape) =>
    shape.clipQuality == LiquidGlassClipQuality.exact &&
    liquidGlassClipCornerRadius(shape) > 0.5 &&
    shape.cornerStyle != LiquidGlassCornerStyle.roundedRectangle;

/// [shape]'s exact outline at [size], stretched by [scale].
///
/// Matches the SDF the shader draws, including the rest-space evaluation: the
/// path is built at rest size and scaled, so the corner curve stretches whole
/// rather than keeping a fixed radius on a deformed box.
///
/// Only meaningful when [liquidGlassUsesExactClipPath] is true; a plain
/// rounded rectangle returns its `RRect` as a path.
@internal
Path liquidGlassOutlinePath(
  LiquidGlassShape shape,
  Size size,
  Offset scale,
) {
  final double r = liquidGlassClipCornerRadius(shape);
  final double sx = scale.dx <= 0 ? 1.0 : scale.dx;
  final double sy = scale.dy <= 0 ? 1.0 : scale.dy;
  switch (shape.cornerStyle) {
    case LiquidGlassCornerStyle.continuousRoundedRectangle:
      return _liquidGlassScaledClipPath(
          size,
          sx,
          sy,
          (rest, renderScale) => liquidGlassContinuousRoundedRectPath(rest, r,
              renderScale: renderScale));
    case LiquidGlassCornerStyle.squircle:
      return _liquidGlassScaledClipPath(
          size,
          sx,
          sy,
          (rest, renderScale) =>
              liquidGlassSquirclePath(rest, r, 1.0, renderScale: renderScale));
    case LiquidGlassCornerStyle.roundedRectangle:
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, Radius.elliptical(r * sx, r * sy)));
  }
}

/// Scales a rest-space clip path onto the deformed box.
///
/// Mirrors the shader exactly: build the outline at REST size with the REST
/// radius, then stretch it. Scaling the PATH (rather than clipping a fixed
/// radius to the deformed box) is what keeps a stretched circle elliptical
/// for every corner style.
Path _liquidGlassScaledClipPath(
  Size size,
  double scaleX,
  double scaleY,
  Path Function(Size rest, double renderScale) build,
) {
  if (scaleX == 1.0 && scaleY == 1.0) return build(size, 1.0);
  final Path rest = build(Size(size.width / scaleX, size.height / scaleY),
      math.max(scaleX, scaleY));
  // `diagonal3Values`, not `scaleByDouble`: the latter needs vector_math 2.2.0
  // (Flutter 3.35+), and would fail to COMPILE for everyone below that.
  return rest.transform(Matrix4.diagonal3Values(scaleX, scaleY, 1).storage);
}

class _LiquidGlassSquircleClipper extends CustomClipper<Path> {
  final double radius;
  final double smoothing;
  final double scaleX;
  final double scaleY;
  const _LiquidGlassSquircleClipper({
    required this.radius,
    required this.smoothing,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  @override
  Path getClip(Size size) => _liquidGlassScaledClipPath(
      size,
      scaleX,
      scaleY,
      (rest, renderScale) => liquidGlassSquirclePath(rest, radius, smoothing,
          renderScale: renderScale));

  @override
  bool shouldReclip(_LiquidGlassSquircleClipper old) =>
      old.radius != radius ||
      old.smoothing != smoothing ||
      old.scaleX != scaleX ||
      old.scaleY != scaleY;
}

class _LiquidGlassContinuousClipper extends CustomClipper<Path> {
  final double radius;
  final double scaleX;
  final double scaleY;
  const _LiquidGlassContinuousClipper({
    required this.radius,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  @override
  Path getClip(Size size) => _liquidGlassScaledClipPath(
      size,
      scaleX,
      scaleY,
      (rest, renderScale) => liquidGlassContinuousRoundedRectPath(rest, radius,
          renderScale: renderScale));

  @override
  bool shouldReclip(_LiquidGlassContinuousClipper old) =>
      old.radius != radius ||
      old.scaleX != scaleX ||
      old.scaleY != scaleY;
}

/// The continuous-curvature (squircle) outline — the SAME L^n superellipse the
/// shader draws. `zone` and `n` are derived exactly like `continuousCornerParams`
/// in `liquid_glass_common.glsl`, so the clip lines up with the refraction.
Path liquidGlassSquirclePath(
  Size size,
  double r,
  double smoothing, {
  int? seg,
  double renderScale = 1.0,
}) {
  final double w = size.width, h = size.height;
  final double maxCorner = math.min(w, h) / 2;
  final double rr = math.min(r, maxCorner);
  if (rr < 0.5) return Path()..addRect(Offset.zero & size);

  final double sm = smoothing.clamp(0.0, 1.0);
  final double zone = math.min(rr * (1 + 0.528 * sm), maxCorner);
  final double base = (1 - 0.29289322 * (rr / zone)).clamp(0.5, 0.999999);
  final double n = -1.0 / (math.log(base) / math.ln2);
  // `zone` is this curve's reach — the corner box the superellipse fills — so
  // it is what sets the density, at the size the path will be DRAWN.
  final int steps = seg ?? (liquidGlassCornerSegments(zone * renderScale) * 2);
  // Loop-invariant: one exponent for the whole shape, not one per point.
  final double inv = 2 / n;

  List<Offset> corner(double cx, double cy, double sx, double sy) => [
        for (int i = 0; i <= steps; i++)
          () {
            final double t = (math.pi / 2) * i / steps;
            final double ox = zone * math.pow(math.cos(t), inv).toDouble();
            final double oy = zone * math.pow(math.sin(t), inv).toDouble();
            return Offset(cx + sx * ox, cy + sy * oy);
          }()
      ];

  final tl = corner(zone, zone, -1, -1);
  final tr = corner(w - zone, zone, 1, -1).reversed.toList();
  final br = corner(w - zone, h - zone, 1, 1);
  final bl = corner(zone, h - zone, -1, 1).reversed.toList();

  final all = [...tl, ...tr, ...br, ...bl];
  final path = Path()..moveTo(all.first.dx, all.first.dy);
  for (final p in all.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// The largest gap the polyline clip may leave against the true curve, in
/// logical pixels. Sub-pixel at any sensible device ratio, and the error is
/// one-sided (chords of a convex curve fall inside it), so this is also the
/// most the clip can ever shave off the rim.
const double _kContinuousClipErrorPx = 0.05;

/// Fitted constant of the chord-sagitta law: the worst deviation of a corner
/// of on-screen reach `R` sampled at `seg` steps is `≈ _kSagitta · R / seg²`.
/// Measured against a dense reference across radii, aspect ratios and
/// deformations; see `continuous_clip_precision_test.dart`.
const double _kSagitta = 0.103;

/// Tessellation density for a corner of on-screen [reach] — shared by both
/// curved corner styles. A corner spans `2 ×` this many straight segments.
///
/// [reach] is the corner's actual extent — the continuous curve's
/// `r · (1 + slack)`, the squircle's `zone` — NOT its radius. A stretched
/// corner covers more ground per step than a round one of the same radius, and
/// keying this on `r` alone lets an extreme aspect ratio slip past the budget
/// (measured: 600×24 at r 12 strayed 0.052 px).
///
/// Inverts the sagitta law for [_kContinuousClipErrorPx], so a small pill is
/// not tessellated to the same density as a full-screen card. Capped at 40 —
/// the old fixed count — so this can only ever emit fewer points, and floored
/// at 3 so even a hairline radius keeps a curve.
int liquidGlassCornerSegments(double reach) {
  if (!reach.isFinite || reach <= 0) return 3;
  final int seg = math.sqrt(_kSagitta * reach / _kContinuousClipErrorPx).ceil();
  return seg.clamp(3, 40);
}

/// The capsule-style continuous rounded-rectangle outline: each corner is a
/// p-norm ball whose box is stretched along whichever edge has room, with an
/// exponent that rises with that same room. The stretch is what makes the
/// corner read as continuous — the curve leaves the edge at `r · (1 + 0.2893)`
/// with zero tangent and curvature, instead of turning in at `r`.
///
/// This is the Dart twin of the shader's `continuousRoundedRect*` SDF, so the
/// [LiquidGlassClipQuality.continuous] clip lines up with the refraction.
///
/// Both the reach and the exponent ramp with each edge's slack, so a square at
/// full radius collapses to a clean circle and a capsule keeps a circular end
/// cap while its long flank stays smoothed.
Path liquidGlassContinuousRoundedRectPath(
  Size size,
  double r, {
  int? seg,
  double renderScale = 1.0,
}) {
  const double reachFrac = 0.2893, expRise = 0.7198, roomShape = 0.6;
  final double w = size.width, h = size.height;
  final double maxCorner = math.min(w, h) / 2;
  final double rr = math.min(r, maxCorner);
  if (rr < 0.5) return Path()..addRect(Offset.zero & size);

  // Each axis' slack, shaped, and the corner box + exponent it earns. Mirrors
  // `continuousRoundedRectReach` — the min() keeps a nearly-round edge from
  // asking for more reach than it has room for.
  double shaped(double half) {
    final double t = ((half - rr) / rr).clamp(0.0, 1.0);
    return math.min(reachFrac * math.pow(t, roomShape).toDouble(), t);
  }

  final double sH = shaped(w / 2);
  final double sV = shaped(h / 2);
  final double reachH = rr * (1 + sH); // onto top/bottom edges
  final double reachV = rr * (1 + sV); // onto left/right edges
  final double expH = 2 + expRise * sH / reachFrac;
  final double expV = 2 + expRise * sV / reachFrac;

  // Density is chosen from the corner's own extent, at the size it will be
  // DRAWN — the path may still be stretched by `renderScale` after this.
  final int segments =
      seg ?? liquidGlassCornerSegments(math.max(reachH, reachV) * renderScale);

  final double halfW = w / 2, halfH = h / 2;
  final double flatX = halfW - reachH;
  final double flatY = halfH - reachV;
  // Loop-invariant: the exponents are per-shape, not per-point.
  final double invH = 2 / expH, invV = 2 / expV;

  /// One corner, walked with the p-norm's own parametrization so the path and
  /// the shader's zero level are the same curve. φ = 0 sits on the vertical
  /// edge, φ = π/2 on the horizontal one.
  List<Offset> corner(double sx, double sy, {required bool forward}) {
    final steps = segments * 2;
    return [
      for (int i = 0; i <= steps; i++)
        () {
          final double t = i / steps;
          final double phi = (forward ? t : 1 - t) * math.pi / 2;
          final double u = reachH * math.pow(math.cos(phi), invH).toDouble();
          final double v = reachV * math.pow(math.sin(phi), invV).toDouble();
          return Offset(halfW + sx * (flatX + u), halfH + sy * (flatY + v));
        }(),
    ];
  }

  // Clockwise: up the left edge, across the top, down the right, back along
  // the bottom.
  final all = [
    ...corner(-1, -1, forward: true), // top-left:     left edge  → top edge
    ...corner(1, -1, forward: false), // top-right:    top edge   → right edge
    ...corner(1, 1, forward: true), // bottom-right: right edge → bottom edge
    ...corner(-1, 1, forward: false), // bottom-left:  bottom     → left edge
  ];
  final path = Path()..moveTo(all.first.dx, all.first.dy);
  for (final p in all.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}
