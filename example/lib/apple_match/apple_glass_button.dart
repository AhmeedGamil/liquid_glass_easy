import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_style.dart';
import 'apple_match_tuning.dart';

/// A glass button tuned to read like iOS 26's `.glass` and
/// `.glassProminent` buttons.
class AppleGlassButton extends StatelessWidget {
  const AppleGlassButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.prominent = false,
    this.tint,
    this.width,
    this.height = 44,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Solid accent fill, like `.glassProminent`.
  final bool prominent;

  /// The prominent fill, or the regular button's label colour.
  final Color? tint;

  final double? width;
  final double height;

  /// The corner radius of a labelled button; icon-only ones are circles.
  static double get cornerRadius => AppleMatchTuning.d('button.cornerRadius');

  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    final Color accent = tint ?? AppleMatchTuning.c('button.prominentFill');
    final bool round = label == null;
    final double radius = round ? height / 2 : cornerRadius;
    return LiquidGlassButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      width: round ? height : width,
      height: height,
      padding:
          round ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 18),
      fontSize: AppleMatchTuning.d('button.fontSize'),
      fontWeight: AppleMatchTuning.w('button.fontWeight'),
      iconSize: round ? height * 0.54 : 17,
      foregroundColor: prominent
          ? Colors.white
          : (tint ?? (dark ? Colors.white : Colors.black)),
      style: tunedStyle(
        'button',
        brightness,
        cornerRadius: radius,
        fill: prominent ? accent : null,
      ),
      touch: AppleMatchTuning.b('button.touch')
          ? const LiquidGlassTouch.flexing(LiquidGlassFlex())
          : null,
    );
  }
}
