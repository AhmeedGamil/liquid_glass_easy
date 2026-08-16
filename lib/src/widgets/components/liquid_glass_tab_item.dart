import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_touch.dart';
import '../utils/liquid_glass_glyph.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// Description of a single tab in [LiquidGlassTabBar].
class LiquidGlassTabBarItem {
  /// Icon shown when the tab is unselected. Ignored when [iconBuilder]
  /// is set — and may be left `null` when the builder draws the tab
  /// entirely.
  final IconData? icon;

  /// Icon shown when the tab is selected (defaults to [icon]). Ignored
  /// when [iconBuilder] is set — the builder gets the selected state
  /// instead and picks its own art.
  final IconData? selectedIcon;

  /// Optional label below the icon. When `null` the tab renders icon
  /// only, matching the modern liquid-glass minimal style.
  final String? label;

  /// Draws the glyph instead of [icon] — for artwork Flutter's [Icon]
  /// can't render (SVG, PNG, a `CustomPaint`, a badge). Honored by every
  /// tier: the plain bar, the sliding bar, the glass-pill bar and the
  /// tab bar.
  ///
  /// The builder receives the resolved color for the layer being drawn
  /// and whether that layer is the selected one, so tinting with
  /// [LiquidGlassGlyph.color] and switching art on
  /// [LiquidGlassGlyph.selected] reproduces exactly what `icon` +
  /// `selectedIcon` do — including the moving pill's reveal.
  ///
  /// ```dart
  /// LiquidGlassTabBarItem(
  ///   label: 'Home',
  ///   iconBuilder: (_, i) => SvgPicture.asset(
  ///     i.selected ? 'assets/home_fill.svg' : 'assets/home.svg',
  ///     width: i.size,
  ///     height: i.size,
  ///     colorFilter: ColorFilter.mode(i.color, BlendMode.srcIn),
  ///   ),
  /// )
  /// ```
  final LiquidGlassGlyphBuilder? iconBuilder;

  /// Draws the label instead of the plain [Text] built from [label] —
  /// for a custom font, rich text, a badge row. Honored by every tier,
  /// like [iconBuilder].
  ///
  /// The builder receives the resolved color, font size and weight for
  /// the layer being drawn (see [LiquidGlassLabel.textStyle]), so a
  /// custom label follows every state change the built-in labels follow
  /// — including the moving pill's reveal. [label] may still be set as
  /// the text to render, or left `null` for builder-only content.
  final LiquidGlassLabelBuilder? labelBuilder;

  const LiquidGlassTabBarItem({
    this.icon,
    this.selectedIcon,
    this.label,
    this.iconBuilder,
    this.labelBuilder,
  }) : assert(icon != null || iconBuilder != null,
            'Give the tab a glyph: an icon or an iconBuilder.');

  /// Whether this tab renders a label line at all — a [label] string, a
  /// [labelBuilder], or both.
  bool get hasLabel => label != null || labelBuilder != null;
}

/// Builds one tab glyph for any nav/tab tier: the item's
/// [LiquidGlassTabBarItem.iconBuilder] when it has one, else the plain
/// [Icon] — the single place either form becomes a widget, so no tier
/// can drift from another.
Widget buildLiquidGlassNavGlyph(
  BuildContext context,
  LiquidGlassTabBarItem item, {
  required Color color,
  required double size,
  required bool selected,
  bool underGlass = false,
}) {
  final LiquidGlassGlyphBuilder? builder = item.iconBuilder;
  if (builder == null) {
    return Icon(
      selected ? (item.selectedIcon ?? item.icon) : item.icon,
      size: size,
      color: color,
    );
  }
  return liquidGlassBoxedGlyph(context, builder,
      color: color, size: size, selected: selected, underGlass: underGlass);
}

