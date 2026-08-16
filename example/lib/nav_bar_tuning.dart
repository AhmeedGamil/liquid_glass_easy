import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuning_store.dart';

// =============================================================
// Builds the bottom-nav glass look from a [NavTuning], so the tuner
// preview and the polished scaffold demo render the bar identically —
// the only difference between them is layout (width / alignment).
// =============================================================

/// A continuous (Apple capsule-style) rounded-rectangle glass shape for the
/// nav bar, with a tunable [lightDirection].
LiquidGlassShape _navGlass(double cornerRadius, double lightDirection) =>
    LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: cornerRadius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: 0.8,
      lightIntensity: 1.1,
      lightDirection: lightDirection,
      borderType: const OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 1.0,
        borderSolidity: 1,
      ),
    );

/// The bar capsule's look for a given tuning — the tunable bits are the
/// rim [NavTuning.lightDirection] and the frosted [NavTuning.background].
LiquidGlassStyle navBarStyle(NavTuning n) => LiquidGlassStyle(
      shape: _navGlass(50, n.lightDirection),
      appearance: LiquidGlassAppearance(
        color: n.background,
        blur: const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
      ),
    );

/// The selection-pill style for a given tuning — motion + travel + grow.
LiquidGlassTabPillStyle navPillStyle(NavTuning n) => LiquidGlassTabPillStyle(
      mode: LiquidGlassPillMode.both,
      animated: true,
      growHeight: n.growHeight,
      travelStiffness: n.travelStiffness,
      travelDamping: n.travelDamping,
      shape: _navGlass(59, n.lightDirection),
      glassStyle: const LiquidGlassStyle(
        appearance: LiquidGlassAppearance(color: Colors.transparent),
        refraction: LiquidGlassRefraction(
          distortion: 0.05,
          distortionWidth: 10,
        ),
      ),
      motion: n.motion,
    );
