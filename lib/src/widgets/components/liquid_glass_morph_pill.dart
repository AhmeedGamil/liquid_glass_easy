import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_shape.dart';
import '../utils/liquid_glass_border_mode.dart';

/// Layout description shared between the static "rest" pill and the
/// animated liquid-glass pill that grows out of it during a morph
/// transition (used by the slider, toggle, and bottom nav bar).
///
/// At rest the pill is rendered as a [LiquidGlassMorphPillStatic]
/// (cheap — plain Material with a soft rim). During an animation,
/// build a [LiquidGlass] lens with [buildLiquidGlassMorphPill] and
/// drive [extraHeight] from `0` → [LiquidGlassMorphPillSpec.extraHeight]
/// → `0` so the lens appears to bulge out of the static highlight
/// and settle back into it at the destination.
class LiquidGlassMorphPillSpec {
  /// Width of the pill at rest.
  final double width;

  /// Height of the pill at rest (matches the host control's inner
  /// row height).
  final double restHeight;

  /// How much taller the glass pill becomes at the peak of the
  /// animation.
  final double extraHeight;

  /// Corner radius at rest. The animated glass pill uses
  /// `currentHeight / 2` for a fully rounded look.
  final double restRadius;

  const LiquidGlassMorphPillSpec({
    required this.width,
    required this.restHeight,
    this.extraHeight = 36,
    this.restRadius = 999,
  });

  /// Resolved corner radius for the rest pill (capped to half height).
  double get resolvedRestRadius => math.min(restRadius, restHeight / 2);
}

/// Static rest pill — a plain Material box with a soft rim. Cheap to
/// render. Place it where the at-rest pill should appear; while a
/// morph is running, hide it and let the [LiquidGlass] from
/// [buildLiquidGlassMorphPill] take over.
class LiquidGlassMorphPillStatic extends StatelessWidget {
  final LiquidGlassMorphPillSpec spec;

