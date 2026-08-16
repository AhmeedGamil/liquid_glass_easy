import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_glyph.dart';
import '../utils/liquid_glass_shape.dart';

/// A compact one-touch control tile rendered as liquid glass.
///
/// Designed for boolean toggles (Wi-Fi, Bluetooth, Airplane Mode,
/// Flashlight, etc.). The tile flips to an "on" tint when [active] is
/// true. Provide [icon], an optional [label], and an [onTap] handler —
/// the widget is stateless on purpose so the parent owns the boolean
/// state.
///
/// By default the glass tint and rim are derived from [active] /
/// [activeColor]. Pass [appearance] or [shape] to take full control.
class LiquidGlassControlTile extends StatelessWidget {
  const LiquidGlassControlTile({
    super.key,
    this.icon,
    required this.active,
    this.label,
    this.activeColor = const Color(0xFF34C759),
    this.onTap,
    this.size = 80,
    this.shape,
    this.appearance,
    this.refraction = _defaultRefraction,
    this.style,
    this.visibility = true,
    this.iconBuilder,
  }) : assert(icon != null || iconBuilder != null,
            'Give the tile a glyph: an icon or an iconBuilder.');

  /// The tile glyph. Ignored when [iconBuilder] is set — and may be
  /// left `null` when the builder draws the glyph entirely.
  final IconData? icon;

  /// Draws the glyph instead of [icon] — an SVG, a PNG, a `CustomPaint`.
  /// Receives the glyph color (white) and box (`size * 0.42`), plus
  /// [active] as the glyph's `selected` flag so the artwork can change
  /// with the tile's state. Boxed to that size, so it never resizes the
  /// tile.
  final LiquidGlassGlyphBuilder? iconBuilder;

  /// Whether the tile is in its "on" state.
  final bool active;

  /// Optional caption under the icon.
  final String? label;

  /// Tint used for the glass when [active] is true (ignored if
  /// [appearance] is set).
  final Color activeColor;

  /// Tap callback.
  final VoidCallback? onTap;

  /// Side length of the square tile.
  final double size;

  /// Glass shape + border. When null, a rounded square derived from
  /// [size] / [active] is used.
  final LiquidGlassShape? shape;

  /// The glass material. When null, it is derived from [active] /
  /// [activeColor].
  final LiquidGlassAppearance? appearance;

  /// How the glass bends light.
  final LiquidGlassRefraction refraction;

  /// Full glass look as one [LiquidGlassStyle] (shape + appearance +
  /// refraction). When non-null it supersedes the individual [shape] /
  /// [appearance] / [refraction] params — the preferred, library-wide
  /// way to style this component.
  final LiquidGlassStyle? style;

  /// Whether the tile is shown; toggling animates the glass in/out.
  final bool visibility;

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.08,
    distortionWidth: 30,
    chromaticAberration: 0.002,
  );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassShape effectiveShape = shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: size * 0.32,
          borderWidth: 1.2,
          lightIntensity: active ? 1.6 : 1.1,
          lightDirection: 60,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        );

    final LiquidGlassAppearance effectiveAppearance = appearance ??
        LiquidGlassAppearance(
          color: active
              ? activeColor.withAlpha(180)
              : Colors.white.withAlpha(30),
          blur: const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
        );

    return SizedBox(
      width: size,
      height: size,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: effectiveAppearance,
          refraction: refraction,
        ).merge(style),
        visibility: visibility,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(effectiveShape),
            ),
            onTap: onTap,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconBuilder == null)
                    Icon(icon, color: Colors.white, size: size * 0.42)
                  else
                    liquidGlassBoxedGlyph(context, iconBuilder!,
                        color: Colors.white,
                        size: size * 0.42,
                        selected: active),
                  if (label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
