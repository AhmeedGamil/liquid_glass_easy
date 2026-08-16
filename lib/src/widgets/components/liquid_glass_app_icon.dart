import 'package:flutter/material.dart';

import '../utils/liquid_glass_glyph.dart';

/// A single app-icon tile drawn with a rounded-square gradient and
/// centered glyph, optionally labelled. This widget is plain
/// Material — it is meant to be placed *inside* a [LiquidGlass]
/// child (e.g. a dock or app grid) so the glass refracts whatever is
/// behind it.
class LiquidGlassAppIcon extends StatelessWidget {
  /// The icon glyph displayed at the center. Ignored when [iconBuilder]
  /// is set — and may be left `null` when the builder draws the glyph
  /// entirely.
  final IconData? icon;

  /// Optional label rendered below the icon. When `null`, only the
  /// rounded square is drawn (useful inside a tight dock).
  final String? label;

  /// Top-to-bottom gradient applied to the icon background.
  final List<Color> gradient;

  /// Color of the glyph.
  final Color foregroundColor;

  /// Size of the rounded square in logical pixels.
  final double size;

  /// Tap callback. When `null` the icon is non-interactive.
  final VoidCallback? onTap;

  /// Draws the glyph instead of [icon] — an SVG, a PNG, a `CustomPaint`.
  /// Receives [foregroundColor] and the glyph box (`size * 0.55`), and
  /// its result is boxed to that size so it never resizes the tile.
  final LiquidGlassGlyphBuilder? iconBuilder;

  const LiquidGlassAppIcon({
    super.key,
    this.icon,
    this.label,
    this.gradient = const [Color(0xFF4FB3FF), Color(0xFF1E69DE)],
    this.foregroundColor = Colors.white,
    this.size = 56,
    this.onTap,
    this.iconBuilder,
  }) : assert(icon != null || iconBuilder != null,
            'Give the tile a glyph: an icon or an iconBuilder.');

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: iconBuilder == null
          ? Icon(icon, color: foregroundColor, size: size * 0.55)
          : Center(
              child: liquidGlassBoxedGlyph(context, iconBuilder!,
                  color: foregroundColor, size: size * 0.55),
            ),
    );

    final tapped = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: tile,
      ),
    );

    if (label == null) return tapped;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tapped,
        const SizedBox(height: 6),
        Text(
          label!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