  const LiquidGlassMorphPillStatic({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: spec.width,
        height: spec.restHeight,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(spec.resolvedRestRadius),
          border: Border.all(
            color: Colors.white.withAlpha(150),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the moving liquid-glass pill at the requested screen
/// position. Place the result in the OUTER `LiquidGlassView`'s
/// `children:` list while the animation is running.
LiquidGlass buildLiquidGlassMorphPill({
  required LiquidGlassMorphPillSpec spec,
  required double left,
  required double bottom,
  required double extraHeight,

  /// Full glass look as one [LiquidGlassStyle] (shape + appearance +
  /// refraction). When non-null, its [LiquidGlassStyle.appearance] and
  /// [LiquidGlassStyle.refraction] replace the tuned morph defaults, and
  /// its [LiquidGlassStyle.shape] is used as-is. When the style is null —
  /// or its shape is null — the pill keeps a height-tracking capsule
  /// (radius = current height / 2) so it stays a clean pill as it morphs.
  LiquidGlassStyle? style,

  /// Corner curve used for the height-tracking default capsule when no
  /// explicit [style] shape is supplied. Defaults to the cheap circular
  /// rounded rectangle; the slider opts into
  /// [LiquidGlassCornerStyle.continuousRoundedRectangle].
  LiquidGlassCornerStyle defaultCornerStyle =
      LiquidGlassCornerStyle.roundedRectangle,

  /// Border width of the height-tracking default capsule when no explicit
  /// [style] shape is supplied. Lets a caller thin (or thicken) the rim
  /// without taking over the whole tuned default shape.
  double defaultBorderWidth = 1.0,

  /// Scales the refraction band's **width** as the pill grows into its
  /// final size. `1.0` (the default) leaves it exactly as authored.
  ///
  /// The band is a distance inward from the rim, so a width authored for
  /// the full-size pill is a much larger *proportion* of a small one —
  /// at the start of a morph it can reach past the pill's own half-height
  /// and swallow the whole surface. Feeding the pill's current size ratio
  /// here keeps the band proportional throughout, arriving at the
  /// authored value once the pill is full size.
  ///
  /// Applies to whichever width is in play: the legacy
  /// [LiquidGlassRefraction.distortionWidth], or the width inside a
  /// [LiquidGlassRefractionType] when one is set (including
  /// [OpticalRefraction.refractionWidth]).
  double refractionWidthScale = 1.0,

  /// Optional content rendered INSIDE the lens, on top of the glass
  /// passes (e.g. a solid rest handle drawn over the glass pill). The
  /// child also receives touches, so it can carry the control's
  /// gesture handling.
  Widget? child,
}) {
  final h = spec.restHeight + extraHeight;
  final LiquidGlassStyle resolved = resolveLiquidGlassMorphPillStyle(
    height: h,
    style: style,
    defaultCornerStyle: defaultCornerStyle,
    defaultBorderWidth: defaultBorderWidth,
    refractionWidthScale: refractionWidthScale,
  );
  return LiquidGlass(
    child: child,
    geometry: LiquidGlassGeometry(
      position: LiquidGlassOffsetPosition(
        left: left,
        bottom: bottom - extraHeight / 2,
      ),
      width: spec.width,
      height: h,
    ),
    shape: resolved.shape!,
    refraction: resolved.refraction,
    appearance: resolved.appearance,
  );
}

/// Resolves the morph pill's material at its current [height] — the
/// same shape/refraction/appearance resolution [buildLiquidGlassMorphPill]
/// applies, exposed on its own for hosts that render the pill as a
/// layout-driven [LiquidGlassLens] instead of a positioned config.
LiquidGlassStyle resolveLiquidGlassMorphPillStyle({
  required double height,
  LiquidGlassStyle? style,
  LiquidGlassCornerStyle defaultCornerStyle =
      LiquidGlassCornerStyle.roundedRectangle,
  double defaultBorderWidth = 1.0,
  double refractionWidthScale = 1.0,
}) {
  // The pill morphs as it grows, so without an explicit shape it stays a
  // height-tracking capsule. A caller-supplied style.shape is honored.
  final LiquidGlassShape shape = style?.shape ??
      LiquidGlassShape(
        cornerStyle: defaultCornerStyle,
        cornerRadius: height / 2,
        borderWidth: defaultBorderWidth,
        lightIntensity: 1.3,
        lightDirection: 80,
        borderType: const OpticalBorder(
          borderSaturation: 1.4,
          ambientIntensity: 1.0,
          borderSolidity: 0.5,
        ),
      );
  final LiquidGlassRefraction authoredRefraction = style?.refraction ??
      const LiquidGlassRefraction(
        distortion: 0.12,
        distortionWidth: 18,
      );
  // Keep the band proportional to the pill. A configured
  // LiquidGlassRefractionType owns its own width, so scale it there;
  // otherwise scale the legacy distortionWidth the shader falls back to.
  final LiquidGlassRefraction refraction = refractionWidthScale == 1.0
      ? authoredRefraction
      : (authoredRefraction.refractionType != null
          ? authoredRefraction.copyWith(
              refractionType: authoredRefraction.refractionType!
                  .withWidthFactor(refractionWidthScale),
            )
          : authoredRefraction.copyWith(
              distortionWidth:
                  authoredRefraction.distortionWidth * refractionWidthScale,
            ));
  final LiquidGlassAppearance appearance = style?.appearance ??
      LiquidGlassAppearance(
        color: Colors.white.withAlpha(28),
        blur: const LiquidGlassBlur(sigmaX: 1.5, sigmaY: 1.5),
      );
  return LiquidGlassStyle(
    shape: shape,
    appearance: appearance,
    refraction: refraction,
  );
}

/// `sin(π·t)` envelope used by the morph: 0 at start and end, 1 at
/// midpoint. Apply it to the extra-height delta so the pill grows out
/// of the static highlight and shrinks back into it at the
/// destination.
double liquidGlassMorphEnvelope(double t) =>
    math.sin(math.pi * t.clamp(0.0, 1.0));