/// Builds one tab label for any nav/tab tier: the item's
/// [LiquidGlassTabBarItem.labelBuilder] when it has one, else the plain
/// [Text] — the single place either form becomes a widget, so no tier
/// can drift from another. Only call when [LiquidGlassTabBarItem.hasLabel].
Widget buildLiquidGlassNavLabel(
  BuildContext context,
  LiquidGlassTabBarItem item, {
  required Color color,
  required double fontSize,
  required FontWeight fontWeight,
  required bool selected,
  bool underGlass = false,
}) {
  final LiquidGlassLabelBuilder? builder = item.labelBuilder;
  final label = LiquidGlassLabel(
    text: item.label,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    selected: selected,
    underGlass: underGlass,
  );
  if (builder == null) {
    return Text(item.label!, style: label.textStyle);
  }
  return builder(context, label);
}

/// Companion floating action button rendered as its own liquid-glass
/// pill, mirroring the pattern of pairing a tab bar with a separate,
/// side-floating action (often Search).
class LiquidGlassTabBarAction extends StatelessWidget {
  const LiquidGlassTabBarAction({
    super.key,
    this.icon,
    this.onTap,
    this.foregroundColor = Colors.white,
    this.size = 56,
    this.style,
    this.visibility = true,
    this.child,
    this.touch,
  }) : assert(icon != null || child != null,
            'Give the action something to show: an icon or a child.');

  /// The action glyph. Ignored when [child] is set.
  final IconData? icon;

  /// Custom content replacing [icon]. Centered in the button and scaled
  /// down when it exceeds it, so it never sizes the button — that stays
  /// a [size]-diameter circle and the lens geometry holds.
  ///
  /// A bare `Icon`/`Text` inside it inherits [foregroundColor]; give the
  /// widget its own color (or an `SvgPicture` its own `colorFilter`) to
  /// paint it yourself.
  final Widget? child;

  /// Tap callback.
  final VoidCallback? onTap;

  /// Color of the glyph.
  final Color foregroundColor;

  /// Diameter of the circular button.
  final double size;

  /// The action's glass look as one [LiquidGlassStyle] (shape + appearance
  /// + refraction), taken as the complete look. When null the tuned
  /// [defaultStyle] is used; its `shape` may be null, in which case a
  /// circular pill mirroring the bottom-nav capsule rim is used. To tweak
  /// one facet while keeping the rest, compose with `copyWith`, e.g.
  /// `style: LiquidGlassTabBarAction.defaultStyle.copyWith(...)`.
  final LiquidGlassStyle? style;

  /// Whether the button is shown; toggling animates the glass in/out.
  final bool visibility;

  /// Makes the button deform under touch without moving it — press and it
  /// swells, drag and it elongates along the pull, then springs back. See
  /// [LiquidGlassTouch]; `null` (the default) disables it entirely.
  final LiquidGlassTouch? touch;

  static const LiquidGlassAppearance _defaultAppearance =
      LiquidGlassAppearance(
    // Transparent body — let the refraction speak for itself.
    blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
  );

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.07,
    distortionWidth: 28,
    chromaticAberration: 0.002,
  );

  /// The tuned default look — a transparent body over a soft optical
  /// refraction. Its `shape` is `null`: the action derives a circular pill
  /// when [style] supplies no shape. Compose with `copyWith` to tweak one
  /// facet, e.g. `style: LiquidGlassTabBarAction.defaultStyle.copyWith(...)`.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);
    final LiquidGlassShape effectiveShape = resolved.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: size / 2,
          borderWidth: 1.2,
          lightIntensity: 1.1,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        );

    return SizedBox(
      width: size,
      height: size,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: resolved.appearance,
          refraction: resolved.refraction,
        ),
        visibility: visibility,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              // Boxed: the loose constraints from [Center] plus a
              // scale-down keep custom content inside the circle instead
              // of letting it drive the button's size.
              child: child == null
                  ? Icon(icon, color: foregroundColor, size: size * 0.46)
                  : IconTheme.merge(
                      data: IconThemeData(
                          color: foregroundColor, size: size * 0.46),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: foregroundColor),
                        child: FittedBox(fit: BoxFit.scaleDown, child: child),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
