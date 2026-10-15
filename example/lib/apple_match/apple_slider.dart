import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_style.dart';
import 'apple_match_tuning.dart';

/// A slider tuned to read like iOS 26's `UISlider`.
class AppleSlider extends StatelessWidget {
  const AppleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 300,
    this.activeColor,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Length of the track, end to end, like a `UISlider` frame. The
  /// widget is wider by the room the lifted thumb needs at each end.
  final double width;
  final Color? activeColor;

  static const LiquidGlassLensMotionSpec motion = LiquidGlassLensMotionSpec();

  /// The layout whose track is [trackWidth] long.
  static LiquidGlassSliderLayout layoutFor(double trackWidth) {
    final LiquidGlassSliderLayout base = LiquidGlassSliderLayout(
      trackHeight: AppleMatchTuning.d('slider.trackHeight'),
      thumbWidth: AppleMatchTuning.d('slider.thumbWidth'),
      thumbHeight: AppleMatchTuning.d('slider.thumbHeight'),
    );
    final double inset = base.resolveHorizontalInset(motion.maxDeformation);
    return base.copyWith(width: trackWidth + inset * 2);
  }

  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    return LiquidGlassSlider(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ?? AppleMatchTuning.c('slider.active'),
      inactiveColor: AppleMatchTuning.c(
          dark ? 'slider.inactiveDark' : 'slider.inactiveLight'),
      layout: layoutFor(width),
      style: tunedStyle('slider', brightness),
    );
  }
}
