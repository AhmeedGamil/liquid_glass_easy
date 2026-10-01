import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuning_store.dart';

// =============================================================
// Builds the bottom-nav glass look from a [NavTuning], so the tuner
// preview and the polished scaffold demo render the bar identically —
// the only difference between them is layout (width / alignment).
// =============================================================

/// A continuous (Apple capsule-style) rounded-rectangle glass shape for the
/// nav bar.
LiquidGlassShape _navGlass(double cornerRadius) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
    );

/// The nav bar's rim highlight, on a tunable [lightDirection].
LiquidGlassLight _navSpecular(double lightDirection) =>
    LiquidGlassLight.specular(
        angle: lightDirection, intensity: 1.1);

/// The nav bar's side glow, a quarter turn from the highlight.
LiquidGlassLight _navGlow(double lightDirection) => LiquidGlassLight.glow(
    thickness: 0.8, angle: lightDirection + 90, intensity: 1.0);

/// The bar capsule's look for a given tuning — the tunable bits are the
/// rim [NavTuning.lightDirection] and the frosted [NavTuning.background].
LiquidGlassStyle navBarStyle(NavTuning n) => LiquidGlassStyle(
      shape: _navGlass(50),
      specular: _navSpecular(n.lightDirection),
      glow: _navGlow(n.lightDirection),
      color: n.background,
      blur: 3,
    );

/// The selection-pill style for a given tuning — motion + travel + grow.
LiquidGlassTabPillStyle navPillStyle(NavTuning n) => LiquidGlassTabPillStyle(
      mode: LiquidGlassPillMode.both,
      animated: true,
      growHeight: n.growHeight,
      travelStiffness: n.travelStiffness,
      travelDamping: n.travelDamping,
      shape: _navGlass(59),
      glassStyle: LiquidGlassStyle(
        specular: _navSpecular(n.lightDirection),
        glow: _navGlow(n.lightDirection),
        color: Colors.transparent,
        refractionIndex: 1.026,
        refractionWidth: 10,
      ),
      motion: n.motion,
    );
