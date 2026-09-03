import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Aurora — the look.
//
// Two things live here: the light (a palette is a base colour and the
// handful of coloured lamps painted into it) and the glass (one helper
// every surface in the app is cut from, so the whole thing reads as a
// single material rather than eight pages of settings).
// =============================================================

/// One soft lamp in a backdrop: where it sits, how far it reaches, and
/// what colour it throws. The backdrop paints these additively over a
/// near-black base, which is what gives the pages their glow.
class AuroraBlob {
  const AuroraBlob(this.center, this.radius, this.color, {this.intensity = 1});

  /// Position in the page, as an [Alignment] so it follows any screen.
  final Alignment center;

  /// Reach, as a fraction of the screen's shortest side.
  final double radius;

  final Color color;

  /// Multiplier on the lamp's brightness — how hot it burns.
  final double intensity;
}

/// The light one page is lit by. Every page has its own, so moving
/// between tabs changes the colour of the room the glass sits in.
class AuroraPalette {
  const AuroraPalette({
    required this.base,
    required this.accent,
    required this.blobs,
  });

  /// The unlit colour of the page — never pure black, always tinted.
  final Color base;

  /// The one saturated colour that page's UI is allowed to use.
  final Color accent;

  final List<AuroraBlob> blobs;

  static const AuroraPalette nightfall = AuroraPalette(
    base: Color(0xFF06060B),
    accent: Color(0xFF9E8CFF),
    blobs: [
      AuroraBlob(Alignment(-0.75, -0.95), 0.95, Color(0xFF5B4BFF)),
      AuroraBlob(Alignment(0.95, -0.45), 0.70, Color(0xFF12D6C0),
          intensity: 0.7),
      AuroraBlob(Alignment(0.15, 0.95), 0.85, Color(0xFFFF3D8A),
          intensity: 0.5),
    ],
  );

  static const AuroraPalette ember = AuroraPalette(
    base: Color(0xFF0A0607),
    accent: Color(0xFFFFB067),
    blobs: [
      AuroraBlob(Alignment(-0.85, -0.85), 0.80, Color(0xFFFF9F45),
          intensity: 0.85),
      AuroraBlob(Alignment(0.95, 0.05), 0.90, Color(0xFFFF4D6D),
          intensity: 0.7),
      AuroraBlob(Alignment(-0.25, 1.05), 0.80, Color(0xFF7A5CFF),
          intensity: 0.6),
    ],
  );

  static const AuroraPalette deep = AuroraPalette(
    base: Color(0xFF04070C),
    accent: Color(0xFF6FD9FF),
    blobs: [
      AuroraBlob(Alignment(0.90, -0.90), 0.85, Color(0xFF35C7FF),
          intensity: 0.8),
      AuroraBlob(Alignment(-0.80, 0.15), 0.90, Color(0xFF3B5BFF),
          intensity: 0.75),
      AuroraBlob(Alignment(0.35, 1.05), 0.60, Color(0xFF4DFFC3),
          intensity: 0.45),
    ],
  );

  static const AuroraPalette moss = AuroraPalette(
    base: Color(0xFF05090A),
    accent: Color(0xFF7BE8B0),
    blobs: [
      AuroraBlob(Alignment(-0.70, -0.85), 0.85, Color(0xFF2BE08A),
          intensity: 0.65),
      AuroraBlob(Alignment(0.95, -0.10), 0.80, Color(0xFF16B8C8),
          intensity: 0.7),
      AuroraBlob(Alignment(0.10, 1.05), 0.75, Color(0xFFE8C36B),
          intensity: 0.4),
    ],
  );

  static const AuroraPalette dusk = AuroraPalette(
    base: Color(0xFF0A0710),
    accent: Color(0xFFC9A6FF),
    blobs: [
      AuroraBlob(Alignment(-0.60, -0.95), 0.90, Color(0xFF8A5BFF),
          intensity: 0.85),
      AuroraBlob(Alignment(1.00, 0.20), 0.75, Color(0xFFFF6FB5),
          intensity: 0.6),
      AuroraBlob(Alignment(-0.30, 1.05), 0.85, Color(0xFF4A7BFF),
          intensity: 0.6),
    ],
  );

  static const AuroraPalette slate = AuroraPalette(
    base: Color(0xFF07080B),
    accent: Color(0xFFA9B8FF),
    blobs: [
      AuroraBlob(Alignment(0.85, -0.95), 0.80, Color(0xFF6E86FF),
          intensity: 0.7),
      AuroraBlob(Alignment(-0.90, 0.30), 0.85, Color(0xFF3ED8E8),
          intensity: 0.5),
      AuroraBlob(Alignment(0.30, 1.05), 0.70, Color(0xFF9B6BFF),
          intensity: 0.5),
    ],
  );

