import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Every color the Aurora app paints with, resolved for one [Brightness]
/// and one accent hue.
///
/// The app never reads raw `Colors.*` — it reads a palette. That is what
/// makes the light/dark switch a single swap instead of a hunt through
/// twelve pages, and what lets the settings page repaint the whole app
/// with a new accent.
@immutable
class AuroraPalette {
  /// Which side of the theme this palette describes.
  final Brightness brightness;

  /// The user-chosen accent, threaded through charts, pills and glass.
  final Color accent;

  /// Vertical base wash painted under the aurora blobs.
  final List<Color> canvas;

  /// The slow-drifting light fields that make the background breathe.
  final List<Color> blobs;

  /// How strongly the blobs read over the canvas.
  final double blobOpacity;

  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;

  /// Fill of an ordinary (non-lens) content card.
  final Color surface;

  /// Fill of a card that needs to sit a step closer to the reader.
  final Color surfaceStrong;

  /// Hairline that gives a surface its edge.
  final Color stroke;

  /// Tint the real glass lenses carry.
  final Color glassTint;

  /// Rim light color handed to the lens shapes.
  final Color glassLight;

  /// Drop shadow under floating elements.
  final Color shadow;

  /// Semantic accents shared by charts and status chips.
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// The categorical chart slots, in fixed order.
  ///
  /// Data color follows the *entity*, not the theme — so these do not
  /// track [accent], and a chart never re-hues when a series drops out.
  /// Both columns were stepped for their own surface and validated for
  /// colorblind separation as an adjacent pairlist; the light column
  /// sits in the 6–8 warn band, which is why every chart that uses more
  /// than one slot also direct-labels its series.
  final List<Color> series;

  /// Single-hue magnitude ramp, low → high, stepped for this surface.
  final List<Color> heat;

  const AuroraPalette._({
    required this.brightness,
    required this.accent,
    required this.canvas,
    required this.blobs,
    required this.blobOpacity,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.surface,
    required this.surfaceStrong,
    required this.stroke,
    required this.glassTint,
    required this.glassLight,
    required this.shadow,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.series,
    required this.heat,
  });

  bool get isDark => brightness == Brightness.dark;

  /// The palette for [brightness], tinted by [accent].
  factory AuroraPalette.resolve(Brightness brightness, Color accent) =>
      brightness == Brightness.dark
          ? AuroraPalette.dark(accent)
          : AuroraPalette.light(accent);

  factory AuroraPalette.dark(Color accent) => AuroraPalette._(
        brightness: Brightness.dark,
        accent: accent,
        canvas: const [Color(0xFF05070F), Color(0xFF0A0D1C), Color(0xFF0E0A1D)],
        blobs: [
          accent,
          const Color(0xFF7C5CFF),
          const Color(0xFF00D3A7),
          const Color(0xFFFF5FA2),
          const Color(0xFF2E8BFF),
        ],
        blobOpacity: 0.55,
        textPrimary: const Color(0xFFF4F6FF),
        textSecondary: const Color(0xFFA6AFCB),
        textFaint: const Color(0x66FFFFFF),
        surface: const Color(0x12FFFFFF),
        surfaceStrong: const Color(0x1FFFFFFF),
        stroke: const Color(0x1FFFFFFF),
        glassTint: const Color(0x14FFFFFF),
        glassLight: const Color(0xB2FFFFFF),
        shadow: const Color(0xB3000000),
        success: const Color(0xFF34D399),
        warning: const Color(0xFFFBBF24),
        danger: const Color(0xFFFB7185),
        info: const Color(0xFF60A5FA),
        series: const [
          Color(0xFF7C6BE8), // violet
          Color(0xFF19A67A), // aqua
          Color(0xFFC98500), // amber
          Color(0xFFD9578A), // magenta
        ],
        heat: const [
          Color(0xFF161B2E),
          Color(0xFF272A57),
          Color(0xFF3E3B85),
          Color(0xFF5A4FB4),
          Color(0xFF7C6BE8),
          Color(0xFFA294F1),
        ],
      );

