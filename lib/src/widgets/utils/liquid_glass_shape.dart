import 'dart:math' as math;

import 'package:flutter/material.dart';

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
}) {
  final double radius = liquidGlassClipCornerRadius(shape);
  if (radius > 0.5 && shape.clipQuality == LiquidGlassClipQuality.exact) {
    switch (shape.cornerStyle) {
      case LiquidGlassCornerStyle.continuousRoundedRectangle:
        return ClipPath(
          clipper: _LiquidGlassContinuousClipper(radius: radius),
          child: child,
        );
      case LiquidGlassCornerStyle.squircle:
        return ClipPath(
          // Full, fixed smoothing — matches the shader's squircle branch.
          clipper: _LiquidGlassSquircleClipper(radius: radius, smoothing: 1.0),
          child: child,
        );
      case LiquidGlassCornerStyle.roundedRectangle:
        // The exact clip is just the circular RRect below.
        break;
    }
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: child,
  );
}

class _LiquidGlassSquircleClipper extends CustomClipper<Path> {
  final double radius;
  final double smoothing;
  const _LiquidGlassSquircleClipper({
    required this.radius,
    required this.smoothing,
  });

  @override
  Path getClip(Size size) =>
      liquidGlassSquirclePath(size, radius, smoothing);

  @override
  bool shouldReclip(_LiquidGlassSquircleClipper old) =>
      old.radius != radius || old.smoothing != smoothing;
}

class _LiquidGlassContinuousClipper extends CustomClipper<Path> {
  final double radius;
  const _LiquidGlassContinuousClipper({required this.radius});

  @override
  Path getClip(Size size) => liquidGlassContinuousRoundedRectPath(size, radius);

  @override
  bool shouldReclip(_LiquidGlassContinuousClipper old) => old.radius != radius;
}

/// The continuous-curvature (squircle) outline — the SAME L^n superellipse the
/// shader draws. `zone` and `n` are derived exactly like `continuousCornerParams`
/// in `liquid_glass_common.glsl`, so the clip lines up with the refraction.
Path liquidGlassSquirclePath(
  Size size,
  double r,
  double smoothing, {
  int seg = 40,
}) {
  final double w = size.width, h = size.height;
  final double maxCorner = math.min(w, h) / 2;
  final double rr = math.min(r, maxCorner);
  if (rr < 0.5) return Path()..addRect(Offset.zero & size);

  final double sm = smoothing.clamp(0.0, 1.0);
  final double zone = math.min(rr * (1 + 0.528 * sm), maxCorner);
  final double base = (1 - 0.29289322 * (rr / zone)).clamp(0.5, 0.999999);
  final double n = -1.0 / (math.log(base) / math.ln2);

  List<Offset> corner(double cx, double cy, double sx, double sy) => [
        for (int i = 0; i <= seg; i++)
          () {
            final double t = (math.pi / 2) * i / seg;
            final double ox = zone * math.pow(math.cos(t), 2 / n).toDouble();
            final double oy = zone * math.pow(math.sin(t), 2 / n).toDouble();
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

/// The Apple capsule-style continuous rounded-rectangle outline: each corner
/// is an EXACT circle of radius `r` for its 45° "belly", plus a tuned G2
/// shoulder that eases the contact onto each flat edge. This is the Dart twin
/// of the shader's `continuousRoundedRect*` SDF (and the `_capsulePath`
/// experiment), so the [LiquidGlassClipQuality.continuous] clip lines up with
/// the refraction. The per-edge shoulder reach is clamped to the room
/// available on each edge, so a square at full radius collapses to a clean
/// circle (capsule), exactly like iOS. Constants are numerically tuned to
/// Apple's capsule.
Path liquidGlassContinuousRoundedRectPath(
  Size size,
  double r, {
  int seg = 40,
}) {
  const double extFrac = 0.4425, t0 = 0.728, aTail = 4.836, nTail = 3.869;
  final double w = size.width, h = size.height;
  final double maxCorner = math.min(w, h) / 2;
  final double rr = math.min(r, maxCorner);
  if (rr < 0.5) return Path()..addRect(Offset.zero & size);

  // Per-edge shoulder reach, clamped to the room available on each edge.
  final double eH = math.min(extFrac * rr, w / 2 - rr); // onto top/bottom edges
  final double eV = math.min(extFrac * rr, h / 2 - rr); // onto left/right edges
  final double belly = rr / math.sqrt2;

  double shoulderA(double tt) {
    if (tt <= t0) return 1.0;
    final double u = ((tt - t0) / (1 - t0)).clamp(0.0, 1.0);
    return math
        .pow(math.max(1 - math.pow(u, aTail).toDouble(), 0.0), 1 / nTail)
        .toDouble();
  }

  List<Offset> corner(double cx, double cy, double sx, double sy) {
    final out = <Offset>[];
    // Lower half: vertical-edge shoulder (param by u, contact -> belly).
    for (int i = 0; i <= seg; i++) {
      final double u = rr - (rr - belly) * i / seg;
      final double v = math.sqrt(math.max(rr * rr - u * u, 0.0)) +
          eV * (shoulderA(u / rr) - 1);
      out.add(Offset(cx + sx * u, cy + sy * v));
    }
    // Upper half: horizontal-edge shoulder (param by v, belly -> contact).
    for (int i = 1; i <= seg; i++) {
      final double v = belly + (rr - belly) * i / seg;
      final double u = math.sqrt(math.max(rr * rr - v * v, 0.0)) +
          eH * (shoulderA(v / rr) - 1);
      out.add(Offset(cx + sx * u, cy + sy * v));
    }
    return out;
  }

  final tl = corner(rr, rr, -1, -1);
  final tr = corner(w - rr, rr, 1, -1).reversed.toList();
  final br = corner(w - rr, h - rr, 1, 1);
  final bl = corner(rr, h - rr, -1, 1).reversed.toList();

  final all = [...tl, ...tr, ...br, ...bl];
  final path = Path()..moveTo(all.first.dx, all.first.dy);
  for (final p in all.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}
