import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_glyph.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_app_icon.dart';

/// Lightweight description of a single entry in [LiquidGlassDock].
class LiquidGlassDockApp {
  /// The entry's glyph. Ignored when [iconBuilder] is set.
  final IconData icon;

  final List<Color> gradient;
  final VoidCallback? onTap;

  /// Draws the glyph instead of [icon] — an SVG, a PNG, a `CustomPaint`.
  /// Boxed to the tile's glyph size so it never resizes the dock.
  final LiquidGlassGlyphBuilder? iconBuilder;

  const LiquidGlassDockApp({
    required this.icon,
    this.gradient = const [Color(0xFF4FB3FF), Color(0xFF1E69DE)],
    this.onTap,
    this.iconBuilder,
  });

  /// An entry drawn entirely by [iconBuilder] — no [IconData] needed.
  /// [icon] is filled with a placeholder that is never rendered.
  const LiquidGlassDockApp.custom({
    required LiquidGlassGlyphBuilder this.iconBuilder,
    this.gradient = const [Color(0xFF4FB3FF), Color(0xFF1E69DE)],
    this.onTap,
  }) : icon = kLiquidGlassCustomGlyph;
}

/// A horizontal dock of app icons inside a single liquid-glass blob with
/// a soft optical rim — the home-screen dock pattern popularised by iOS
/// / iPadOS.
///
/// Drop it anywhere in your layout. The dock sizes itself to its [apps].
/// Styling uses the [LiquidGlassLens] vocabulary — [shape], [appearance],
/// [refraction].
class LiquidGlassDock extends StatelessWidget {
  const LiquidGlassDock({
    super.key,
    required this.apps,
    this.iconSize = 52,
    this.spacing = 14,
    this.horizontalPadding = 14,
    this.verticalPadding = 12,
    this.shape,
    this.appearance = _defaultAppearance,
    this.refraction = _defaultRefraction,
    this.style,
    this.visibility = true,
  });

  /// The apps shown in the dock, left to right.
  final List<LiquidGlassDockApp> apps;

  /// Size of each app icon.
  final double iconSize;

  /// Gap between icons.
  final double spacing;

  /// Horizontal padding between the blob rim and the icon row.
  final double horizontalPadding;

  /// Vertical padding between the blob rim and the icon row.
  final double verticalPadding;

  /// Glass shape + border. When null, a tuned rounded-rectangle default
  /// with an optical rim is used.
  final LiquidGlassShape? shape;

  /// The glass material: tint, blur, saturation.
  final LiquidGlassAppearance appearance;

  /// How the glass bends light.
  final LiquidGlassRefraction refraction;

  /// Full glass look as one [LiquidGlassStyle] (shape + appearance +
  /// refraction). When non-null it supersedes the individual [shape] /
  /// [appearance] / [refraction] params — the preferred, library-wide
  /// way to style this component.
  final LiquidGlassStyle? style;

  /// Whether the dock is shown; toggling animates the glass in/out.
  final bool visibility;

  static const LiquidGlassShape _defaultShape = LiquidGlassShape.roundedRectangle(
    cornerRadius: 30,
    borderWidth: 1.2,
    lightIntensity: 1.2,
    lightDirection: 70,
    borderType: OpticalBorder(
      borderSaturation: 1.3,
      ambientIntensity: 1.0,
      borderSolidity: 0.4,
    ),
  );

  static const LiquidGlassAppearance _defaultAppearance =
      LiquidGlassAppearance(
    color: Color(0x1CFFFFFF), // white, alpha 28
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  );

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.08,
    distortionWidth: 36,
    chromaticAberration: 0.002,
  );

  @override
  Widget build(BuildContext context) {
    final double width = apps.length * iconSize +
        (apps.length - 1) * spacing +
        horizontalPadding * 2;
    final double height = iconSize + verticalPadding * 2;

    return SizedBox(
      width: width,
      height: height,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: shape ?? _defaultShape,
          appearance: appearance,
          refraction: refraction,
        ).merge(style),
        visibility: visibility,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < apps.length; i++) ...[
                LiquidGlassAppIcon(
                  icon: apps[i].icon,
                  iconBuilder: apps[i].iconBuilder,
                  gradient: apps[i].gradient,
                  size: iconSize,
                  onTap: apps[i].onTap,
                ),
                if (i != apps.length - 1) SizedBox(width: spacing),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
