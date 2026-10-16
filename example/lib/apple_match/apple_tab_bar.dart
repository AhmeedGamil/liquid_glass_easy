import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_style.dart';
import 'apple_match_tuning.dart';

/// A tab bar tuned to read like iOS 26's floating `UITabBar`.
class AppleTabBar extends StatelessWidget {
  const AppleTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.width,
    this.height,
    this.tint,
    this.body,
    this.centerY,
  });

  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Apple's 328 x 62 when null.
  final double? width;
  final double? height;

  /// The selected tab's colour; system blue when null.
  final Color? tint;

  /// What the bar floats over. When set, the bar builds its own views and
  /// fills its parent with the moving glass pill, vertically centred;
  /// otherwise it is the plain bar inside an enclosing glass view.
  final Widget? body;

  /// Where the bar's centre sits from the top of its parent, with [body];
  /// the parent's middle when null.
  final double? centerY;

  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    final double h = height ?? AppleMatchTuning.d('tab.height');
    final FontWeight weight = AppleMatchTuning.w('tab.labelWeight');
    final Widget? behind = body;
    if (behind == null) return _bar(brightness, dark, h, weight, 0);
    return LayoutBuilder(
      builder: (context, c) => _bar(
        brightness,
        dark,
        h,
        weight,
        (c.maxHeight - (centerY ?? c.maxHeight / 2) - h / 2)
            .clamp(0.0, double.infinity),
      ).buildGlassPillBar(body: behind),
    );
  }

  LiquidGlassTabBar _bar(
    Brightness brightness,
    bool dark,
    double h,
    FontWeight weight,
    double bottom,
  ) {
    final double barWidth = width ?? AppleMatchTuning.d('tab.width');
    final double padding = AppleMatchTuning.d('tab.itemPadding');
    return LiquidGlassTabBar(
      items: items,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      width: barWidth,
      height: h,
      margin: EdgeInsets.only(bottom: bottom),
      itemPadding: padding,
      // With a body the bar places itself from its bottom margin, which
      // only bottomCenter honours exactly.
      alignment: body == null ? Alignment.center : Alignment.bottomCenter,
      style: tunedStyle('tab', brightness),
      // The bar's glass flexes under the finger, as a lens does.
      touch: tunedTouch('tab'),
      pillStyle: LiquidGlassTabPillStyle(
        // The moving glass pill, on Impeller and Skia alike.
        mode: LiquidGlassPillMode.both,
        // How much taller than the bar the lifted glass pill stands.
        growHeight: AppleMatchTuning.d('tab.growHeight'),
        // How much wider than the resting pill the lifted one is.
        growWidth: AppleMatchTuning.b('tab.growWidthNull')
            ? null
            : AppleMatchTuning.d('tab.growWidth'),
        // The moving glass pill's own bend, separate from the bar's.
        refractionIndex: AppleMatchTuning.d('tab.pillRefIndex'),
        refractionWidth: AppleMatchTuning.d('tab.pillRefWidth'),
        // The glass pill's own zoom; Skia only, Impeller uses the magnifier.
        magnification: AppleMatchTuning.d('tab.pillMagnification'),
        dispersion: AppleMatchTuning.d('tab.pillDispersion'),
        // The bar seen under the pill, zoomed by the Impeller magnifier.
        magnifierPill: LiquidGlassTabMagnifierPillStyle(
          magnification: AppleMatchTuning.d('tab.magnifierMagnification'),
        ),
        // Lite glass for the moving pill and its magnifier. A glassStyle
        // replaces the pill's whole look, so it restates the defaults.
        glassStyle: AppleMatchTuning.b('tab.pillLite')
            ? LiquidGlassStyle(
                color: Colors.transparent,
                blur: 0,
                refractionIndex: AppleMatchTuning.d('tab.pillRefIndex'),
                refractionWidth: AppleMatchTuning.d('tab.pillRefWidth'),
                magnification: AppleMatchTuning.d('tab.pillMagnification'),
                dispersion: AppleMatchTuning.d('tab.pillDispersion'),
                shadow: const LiquidGlassShadow(
                    blur: 9, opacity: 0.3, inset: 0),
                liteGlass: true,
              )
            : null,
        // Apple's pill is wider than an equal share and scales with it:
        // 1.175 x (328 - 2 x 4) / 4 = 94 pt. The end items sit half a pill
        // in from the bar's ends.
        width: AppleMatchTuning.b('tab.pillWidthNull')
            ? null
            : AppleMatchTuning.d('tab.pillWidthFactor') *
                (barWidth - 2 * padding) /
                items.length,
        // Only the resting pill is styled here. The moving glass pill and
        // its magnifier keep the shipped defaults: a continuous capsule
        // that tracks the pill's height as it lifts and grows.
        rest: LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: AppleMatchTuning.d('tab.pillRadius'),
            clipQuality: LiquidGlassClipQuality.exact,
          ),
          color: AppleMatchTuning.c('tab.pillColor'),
        ),
      ),
      itemStyle: LiquidGlassTabItemStyle(
        selectedColor: tint ??
            AppleMatchTuning.c(dark ? 'tab.selectedDark' : 'tab.selectedLight'),
        unselectedColor: dark ? Colors.white : Colors.black,
        iconSize: AppleMatchTuning.d('tab.iconSize'),
        labelFontSize: AppleMatchTuning.d('tab.labelSize'),
        underGlassIconSize: AppleMatchTuning.d('tab.underGlassIconSize'),
        underGlassLabelFontSize: AppleMatchTuning.d('tab.underGlassLabelSize'),
        iconLabelGap: 1,
        selectedFontWeight: weight,
        unselectedFontWeight: weight,
      ),
    );
  }
}
