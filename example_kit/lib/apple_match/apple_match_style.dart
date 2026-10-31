import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// The tab bar's timing and press, not in the package's exports.
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_nav_bar_style.dart'
    show LiquidGlassTabPillTiming, LiquidGlassTabBarPress;

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
    ),
    glow: LiquidGlassLight.glow(
      thickness: t('$c.glowThickness'),
      angle: t('$c.glowAngle'),
      spread: t('$c.glowSpread'),
      intensity: t('$c.glowIntensity'),
      oppositeIntensity: t('$c.glowOpposite'),
      color: _lightColor('$c.glowColorNull', '$c.glowColor'),
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

/// The tab bar's press, every field read from its knobs; `null` while its
/// toggle is off.
LiquidGlassTabBarPress? tunedPress() {
  if (!AppleMatchTuning.b('tab.press')) return null;
  final double Function(String) t = AppleMatchTuning.d;
  return LiquidGlassTabBarPress(
    scale: t('tab.pressScale'),
    grip: t('tab.pressGrip'),
    stiffness: t('tab.pressStiffness'),
    damping: t('tab.pressDamping'),
    releaseDamping: t('tab.pressReleaseDamping'),
  );
}

/// A light's `color`: `null` while [nullId] is on, so the light takes the
/// colour of the backdrop under the edge; else the colour as given, its
/// alpha being how much of it replaces the picked-up colour.
Color? _lightColor(String nullId, String colorId) =>
    AppleMatchTuning.b(nullId) ? null : AppleMatchTuning.c(colorId);

/// The glass pill's events, timing and travel, every field read from its
/// knobs.
LiquidGlassTabPillTiming tunedTiming() {
  final double Function(String) t = AppleMatchTuning.d;
  return LiquidGlassTabPillTiming(
    liftDuration: t('tab.t.liftDuration'),
    liftBounce: t('tab.t.liftBounce'),
    dropDistance: t('tab.t.dropDistance'),
    travelDuration: t('tab.t.travelDuration'),
    travelBounce: t('tab.t.travelBounce'),
    glassFadeDuration: t('tab.t.glassFadeDuration'),
    dragDuration: t('tab.t.dragDuration'),
    dragBounce: t('tab.t.dragBounce'),
    dragThreshold: t('tab.t.dragThreshold'),
    landingWobbleStrength: t('tab.t.landingWobbleStrength'),
    landingWobbleDelay: t('tab.t.landingWobbleDelay'),
    landingSquashFadeDuration: t('tab.t.landingSquashFadeDuration'),
  );
}

/// The glass pill's squash and stretch, every field read from its knobs.
LiquidGlassLensMotionSpec tunedMotion() {
  final double Function(String) t = AppleMatchTuning.d;
  return LiquidGlassLensMotionSpec(
    sampleWindow: t('tab.d.sampleWindow'),
    // Its knob is in units of 0.00001.
    sensitivity: t('tab.d.sensitivity') / 100000,
    maxDeformation: t('tab.d.maxDeformation'),
    responseTime: t('tab.d.responseTime'),
  );
}
