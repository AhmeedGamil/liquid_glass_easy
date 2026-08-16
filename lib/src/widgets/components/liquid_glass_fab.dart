import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_shadow.dart';

/// A floating action button (FAB) rendered as liquid glass.
///
/// Supports standard circular FABs, custom child FABs, and extended FABs
/// with an icon and label via [LiquidGlassFab.extended].
///
/// Drop it anywhere in your layout or pass it to `LiquidGlassScaffold`'s
/// `floatingActionButton` slot.
///
/// ```dart
/// LiquidGlassFab(
///   icon: Icons.add,
///   onPressed: () {},
/// )
///
/// LiquidGlassFab.extended(
///   icon: Icons.edit,
///   label: const Text('Compose'),
///   onPressed: () {},
/// )
/// ```
class LiquidGlassFab extends StatelessWidget {
  /// Standard FAB constructor (circular or custom child).
  const LiquidGlassFab({
    super.key,
    this.icon,
    this.child,
    this.onPressed,
    this.size = 56.0,
    this.padding = const EdgeInsets.all(16),
    this.style,
    this.visibility = true,
    this.foregroundColor = Colors.white,
    this.iconSize = 24.0,
    this.heroTag,
    this.tooltip,
  })  : label = null,
        height = null,
        width = null,
        isExtended = false,
        assert(icon != null || child != null, 'Either icon or child must be provided.');

  /// Extended FAB constructor with label and optional icon.
  const LiquidGlassFab.extended({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    double this.height = 48.0,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.style,
    this.visibility = true,
    this.foregroundColor = Colors.white,
    this.iconSize = 20.0,
    this.heroTag,
    this.tooltip,
  })  : child = null,
        size = height,
        isExtended = true;

  /// Optional icon for regular or extended FAB.
  final IconData? icon;

  /// Custom child widget inside standard FAB.
  final Widget? child;

  /// Label widget for extended FAB.
  final Widget? label;

  /// Tap callback.
  final VoidCallback? onPressed;

  /// Size (diameter) of standard circular FAB.
  final double size;

  /// Explicit height for extended FAB.
  final double? height;

  /// Explicit width for extended FAB.
  final double? width;

  /// Inner padding around icon/label.
  final EdgeInsetsGeometry padding;

  /// Glass look descriptor (shape + appearance + refraction).
  final LiquidGlassStyle? style;

  /// Whether the FAB is shown; toggling animates glass in/out.
  final bool visibility;

  /// Foreground color for icon/text.
  final Color foregroundColor;

  /// Icon size.
  final double iconSize;

  /// Optional Hero tag for route transitions.
  final Object? heroTag;

  /// Optional tooltip string.
  final String? tooltip;

  /// Whether this is an extended FAB layout.
  final bool isExtended;

  static const LiquidGlassAppearance _defaultAppearance = LiquidGlassAppearance(
    color: Color(0x1CFFFFFF), // white, alpha 28
    blur: LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    // The contact shadow rides the appearance, like every lens's; hand
    // over an appearance carrying none to drop it.
    shadow: LiquidGlassShadow(blur: 9, opacity: 0.25),
  );

  static const LiquidGlassRefraction _defaultRefraction = LiquidGlassRefraction(
    distortion: 0.08,
    distortionWidth: 28,
    chromaticAberration: 0.002,
  );

  /// The tuned default look for liquid glass FAB.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);

    final double effectiveHeight = isExtended ? (height ?? 48.0) : size;
    final double? effectiveWidth = isExtended ? width : size;

    final LiquidGlassShape effectiveShape = resolved.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: effectiveHeight / 2,
          borderWidth: 1.2,
          lightIntensity: 1.2,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.3,
            ambientIntensity: 1.0,
            borderSolidity: 0.4,
          ),
        );

    Widget content;
    if (child != null) {
      content = child!;
    } else if (isExtended) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foregroundColor, size: iconSize),
            const SizedBox(width: 8),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(
              color: foregroundColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
            child: label!,
          ),
        ],
      );
    } else {
      content = Icon(icon, color: foregroundColor, size: iconSize);
    }

    Widget result = SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: resolved.appearance,
          refraction: resolved.refraction,
        ),
        visibility: visibility,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            liquidGlassClipCornerRadius(effectiveShape),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(effectiveShape),
            ),
            onTap: onPressed,
            child: Padding(
              padding: padding,
              child: Center(
                widthFactor: effectiveWidth == null ? 1.0 : null,
                heightFactor: 1.0,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      result = Tooltip(message: tooltip, child: result);
    }

    if (heroTag != null) {
      result = Hero(tag: heroTag!, child: result);
    }

    return result;
  }
}

/// Alias for [LiquidGlassFab].
typedef LiquidGlassFloatingActionButton = LiquidGlassFab;
