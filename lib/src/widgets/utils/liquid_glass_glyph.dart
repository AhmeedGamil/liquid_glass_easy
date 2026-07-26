import 'package:flutter/material.dart';

/// Everything a [LiquidGlassGlyphBuilder] needs to draw one glyph in the
/// state its host is currently rendering it.
///
/// [color] is the **already resolved** color a plain `Icon` would have
/// received for this exact layer — the item style's selected/unselected
/// color, the action's foreground, the tile's glyph color. Tint with it
/// and custom art follows every state change the built-in icons follow,
/// including the nav bar's moving-pill reveal.
@immutable
class LiquidGlassGlyph {
  /// The color this glyph should paint in for this layer/frame.
  final Color color;

  /// The box the glyph is laid out in. Content larger than this is
  /// scaled down; it never grows its cell (hosts derive their layout —
  /// and, on the nav bar, the moving pill's rect — from their own
  /// numbers, not from the glyph).
  final double size;

  /// Whether this layer draws the host's selected/active state. Always
  /// `false` on hosts that have no such state (an app icon, a dock
  /// entry).
  final bool selected;

  const LiquidGlassGlyph({
    required this.color,
    required this.size,
    this.selected = false,
  });
}

/// Builds custom glyph content — an SVG, a PNG, a `CustomPaint`, a badge
/// — anywhere the package would otherwise draw an [Icon].
///
/// Called **once per rendered layer**, so on the nav bar's glass-pill
/// tier it runs for both the inside-the-pill and outside-the-pill passes
/// of the same tab, each with its own [LiquidGlassGlyph.color] and
/// [LiquidGlassGlyph.selected].
///
/// ```dart
/// iconBuilder: (context, i) => SvgPicture.asset(
///   i.selected ? 'assets/home_fill.svg' : 'assets/home.svg',
///   width: i.size,
///   height: i.size,
///   colorFilter: ColorFilter.mode(i.color, BlendMode.srcIn),
/// )
/// ```
///
/// Multi-color art can simply ignore the color and stay as authored.
typedef LiquidGlassGlyphBuilder = Widget Function(
  BuildContext context,
  LiquidGlassGlyph glyph,
);

/// Placeholder stored in the `icon` field by every `.custom` constructor
/// in the package. Never rendered — a host with a glyph builder always
/// draws the builder's widget instead. Kept `const` so
/// `--tree-shake-icons` still works.
const IconData kLiquidGlassCustomGlyph =
    IconData(0xe000, fontFamily: 'MaterialIcons');

/// Runs [builder] and **boxes** the result to [size], scaling down
/// anything larger.
///
/// The box is what keeps custom content from disturbing its host: the
/// bars compute their cell layout — and the glass-pill bar its moving
/// pill's rect — from their layout numbers, so a glyph that could grow
/// its cell would desync the reveal from the icon it reveals.
Widget liquidGlassBoxedGlyph(
  BuildContext context,
  LiquidGlassGlyphBuilder builder, {
  required Color color,
  required double size,
  bool selected = false,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: builder(
        context,
        LiquidGlassGlyph(color: color, size: size, selected: selected),
      ),
    ),
  );
}
