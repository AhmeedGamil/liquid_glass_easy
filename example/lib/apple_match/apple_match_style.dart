import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_tuning.dart';

/// Component [c]'s glass, every field read from its knobs, for
/// [brightness]. [cornerRadius] and [fill] replace the knob values where a
/// variant needs its own (a round icon button, a prominent fill).
LiquidGlassStyle tunedStyle(
  String c,
  Brightness brightness, {
  double? cornerRadius,
  Color? fill,
}) {
  final double Function(String) t = AppleMatchTuning.d;
  final bool dark = brightness == Brightness.dark;
  return LiquidGlassStyle(
    shape: LiquidGlassShape(
      cornerStyle: LiquidGlassCornerStyle
          .values[AppleMatchTuning.i('$c.cornerStyle').clamp(0, 2)],
      cornerRadius: cornerRadius ?? t('$c.cornerRadius'),
    ),
    specular: LiquidGlassLight.specular(
      thickness: t('$c.specThickness'),
      sharpness: t('$c.specSharpness'),
      angle: t('$c.specAngle'),
      spread: t('$c.specSpread'),
      intensity: t('$c.specIntensity'),
      oppositeIntensity: t('$c.specOpposite'),
      color: _lightColor('$c.specColorNull', '$c.specColor'),
      tintWeight: t('$c.specTintWeight'),
    ),
    glow: LiquidGlassLight.glow(
      thickness: t('$c.glowThickness'),
      angle: t('$c.glowAngle'),
      spread: t('$c.glowSpread'),
      intensity: t('$c.glowIntensity'),
      oppositeIntensity: t('$c.glowOpposite'),
      color: _lightColor('$c.glowColorNull', '$c.glowColor'),
      tintWeight: t('$c.glowTintWeight'),
    ),
    refractionIndex: t('$c.refIndex'),
    refractionWidth: t('$c.refWidth'),
    magnification: t('$c.magnification'),
    dispersion: t('$c.dispersion'),
    saturation: t(dark ? '$c.satDark' : '$c.satLight'),
    blur: t('$c.blur'),
    color: fill ?? AppleMatchTuning.c(dark ? '$c.fillDark' : '$c.fillLight'),
    shadow: AppleMatchTuning.b('$c.shadowOn')
        ? LiquidGlassShadow(
            blur: t('$c.shadowBlur'),
            opacity: t('$c.shadowOpacity'),
            color: AppleMatchTuning.c('$c.shadowColor'),
            offset: AppleMatchTuning.b('$c.shadowAutoOffset')
                ? null
                : Offset(t('$c.shadowOffsetX'), t('$c.shadowOffsetY')),
            inset: t('$c.shadowInset'),
            insideGlass: AppleMatchTuning.b('$c.shadowInsideGlass'),
          )
        : null,
    liteGlass: AppleMatchTuning.b('$c.lite'),
  );
}

/// Component [c]'s flex, every field read from its knobs; `null` while its
/// touch toggle is off.
LiquidGlassTouch? tunedTouch(String c) {
  if (!AppleMatchTuning.b('$c.flex')) return null;
  final double Function(String) t = AppleMatchTuning.d;
  return LiquidGlassTouch.flexing(LiquidGlassFlex(
    stretch: t('$c.flexStretch'),
    squeeze: t('$c.flexSqueeze'),
    lean: t('$c.flexLean'),
    grip: t('$c.flexGrip'),
    compressInward: AppleMatchTuning.b('$c.flexCompressInward'),
    holdScale: t('$c.flexHoldScale'),
    tapScale: t('$c.flexTapScale'),
    maxPull: t('$c.flexMaxPull'),
    lockAxis: const [null, Axis.horizontal, Axis.vertical]
        [AppleMatchTuning.i('$c.flexLockAxis').clamp(0, 2)],
    advanced: LiquidGlassFlexAdvanced(
      childFollow: t('$c.flexChildFollow'),
      refractionBoost: t('$c.flexRefractionBoost'),
      magnificationBoost: t('$c.flexMagnificationBoost'),
      stiffness: t('$c.flexStiffness'),
      damping: t('$c.flexDamping'),
      releaseDamping: t('$c.flexReleaseDamping'),
    ),
  ));
}

/// A light's `color`: `null` while [nullId] is on, so the light takes the
/// colour of the backdrop under the edge; else the colour as given, its
/// alpha being how much of it replaces the picked-up colour.
Color? _lightColor(String nullId, String colorId) =>
    AppleMatchTuning.b(nullId) ? null : AppleMatchTuning.c(colorId);
