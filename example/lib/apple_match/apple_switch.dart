import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_style.dart';
import 'apple_match_tuning.dart';

/// A switch tuned to read like iOS 26's `UISwitch`.
class AppleSwitch extends StatelessWidget {
  const AppleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    return LiquidGlassSwitch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ??
          AppleMatchTuning.c(dark ? 'switch.activeDark' : 'switch.activeLight'),
      inactiveColor: AppleMatchTuning.c(
          dark ? 'switch.inactiveDark' : 'switch.inactiveLight'),
      style: tunedStyle('switch', brightness),
      layout: LiquidGlassSwitchLayout(
        overshootRoom: AppleMatchTuning.d('switch.overshootRoom'),
      ),
    );
  }
}
