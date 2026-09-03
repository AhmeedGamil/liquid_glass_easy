import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Vitrine — the look.
//
// A shop is a light room with saturated things in it, and that split
// runs through every file here. The PAPER is the room: warm, close to
// white, almost nothing on it. The PLATES are the things: full-bleed
// fields of colour with an object standing on them.
//
// Glass belongs over the plates. A lens over paper has nothing to bend
// and reads as a smudge, so the bars, and only the bars, float over the
// whole app — and the pages are laid out so a plate is always passing
// under them.
// =============================================================

// ── Paper ────────────────────────────────────────────────────

/// The room. Warm rather than white: a neutral page makes every plate
/// on it look slightly cold.
const Color kPaper = Color(0xFFF2EEE7);

/// One step down from the paper, for the strips a section sits in.
const Color kPaperSunk = Color(0xFFEAE5DC);

const Color kInk = Color(0xFF1A1714);
const Color kInkSoft = Color(0xFF6B6259);
const Color kInkFaint = Color(0xFF9E958A);

/// The hairline. Everything on paper is separated by this and nothing
/// else — no cards, no shadows. The plates do the shouting.
const Color kLine = Color(0x141A1714);

/// The one saturated colour the interface itself is allowed: sale tags,
/// the selected state, the price when it has moved.
const Color kSignal = Color(0xFFB4472E);

// ── Plates ───────────────────────────────────────────────────

/// The colour of one product's plate, and of the object standing on it.
///
/// Everything is derived from a single hue so a catalogue of forty
/// objects still reads as one shop: the field is that hue held down to
/// a studio-backdrop saturation, the floor is the same hue darkened,
/// and the object is a warm off-white lit from the upper left. Only
/// [accent] is allowed to leave the family.
class PlateTone {
  const PlateTone({
    required this.hue,
    required this.wallTop,
    required this.wallBottom,
    required this.floor,
    required this.object,
    required this.objectShade,
    required this.accent,
    required this.dark,
  });

  final double hue;

  /// The backdrop, top and bottom. A studio wall is never one colour.
  final Color wallTop;
  final Color wallBottom;

  /// The surface the object stands on, and the shadow it casts there.
  final Color floor;

  /// The lit and unlit sides of the object itself.
  final Color object;
  final Color objectShade;

  /// The one thing on the plate that is not in the hue family.
  final Color accent;

  /// Whether type over this plate has to be white. Plates run mid-tone
  /// by design, so this is close, and it is measured rather than
  /// guessed — see [_luminance].
  final bool dark;

  /// The whole family from one hue.
  factory PlateTone.of(double hue) {
    Color hsl(double h, double s, double l) =>
        HSLColor.fromAHSL(1, h % 360, s, l).toColor();

    // Warm hues carry more saturation before they go lurid; the greens
    // and blues need less of it to read as strongly coloured.
    final double warmth =
        0.5 + 0.5 * math.cos((hue - 35) * math.pi / 180).clamp(-1.0, 1.0);
    final double sat = 0.30 + 0.16 * warmth;
    final double light = 0.63 - 0.07 * warmth;

    final Color wallTop = hsl(hue + 6, sat * 0.92, light + 0.07);
    final Color wallBottom = hsl(hue - 4, sat, light - 0.04);
    final Color floor = hsl(hue - 10, sat * 1.05, light - 0.15);

    return PlateTone(
      hue: hue,
      wallTop: wallTop,
      wallBottom: wallBottom,
      floor: floor,
      // The object is paper-coloured, pulled a few degrees toward the
      // wall so it sits in the room instead of on top of it.
      object: hsl(hue + 14, 0.16, 0.93),
      objectShade: hsl(hue + 2, 0.20, 0.74),
      accent: hsl(hue + 165, 0.55, 0.46),
      dark: _luminance(wallBottom) < 0.52,
    );
  }

  /// Type colour that survives this plate.
  Color get onPlate => dark ? const Color(0xFFFBF9F6) : kInk;

