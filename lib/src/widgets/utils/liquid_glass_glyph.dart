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

  /// Whether this layer is the copy drawn **inside the moving selection
  /// pill** — the one the pill reveals as it travels. Always `false` on
  /// hosts with no moving pill, and on the outside-the-pill copy.
  ///
  /// Both copies are drawn for **every** tab each frame, so this is
  /// `true` for all of them on that layer; the pill's clip decides which
  /// is actually visible, exactly as it does for [selected]. Use it to
  /// give the revealed art its own treatment — a larger glyph under the
  /// glass, say — rather than only its own colour.
  ///
  /// Whatever it returns is still boxed to [size], so a bigger size only
  /// survives if the host's `iconSize` (or `labelFontSize`) is at least
  /// that large. The box is what keeps the two copies laid out
  /// identically, which is what lets the pill's clip cut between them
  /// without the art stepping at the seam.
  final bool underPill;

  const LiquidGlassGlyph({
    required this.color,
    required this.size,
    this.selected = false,
    this.underPill = false,
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
  bool underPill = false,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: builder(
        context,
        LiquidGlassGlyph(
          color: color,
          size: size,
          selected: selected,
          underPill: underPill,
        ),
      ),
    ),
  );
}

/// Builds a tab's **label**, anywhere the package would otherwise draw
/// its plain `Text`.
///
/// Handed the same [LiquidGlassGlyph] the icon builder gets — same
/// resolved [LiquidGlassGlyph.color], same [LiquidGlassGlyph.selected],
/// same [LiquidGlassGlyph.underPill] — so a label can follow its icon
/// into the pill instead of being the one part that cannot react.
/// [LiquidGlassGlyph.size] carries the resolved **font size** for the
/// layer rather than an icon box.
///
/// ```dart
/// labelBuilder: (context, l) => Text(
///   'Home',
///   style: TextStyle(
///     fontSize: l.underPill ? 12 : 10,
///     color: l.color,
///   ),
/// )
/// ```
typedef LiquidGlassLabelBuilder = Widget Function(
  BuildContext context,
  LiquidGlassGlyph label,
);

/// The line box a custom label is fitted into, as a multiple of the
/// resolved font size.
///
/// Labels need the same fixed box the glyphs get, and for the same
/// reason: the inside- and outside-the-pill copies of a tab must lay out
/// identically or the reveal steps at the seam. A label free to change
/// its font size would change its cell's height with it and drag the
/// icon above it along. Comfortably clears a line of text at the box's
/// font size, so a label that does not grow is never scaled.
const double kLiquidGlassLabelLineBox = 1.45;

/// Runs [builder] and **boxes** the result to one line at [fontSize],
/// scaling down anything larger — the label counterpart of
/// [liquidGlassBoxedGlyph].
Widget liquidGlassBoxedLabel(
  BuildContext context,
  LiquidGlassLabelBuilder builder, {
  required Color color,
  required double fontSize,
  bool selected = false,
  bool underPill = false,
}) {
  return SizedBox(
    height: fontSize * kLiquidGlassLabelLineBox,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: builder(
        context,
        LiquidGlassGlyph(
          color: color,
          size: fontSize,
          selected: selected,
          underPill: underPill,
        ),
      ),
    ),
  );
}
