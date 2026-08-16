import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';
import '../utils/liquid_glass_touch.dart';

/// A pill-shaped action button rendered as liquid glass.
///
/// This is a plain widget: drop it anywhere in your layout (a `Row`, a
/// `Column`, a `Stack`) and it renders a single [LiquidGlassLens] around
/// its label/icon. It needs no position and no `LiquidGlassView` on
/// Impeller; on Skia / Web place it inside a `LiquidGlassView` so it has
/// a background to refract.
///
/// Styling uses one [LiquidGlassStyle] ([style] — shape + appearance +
/// refraction), defaulted to a tuned iOS-style glass, so the simplest call
/// is just `label` + `onPressed`. For a solid call-to-action (e.g. a blue
/// "Continue"), pass a [style] with a colored tint — compose from
/// [defaultStyle] to keep the rest of the tuned look:
///
/// ```dart
/// LiquidGlassButton(
///   label: 'Continue',
///   style: LiquidGlassButton.defaultStyle.copyWith(
///     appearance: LiquidGlassAppearance(color: Colors.blue.withAlpha(160)),
///   ),
///   onPressed: () {},
/// )
/// ```
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.style,
    this.visibility = true,
    this.foregroundColor = Colors.white,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.iconSize = 20,
    this.touch,
    this.child,
  }) : assert(label != null || icon != null || child != null,
            'Give the button something to show: a label, an icon, or a child.');

  /// Button label text. Ignored when [child] is set.
  final String? label;

  /// Optional leading icon. Ignored when [child] is set.
  final IconData? icon;

  /// Custom content, replacing the [icon] + [label] row entirely — for
  /// anything `Icon`/`Text` can't express (SVG, PNG, a badge, a
  /// spinner). It is centered inside the button's [padding] and clipped
  /// to the glass shape; it never sizes the button, which stays on
  /// [width]/[height] so the lens geometry holds.
  ///
  /// A bare `Icon`/`Text` inside it inherits [foregroundColor],
  /// [fontSize], [fontWeight] and [iconSize], so it matches the built-in
  /// row by default. Give the widget its own color to paint it yourself.
  final Widget? child;

  /// Tap callback.
  final VoidCallback? onPressed;

  /// Explicit width. When null the button hugs its content.
  final double? width;

  /// Capsule height; also drives the default pill radius (`height / 2`).
  final double height;

  /// Inner padding around the label/icon.
  final EdgeInsetsGeometry padding;

  /// The button's glass look as one [LiquidGlassStyle] (shape +
  /// appearance + refraction), taken as the complete look. When null the
  /// tuned [defaultStyle] is used. Its `shape` may be null, in which case
  /// a full pill ([LiquidGlassShape] with radius `height / 2`) and a tuned
  /// optical border are used. To tweak one facet while keeping the rest of
  /// the tuned look, compose with `copyWith`, e.g.
  /// `style: LiquidGlassButton.defaultStyle.copyWith(...)`.
  final LiquidGlassStyle? style;

  /// Whether the button is shown; toggling animates the glass in/out.
  final bool visibility;

  /// How the button answers a finger — see [LiquidGlassTouch].
  ///
  /// With a [LiquidGlassTouch.flex] the glass deforms under the press
  /// instead of only rippling: it swells under your finger, elongates if
  /// you drag, and springs back on release. The button does not move.
  ///
  /// `null` (the default) leaves the glass rigid — no gesture listener, no
  /// ticker, nothing added to the tree.
  final LiquidGlassTouch? touch;

  /// Color of the label text and icon.
  final Color foregroundColor;

  /// Font size of the label.
  final double fontSize;

  /// Font weight of the label.
  final FontWeight fontWeight;

  /// Size of the leading [icon].
  final double iconSize;

  static const LiquidGlassAppearance _defaultAppearance =
      LiquidGlassAppearance(
    color: Color(0x1CFFFFFF), // white, alpha 28
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  );

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.07,
    distortionWidth: 24,
    chromaticAberration: 0.002,
  );

  /// The tuned default look — a faint white frost over a soft optical
  /// refraction. Its `shape` is `null`: the button derives a height-tracking
  /// full pill with an optical border when [style] supplies no shape.
  /// Compose with `copyWith` to tweak one facet, e.g.
  /// `style: LiquidGlassButton.defaultStyle.copyWith(...)`.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  /// The button's inner content: the caller's [child] when given, else
  /// the built-in icon + label row.
  ///
  /// The child path installs the foreground as *ambient* theme data
  /// rather than baking it in, so a bare `Icon`/`Text` matches the
  /// built-in row while anything carrying its own color keeps it.
  Widget _content() {
    final Widget? custom = child;
    if (custom == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foregroundColor, size: iconSize),
            if (label != null) const SizedBox(width: 8),
          ],
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                color: foregroundColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            ),
        ],
      );
    }
    return IconTheme.merge(
      data: IconThemeData(color: foregroundColor, size: iconSize),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        child: custom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);
    final LiquidGlassShape effectiveShape = resolved.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: height / 2,
          borderWidth: 1.1,
          lightIntensity: 1.2,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(effectiveShape),
            ),
            onTap: onPressed,
            child: Padding(
              padding: padding,
              child: Center(child: _content()),
            ),
          ),
        ),
      ),
    );
  }
}