  factory AuroraPalette.light(Color accent) => AuroraPalette._(
        brightness: Brightness.light,
        accent: accent,
        canvas: const [Color(0xFFF2F5FF), Color(0xFFF8F5FF), Color(0xFFFFF0F6)],
        blobs: [
          accent,
          const Color(0xFF9B8CFF),
          const Color(0xFF5EEAD4),
          const Color(0xFFFF9FC4),
          const Color(0xFF8FC2FF),
        ],
        blobOpacity: 0.42,
        textPrimary: const Color(0xFF10142E),
        textSecondary: const Color(0xFF515A7C),
        textFaint: const Color(0x66000000),
        surface: const Color(0x8AFFFFFF),
        surfaceStrong: const Color(0xC2FFFFFF),
        stroke: const Color(0x14101430),
        glassTint: const Color(0x2EFFFFFF),
        glassLight: const Color(0xCCFFFFFF),
        shadow: const Color(0x2A121A3A),
        success: const Color(0xFF0EA47A),
        warning: const Color(0xFFD97706),
        danger: const Color(0xFFE11D48),
        info: const Color(0xFF2563EB),
        series: const [
          Color(0xFF5B4AD6), // violet
          Color(0xFF12805C), // aqua
          Color(0xFFB37400), // amber
          Color(0xFFD0407A), // magenta
        ],
        heat: const [
          Color(0xFFE9E7FB),
          Color(0xFFD1CCF4),
          Color(0xFFB2A9ED),
          Color(0xFF8F84E3),
          Color(0xFF6B5ED4),
          Color(0xFF4B3FB3),
        ],
      );

  // ── Derived colors ────────────────────────────────────────────

  /// Ink that stays legible on top of a filled [accent] surface.
  Color get onAccent =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : const Color(0xFF10142E);

  /// A muted wash of [accent], for chips and chart fills.
  Color accentWash([double alpha = 0.16]) => accent.withValues(alpha: alpha);

  /// The scrim laid over photography so text stays readable.
  List<Color> get photoScrim => isDark
      ? const [Color(0x00000000), Color(0xCC000000)]
      : const [Color(0x00000000), Color(0x99000000)];

  // ── Glass styles ──────────────────────────────────────────────

  /// The house glass: a continuous-corner lens with an optical rim,
  /// tuned per brightness so light mode doesn't wash out.
  LiquidGlassStyle glass({
    double radius = 28,
    double blur = 4,
    double distortion = 0.11,
    double distortionWidth = 26,
    Color? tint,
    double borderWidth = 1.2,
    double lightDirection = 0,
  }) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: radius,
        borderWidth: borderWidth,
        lightColor: glassLight,
        lightDirection: lightDirection,
        lightIntensity: isDark ? 1.0 : 1.25,
        borderType: OpticalBorder(
          borderSaturation: isDark ? 1.35 : 1.1,
          ambientIntensity: isDark ? 1.0 : 1.5,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: tint ?? glassTint,
        blur: LiquidGlassBlur(sigmaX: blur, sigmaY: blur),
        saturation: isDark ? 1.12 : 1.05,
      ),
      refraction: LiquidGlassRefraction(
        distortion: distortion,
        distortionWidth: distortionWidth,
        chromaticAberration: 0.0025,
      ),
    );
  }

  /// Clear, physically-refracting glass — no blur, Snell's-law bending.
  /// The look reserved for hero surfaces the eye should read *through*.
  LiquidGlassStyle opticalGlass({
    double radius = 32,
    double depth = 0.7,
    double width = 24,
    Color? tint,
  }) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.continuousRoundedRectangle(
        cornerRadius: radius,
        borderWidth: 1.4,
        lightColor: glassLight,
        borderType: OpticalBorder(
          borderSaturation: isDark ? 1.5 : 1.15,
          ambientIntensity: isDark ? 1.1 : 1.6,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: tint ?? (isDark ? const Color(0x0FFFFFFF) : glassTint),
        saturation: isDark ? 1.15 : 1.04,
        blur: LiquidGlassBlur(
            sigmaX: isDark ? 1.5 : 2.5, sigmaY: isDark ? 1.5 : 2.5),
      ),
      refraction: LiquidGlassRefraction(
        refractionType: OpticalRefraction(
          refraction: 1.5,
          refractionWidth: width,
          depth: depth,
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuroraPalette &&
      other.brightness == brightness &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(brightness, accent);
}
