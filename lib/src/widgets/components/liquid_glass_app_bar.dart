import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';
import '../utils/liquid_glass_touch.dart';

/// A floating, drop-in liquid-glass **app bar** — a translucent bar with
/// an optional [leading] widget, a [title], and trailing [actions], all
/// refracting the content behind it.
///
/// Place it wherever you want the bar to sit (a top-aligned `Stack`
/// child, the `appBar:` slot of a `LiquidGlassScaffold`, …). It is a
/// single [LiquidGlassLens] around its content, so on Impeller it works
/// standalone and on Skia / Web it needs an ancestor `LiquidGlassView`
/// with a background.
///
/// ```dart
/// LiquidGlassScaffold(
///   appBar: LiquidGlassAppBar(
///     leading: const Icon(Icons.menu),
///     title: const Text('Gallery'),
///     actions: const [Icon(Icons.search), Icon(Icons.more_vert)],
///   ),
///   body: myPageContent,
/// )
/// ```
///
/// Styling uses the [LiquidGlassLens] vocabulary — [shape], [appearance],
/// [refraction] — each defaulted to a tuned glass. Foreground color is
/// applied to icons and text through an [IconTheme] / [DefaultTextStyle],
/// so a plain `Icon(...)` or `Text(...)` automatically picks up
/// [foregroundColor].
class LiquidGlassAppBar extends StatelessWidget {
  const LiquidGlassAppBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const [],
    this.centerTitle = true,
    this.height = 56,
    this.width = 360,
    this.horizontalPadding = 14,
    this.actionSpacing = 8,
    this.style,
    this.visibility = true,
    this.foregroundColor = Colors.white,
    this.fontSize = 18,
    this.touch,
  });

  /// Leading widget (typically a menu or back button), shown at the
  /// start of the bar.
  final Widget? leading;

  /// The bar's title. Usually a [Text]; inherits [foregroundColor] and a
  /// semi-bold style unless the widget overrides it.
  final Widget? title;

  /// Trailing widgets (search, overflow menu, avatar, …), laid out at
  /// the end of the bar in order.
  final List<Widget> actions;

  /// Whether the [title] is centered. When `false` the title is
  /// left-aligned next to the [leading] widget (Material style).
  final bool centerTitle;

  /// Bar height; also drives the default pill radius (`height / 2`).
  final double height;

  /// Explicit width. When null the bar hugs its content. Defaults to a
  /// wide floating capsule.
  final double? width;

  /// Horizontal padding between the bar rim and its content.
  final double horizontalPadding;

  /// Spacing between the action widgets.
  final double actionSpacing;

  /// The bar's glass look as one [LiquidGlassStyle] (shape + appearance +
  /// refraction), taken as the complete look. When null the tuned
  /// [defaultStyle] is used. Its `shape` may be null, in which case a full
  /// pill with a tuned optical border is used. To tweak one facet while
  /// keeping the rest of the tuned look, compose with `copyWith`, e.g.
  /// `style: LiquidGlassAppBar.defaultStyle.copyWith(...)`.
  final LiquidGlassStyle? style;

  /// Whether the bar is shown; toggling animates the glass in/out.
  final bool visibility;

  /// How the bar answers a finger — see [LiquidGlassTouch].
  ///
  /// With a [LiquidGlassTouch.flex] the whole bar deforms as one body under
  /// a press or a drag, then springs back. The bar does not move.
  ///
  /// `null` (the default) leaves the glass rigid — no gesture listener, no
  /// ticker, nothing added to the tree. A bar is a large surface, so prefer
  /// a restrained spec such as [LiquidGlassFlex.subtle] if you enable it.
  final LiquidGlassTouch? touch;

  /// Color applied to icons and text inside the bar.
  final Color foregroundColor;

  /// Font size of the [title] when it is a plain [Text].
  final double fontSize;

  static const LiquidGlassAppearance _defaultAppearance =
      LiquidGlassAppearance(
    color: Color(0x1CFFFFFF), // white, alpha 28
    blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
  );

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.07,
    distortionWidth: 28,
    chromaticAberration: 0.002,
  );

  /// The tuned default look — a faint white frost over a soft optical
  /// refraction. Its `shape` is `null`: the bar derives a height-tracking
  /// full pill with an optical border when [style] supplies no shape.
  /// Compose with `copyWith` to tweak one facet, e.g.
  /// `style: LiquidGlassAppBar.defaultStyle.copyWith(...)`.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);
    final LiquidGlassShape effectiveShape = resolved.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: height / 2,
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
      width: width,
      height: height,
      child: LiquidGlassLens(
        touch: touch,
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: resolved.appearance,
          refraction: resolved.refraction,
        ),
        visibility: visibility,
        child: _AppBarContent(
          leading: leading,
          title: title,
          actions: actions,
          centerTitle: centerTitle,
          horizontalPadding: horizontalPadding,
          actionSpacing: actionSpacing,
          foregroundColor: foregroundColor,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// Crisp content layer (leading + title + actions) drawn on top of
/// the [LiquidGlassAppBar] capsule, inside the lens `child` so it is
/// clipped to the bar and stays sharp.
class _AppBarContent extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;
  final bool centerTitle;
  final double horizontalPadding;
  final double actionSpacing;
  final Color foregroundColor;
  final double fontSize;

  const _AppBarContent({
    required this.leading,
    required this.title,
    required this.actions,
    required this.centerTitle,
    required this.horizontalPadding,
    required this.actionSpacing,
    required this.foregroundColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    // Theme icons + text so a bare Icon()/Text() inherits the bar's
    // foreground color without the caller having to set it.
    final Widget content = IconTheme.merge(
      data: IconThemeData(color: foregroundColor, size: 24),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          // The app bar floats as a glass overlay with no Material
          // ancestor, so the ambient DefaultTextStyle is Flutter's
          // fallback — which paints a yellow double underline. Clear it
          // explicitly (merge keeps the parent's decoration otherwise).
          decoration: TextDecoration.none,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: centerTitle ? _centered() : _leftAligned(),
        ),
      ),
    );
    return content;
  }

  Widget _trailing() {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i != 0) SizedBox(width: actionSpacing),
          actions[i],
        ],
      ],
    );
  }

  // Title pinned to the true center of the bar, with leading at the
  // start and actions at the end, each in its own [Positioned]-like
  // slot so the title stays centered regardless of their widths.
  Widget _centered() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (title != null) Center(child: title!),
        Align(
          alignment: Alignment.centerLeft,
          child: leading ?? const SizedBox.shrink(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _trailing(),
        ),
      ],
    );
  }

  // Material-style: leading, then left-aligned title that expands to
  // push the actions to the end.
  Widget _leftAligned() {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: title ?? const SizedBox.shrink(),
          ),
        ),
        _trailing(),
      ],
    );
  }
}