  /// The light a *record* throws — the room an album detail or the
  /// player is lit by, derived from the same seed its artwork is, so
  /// the page and the cover on it are always the same two colours.
  factory AuroraPalette.fromSeed(String seed) {
    final math.Random rnd = math.Random(seed.hashCode);
    final double h = rnd.nextDouble() * 360;
    Color hue(double delta, double saturation, double lightness) =>
        HSLColor.fromAHSL(1, (h + delta) % 360, saturation, lightness)
            .toColor();

    return AuroraPalette(
      // Near-black, but carrying the seed's hue — a page is never grey.
      base: HSLColor.fromAHSL(1, h, 0.38, 0.035).toColor(),
      accent: hue(18, 0.85, 0.72),
      blobs: [
        AuroraBlob(const Alignment(-0.80, -0.90), 0.95, hue(0, 0.85, 0.55),
            intensity: 0.9),
        AuroraBlob(const Alignment(0.95, -0.20), 0.75, hue(55, 0.80, 0.50),
            intensity: 0.65),
        AuroraBlob(const Alignment(0.00, 1.05), 0.90, hue(-50, 0.80, 0.50),
            intensity: 0.55),
      ],
    );
  }
}

// ── The material ─────────────────────────────────────────────

/// The one glass in the app. Everything that is a real lens — the bars,
/// the mini player, the dialog, the sheets, the field you type into —
/// is cut from this, and the arguments are the only thing that differs
/// between them.
///
/// The rim is optical rather than a painted stroke: it is derived from
/// the glass shape, so a corner catches the light the way a real bevel
/// would instead of glowing evenly all the way round. [auroraRim] is
/// that same rim on its own, for the surfaces that are not lenses.
LiquidGlassStyle auroraGlass({
  double radius = 26,
  Color tint = const Color(0x1FFFFFFF),
  double blur = 7,
  double distortion = 0.10,
  double distortionWidth = 30,
  double borderWidth = 0.9,
  double lightIntensity = 0.9,
  double lightDirection = 55,
  double saturation = 1.15,
  LiquidGlassShadow? shadow,
}) {
  return LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: radius,
      clipQuality: LiquidGlassClipQuality.exact,
      borderWidth: borderWidth,
      lightIntensity: lightIntensity,
      lightDirection: lightDirection,
      borderType: const OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 0.85,
        borderSolidity: 0.9,
      ),
    ),
    appearance: LiquidGlassAppearance(
      color: tint,
      blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
      saturation: saturation,
      shadow: shadow,
    ),
    refraction: LiquidGlassRefraction(
      distortion: distortion,
      distortionWidth: distortionWidth,
    ),
  );
}

/// The rim of that glass, without the glass.
///
/// [LiquidGlassLite] takes an ordinary [LiquidGlassShape] and reads it
/// exactly as a lens does, so this is [auroraGlass]'s border settings and
/// nothing else, at the same numbers: the same optical rim, the same
/// corner, drawn from a triangle mesh instead of a fragment shader.
///
/// Everything in a page's content is cut from this. Nothing in it reads
/// the backdrop, so there is no ceiling on how many of them a page can
/// have — which is the whole reason the cards, the tiles and the buttons
/// down there are rims and the chrome above them is glass.
LiquidGlassShape auroraRim({
  double radius = 26,
  double borderWidth = 0.9,
  double lightIntensity = 0.9,
  double lightDirection = 55,
}) {
  return LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: radius,
    borderWidth: borderWidth,
    lightIntensity: lightIntensity,
    lightDirection: lightDirection,
    borderType: const OpticalBorder(
      borderSaturation: 1.2,
      ambientIntensity: 0.85,
      borderSolidity: 0.9,
    ),
  );
}

/// The chrome material — app bar, tab bar, mini player. Thinner and
/// less distorting than a card's, because chrome sits over moving
/// content all day and a heavy lens there reads as smeared rather than
/// as glass.
LiquidGlassStyle auroraChrome({double radius = 30}) => auroraGlass(
      radius: radius,
      tint: const Color(0x1AFFFFFF),
      blur: 5,
      distortion: 0.065,
      distortionWidth: 26,
      borderWidth: 0.8,
      shadow: const LiquidGlassShadow(blur: 10, opacity: 0.22),
    );

// ── Type ─────────────────────────────────────────────────────

/// Display type: light weight, tight tracking, near-white. Big numbers
/// and page titles.
const TextStyle kDisplay = TextStyle(
  fontSize: 34,
  height: 1.05,
  fontWeight: FontWeight.w300,
  letterSpacing: -1.0,
  color: Color(0xFFF4F3F8),
);

const TextStyle kTitle = TextStyle(
  fontSize: 17,
  height: 1.2,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
  color: Color(0xFFF4F3F8),
);

const TextStyle kBody = TextStyle(
  fontSize: 13.5,
  height: 1.35,
  fontWeight: FontWeight.w400,
  color: Color(0xB3EDECF5),
);

/// The small all-caps line over a section — the app's only piece of
/// deliberately quiet type.
const TextStyle kEyebrow = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  color: Color(0x8AEDECF5),
);