  Color get onPlateSoft =>
      dark ? const Color(0xB8FBF9F6) : const Color(0xB01A1714);
}

double _luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

// ── The material ─────────────────────────────────────────────

/// The one glass in the app.
///
/// It is a *light* glass — a white tint over saturated plates rather
/// than a dark one over a dark page — so the numbers are not Aurora's:
/// the tint carries most of the surface, the blur stays low so the
/// plate behind it is still legibly a shape, and the rim runs bright.
LiquidGlassStyle vitrineGlass({
  double radius = 26,
  Color tint = const Color(0x4DFFFFFF),
  double blur = 7,
  double distortion = 0.10,
  double distortionWidth = 28,
  double borderWidth = 1.0,
  double lightIntensity = 1.0,
  double lightDirection = 68,
  double saturation = 1.22,
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
        borderSaturation: 1.15,
        ambientIntensity: 0.9,
        borderSolidity: 0.85,
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

/// The chrome material — the top bar and the tab bar, which are the
/// only two lenses on screen at once for most of the app.
///
/// Thinner and less distorting than a panel's: chrome spends its life
/// over moving content, and a heavy lens there smears rather than
/// refracts. The shadow is what lifts it off a *light* page — on paper
/// there is no darkness for a rim alone to separate against.
LiquidGlassStyle vitrineChrome({double radius = 28}) => vitrineGlass(
      radius: radius,
      tint: const Color(0x59FFFFFF),
      blur: 9,
      distortion: 0.07,
      distortionWidth: 24,
      borderWidth: 0.9,
      shadow: const LiquidGlassShadow(blur: 18, opacity: 0.14),
    );

/// The same rim, without the glass under it.
///
/// [LiquidGlassLite] reads an ordinary [LiquidGlassShape] exactly as a
/// lens does, so this is [vitrineGlass]'s border and nothing else, drawn
/// from a triangle mesh: no fragment shader, no warm-up, and no read of
/// what is behind it. Every rim inside a page is this, which is why a
/// product plate can carry four of them and the bars still have the
/// whole lens budget to themselves.
LiquidGlassShape vitrineRim({
  double radius = 22,
  double borderWidth = 1.0,
  double lightIntensity = 1.0,
  double lightDirection = 68,
}) {
  return LiquidGlassShape.continuousRoundedRectangle(
    cornerRadius: radius,
    borderWidth: borderWidth,
    lightIntensity: lightIntensity,
    lightDirection: lightDirection,
    borderType: const OpticalBorder(
      borderSaturation: 1.15,
      ambientIntensity: 0.9,
      borderSolidity: 0.85,
    ),
  );
}

// ── Type ─────────────────────────────────────────────────────

/// Editorial display: light weight, tight tracking, set large. Shop
/// headings and prices that are meant to be read as a statement.
const TextStyle kDisplay = TextStyle(
  fontSize: 40,
  height: 1.02,
  fontWeight: FontWeight.w300,
  letterSpacing: -1.7,
  color: kInk,
);

const TextStyle kTitle = TextStyle(
  fontSize: 16.5,
  height: 1.25,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.25,
  color: kInk,
);

const TextStyle kBody = TextStyle(
  fontSize: 13.5,
  height: 1.45,
  fontWeight: FontWeight.w400,
  color: kInkSoft,
);

/// The small tracked line above a section — a shop's quietest voice,
/// and the one that appears most often.
const TextStyle kEyebrow = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.9,
  color: kInkFaint,
);

/// Prices are tabular in spirit: same weight as a title, wider tracking,
/// never bold. A bold price reads as a discount.
const TextStyle kPrice = TextStyle(
  fontSize: 14.5,
  height: 1.2,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
  color: kInk,
);

/// Money, the way the shop writes it.
String money(int cents) {
  final int whole = cents ~/ 100;
  final int rest = cents % 100;
  final String digits = whole.toString();
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return rest == 0
      ? '£$grouped'
      : '£$grouped.${rest.toString().padLeft(2, '0')}';
}
