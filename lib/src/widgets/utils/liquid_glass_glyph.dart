import 'package:flutter/material.dart';

/// Everything a [LiquidGlassGlyphBuilder] needs to draw one glyph in the
/// state its host is currently rendering it.
///
/// [color] is the **already resolved** color a plain `Icon` would have
/// received for this exact layer — the item style's selected/unselected
/// color, the action's foreground, the tile's glyph color. Tint with it
/// and custom art follows every state change the built-in icons follow,
/// including the nav bar's moving-pill reveal.
///
/// On the nav/tab bars a glyph is in one of **three states**:
///  • unselected — [selected] and [underGlass] both `false`;
///  • selected — [selected] `true`: the committed tab, whether or not
///    a pill is on it (a bar may hide its pill entirely);
///  • under glass — [underGlass] `true`: the moving **glass** pill is
///    over this layer right now — lifted on it, dragged across it, or
///    sweeping past it mid-travel. A flat pill is not glass, so the
///    static rest highlight never sets it.
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

  /// Whether the host's moving **glass** pill is over this layer right
  /// now. Stays `true` through the landing until the pill has fully
  /// shed into the static rest pill; always `false` under a flat pill,
  /// a hidden one, or on hosts that have no pill at all.
  final bool underGlass;

  const LiquidGlassGlyph({
    required this.color,
    required this.size,
    this.selected = false,
    this.underGlass = false,
  });
}

/// Everything a [LiquidGlassLabelBuilder] needs to draw one tab label in
/// the state its host is currently rendering it.
///
/// Mirrors [LiquidGlassGlyph]: [color], [fontSize] and [fontWeight] are
/// the **already resolved** values the default [Text] would have received
/// for this exact layer — the item style's selected/unselected color, its
/// per-state font size and weight. Style with them and a custom label
/// follows every state change the built-in labels follow, including the
/// nav bar's moving-pill reveal. The same three states apply: unselected,
/// [selected] (the committed tab), and [underGlass] (the moving glass
/// pill is over this layer right now — see
/// [LiquidGlassGlyph.underGlass]).
@immutable
class LiquidGlassLabel {
  /// The item's `label` string, when it has one. A builder-only item may
  /// leave it `null` and draw its own content.
  final String? text;

  /// The color this label should paint in for this layer/frame.
  final Color color;

  /// The font size the default label would use for this layer.
  final double fontSize;

  /// The font weight the default label would use for this layer.
  final FontWeight fontWeight;

  /// Whether this layer draws the host's selected/active state.
  final bool selected;

  /// Whether the host's moving glass pill is over this layer right now.
  /// See [LiquidGlassGlyph.underGlass].
  final bool underGlass;

  const LiquidGlassLabel({
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.text,
    this.selected = false,
    this.underGlass = false,
  });

  /// The [TextStyle] the default label renders with — spread it into a
  /// custom [Text] (via `copyWith`) to keep the stock look and change
  /// only what you need.
  TextStyle get textStyle =>
      TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

/// Builds custom label content — a different font, rich text, a badge
/// row — anywhere the package would otherwise draw the item's label as a
/// plain [Text].
///
/// Called **once per rendered layer**, like [LiquidGlassGlyphBuilder]:
/// on the nav bar's reveal tiers it runs for both the inside-the-pill
/// and outside-the-pill passes of the same tab, each with its own
/// resolved [LiquidGlassLabel.color] / [LiquidGlassLabel.selected]. The
/// two passes share one layout, so return the same-sized widget for both
/// states or the reveal clip will show a seam.
///
/// ```dart
/// labelBuilder: (context, l) => Text(
///   l.text ?? 'Home',
///   style: l.textStyle.copyWith(letterSpacing: 0.4),
/// )
/// ```
typedef LiquidGlassLabelBuilder = Widget Function(
  BuildContext context,
  LiquidGlassLabel label,
);

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

/// Runs [builder] and **boxes** the result to [size], scaling the
/// content to fill the box — up as well as down, aspect kept.
///
/// The box is what keeps custom content from disturbing its host: the
/// bars compute their cell layout — and the glass-pill bar its moving
/// pill's rect — from their layout numbers, so a glyph that could grow
/// its cell would desync the reveal from the icon it reveals.
///
/// Scaling to the box (rather than only shrinking oversized art) is
/// also what makes the under-glass size work for custom glyphs: when
/// the nav bar lerps the box toward `underGlassIconSize`, art drawn at
/// any fixed size rides the box instead of floating unchanged inside a
/// larger boundary.
Widget liquidGlassBoxedGlyph(
  BuildContext context,
  LiquidGlassGlyphBuilder builder, {
  required Color color,
  required double size,
  bool selected = false,
  bool underGlass = false,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: FittedBox(
      fit: BoxFit.contain,
      child: builder(
        context,
        LiquidGlassGlyph(
          color: color,
          size: size,
          selected: selected,
          underGlass: underGlass,
        ),
      ),
    ),
  );
}
