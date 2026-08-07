import 'package:flutter/material.dart';

import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_jelly_config.dart';
import '../../utils/liquid_glass_shape.dart';

/// Which renderer(s) get the full iOS-26 **glass-refracting** morphing
/// pill (the dual-pipeline animated bar). See
/// [LiquidGlassBottomNavBar.glassPill] for how to opt in.
enum LiquidGlassPillMode {
  /// No glass pill — the lightweight single-lens bar (instant, or a
  /// soft sliding highlight with `animated: true`). Works everywhere.
  none,

  /// Glass-refracting morphing pill **only on Impeller**; falls back to
  /// [none] on Skia / Web.
  impellerOnly,

  /// Glass-refracting morphing pill on **both** Impeller and Skia.
  both,
}

/// **Item** group for [LiquidGlassBottomNavBar]: how each tab's icon
/// and label render. Defaults mirror the bar's flat parameters, so
/// swapping APIs is lossless.
class LiquidGlassNavItemStyle {
  /// Color of the selected item's icon + label.
  final Color selectedColor;

  /// Color of unselected items' icons + labels.
  final Color unselectedColor;

  /// Icon size for every item.
  final double iconSize;

  /// Label font size. Labels are only shown for items that provide one.
  final double labelFontSize;

  /// Vertical gap between the icon and its label, in logical pixels.
  final double iconLabelGap;

  /// Font weight of the selected item's label.
  final FontWeight selectedFontWeight;

  /// Font weight of unselected items' labels.
  final FontWeight unselectedFontWeight;

  const LiquidGlassNavItemStyle({
    this.selectedColor = Colors.white,
    this.unselectedColor = Colors.white70,
    this.iconSize = 24,
    this.labelFontSize = 10.5,
    this.iconLabelGap = 2,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedFontWeight = FontWeight.w500,
  });

  /// Resolves the icon/label color for a cell in [selected] state.
  Color colorFor({required bool selected}) =>
      selected ? selectedColor : unselectedColor;

  /// Resolves the label weight for a cell in [selected] state.
  FontWeight fontWeightFor({required bool selected}) =>
      selected ? selectedFontWeight : unselectedFontWeight;

  LiquidGlassNavItemStyle copyWith({
    Color? selectedColor,
    Color? unselectedColor,
    double? iconSize,
    double? labelFontSize,
    double? iconLabelGap,
    FontWeight? selectedFontWeight,
    FontWeight? unselectedFontWeight,
  }) {
    return LiquidGlassNavItemStyle(
      selectedColor: selectedColor ?? this.selectedColor,
      unselectedColor: unselectedColor ?? this.unselectedColor,
      iconSize: iconSize ?? this.iconSize,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      iconLabelGap: iconLabelGap ?? this.iconLabelGap,
      selectedFontWeight: selectedFontWeight ?? this.selectedFontWeight,
      unselectedFontWeight: unselectedFontWeight ?? this.unselectedFontWeight,
    );
  }
}

/// **Selection pill** group for [LiquidGlassBottomNavBar]: everything
/// about the highlight behind the active tab — its look, whether it
/// slides, and whether/where it upgrades to the glass-refracting
/// morphing pill. Defaults mirror the bar's flat parameters, so
/// swapping APIs is lossless.
///
/// The three tiers, all configured here:
///  • static highlight — the defaults ([animated] false, [mode] none);
///  • sliding highlight — [animated] true: the pill slides between tabs
///    with the iOS-26 icon-reveal, drawn inside the lens (works on
///    every renderer);
///  • glass-refracting morphing pill — [mode] other than
///    [LiquidGlassPillMode.none]: the dual-pipeline pill that refracts
///    the bar itself. The `distortion`/`growHeight`/… knobs below apply
///    to this tier only.
class LiquidGlassNavPillStyle {
  /// Which renderer(s) use the glass-refracting morphing pill.
  final LiquidGlassPillMode mode;

  /// Whether to draw the soft pill behind the selected item.
  final bool show;

  /// Color of the selection pill behind the active item.
  final Color color;

  /// When `true`, the selection pill **slides** between tabs with the
  /// iOS-26 "icon highlights through the moving pill" reveal. When
  /// `false` the selection jumps instantly.
  final bool animated;

  /// How long the pill takes to slide between tabs ([animated] only).
  final Duration animationDuration;

  /// Easing curve for the pill slide ([animated] only).
  final Curve animationCurve;

  /// Blur behind the moving **glass** pill (glass [mode]s only).
  final LiquidGlassBlur blur;

  /// How much taller the glass pill grows than the bar at the peak of a
  /// transition (glass [mode]s only) — the pill's main size knob.
  final double growHeight;

  /// Refraction strength of the moving glass pill (glass [mode]s only).
  final double distortion;

  /// Width of the glass pill's refraction band in logical pixels
  /// (glass [mode]s only).
  final double distortionWidth;

  /// Magnification of the content seen through the glass pill (glass
  /// [mode]s only). `1` = none.
  final double magnification;

  /// When `true`, the glass pill's inner area is transparent (glass
  /// [mode]s only).
  final bool enableInnerRadiusTransparent;

  /// Shape of the moving **glass** pill (glass [mode]s only). When
  /// `null` (the default) the pill is an Apple capsule-style
  /// [LiquidGlassShape] whose corner radius tracks the
  /// pill's height, so it stays a clean capsule while it grows and
  /// squashes. Supply a custom [LiquidGlassShape] — e.g. a
  /// continuous variant with a smaller `cornerRadius` for
  /// visible continuous corners, or a plain rounded variant — to
  /// change the pill's silhouette and rim.
  ///
  /// Superseded by [glassStyle]/[rest], which bundle shape + fill +
  /// refraction per pill state. When [glassStyle]/[rest] omit a shape they
  /// fall back to this one.
  final LiquidGlassShape? shape;

  /// The **moving glass pill**'s full look as one [LiquidGlassStyle]
  /// (shape + fill/blur + refraction). When non-null it supersedes the
  /// individual glass-pill fields ([shape], [blur], [distortion],
  /// [distortionWidth], [magnification], [enableInnerRadiusTransparent]);
  /// a `null` shape inside it falls back to [shape]. Glass [mode]s only.
  final LiquidGlassStyle? glassStyle;

  /// The **static rest pill**'s look as one [LiquidGlassStyle] — the
  /// non-refracting highlight shown when the glass pill is not moving
  /// (and the fill of the non-glass tiers). Its `appearance.color` is the
  /// pill's background, its `shape` the corners (falls back to [shape]),
  /// and a border is drawn **only when** the shape sets a `borderColor`
  /// (default: no border). Refraction is ignored.
  final LiquidGlassStyle? rest;

  /// Stiffness of the spring that carries the glass pill between tabs
  /// (glass [mode]s only). Higher → snappier travel. Default `320`.
  final double travelStiffness;

  /// Damping of the travel spring (glass [mode]s only). The critical
  /// (no-overshoot) value is `2·√travelStiffness` (≈ 36 at the default
  /// stiffness): below it the pill bounces, at/above it just settles.
  /// Default `30` — a faint settle.
  final double travelDamping;

  /// The pill's jelly squash/stretch tuning (glass [mode]s only) — the
  /// same unified [LiquidGlassJellyConfig] as the slider thumb and the
  /// [LiquidGlassJelly] widget. Applies to both finger-drags and
  /// tap-travel. The nav bar is **locked to the on-device-tuned iOS
  /// [LiquidGlassJellyStyle.squashStretch]** squash & stretch (dialled in for
  /// tab-scale travel): any [LiquidGlassJellyConfig.style] passed here is
  /// ignored and normalized to `squashStretch`. The pill's original
  /// `pinchExtrude` feel is kept internally (it still drives
  /// [LiquidGlassJelly]) but is no longer selectable here; all other
  /// fields are honored.
  final LiquidGlassJellyConfig jelly;

  const LiquidGlassNavPillStyle({
    this.mode = LiquidGlassPillMode.none,
    this.show = true,
    this.color = const Color(0x26FFFFFF),
    this.animated = false,
    this.animationDuration = const Duration(milliseconds: 320),
    this.animationCurve = Curves.easeOutCubic,
    this.blur = const LiquidGlassBlur(),
    this.growHeight = 12,
    this.distortion = 0.06,
    this.distortionWidth = 10,
    this.magnification = 1,
    this.enableInnerRadiusTransparent = false,
    this.shape,
    this.glassStyle,
    this.rest,
    this.travelStiffness = 280,
    this.travelDamping = 31.4,
    // On-device-tuned iOS squash & stretch (confirmed 2026-06-14). The
    // unified jelly config, dialled in via the nav_jelly_tuner for
    // tab-scale travel: a fast elongate-along-motion with a pronounced
    // cross-axis recoil on settle. `velocityClamp` is kept at the
    // tab-index scale (not exposed by the tuner).
    this.jelly = const LiquidGlassJellyConfig(
      style: LiquidGlassJellyStyle.squashStretch,
      stiffness: 260,
      damping: 13,
      maxVelocity: 6,
      velocityClamp: 60,
      stretchWidth: 17.1,
      squashHeight: 9.8,
      anchorBias: -1.0,
      recoilScale: 3.0,
      recoilAnchor: 1.0,
      directionTau: 0.42,
    ),
  });

  LiquidGlassNavPillStyle copyWith({
    LiquidGlassPillMode? mode,
    bool? show,
    Color? color,
    bool? animated,
    Duration? animationDuration,
    Curve? animationCurve,
    LiquidGlassBlur? blur,
    double? growHeight,
    double? distortion,
    double? distortionWidth,
    double? magnification,
    bool? enableInnerRadiusTransparent,
    LiquidGlassShape? shape,
    LiquidGlassStyle? glassStyle,
    LiquidGlassStyle? rest,
    double? travelStiffness,
    double? travelDamping,
    LiquidGlassJellyConfig? jelly,
  }) {
    return LiquidGlassNavPillStyle(
      mode: mode ?? this.mode,
      show: show ?? this.show,
      color: color ?? this.color,
      animated: animated ?? this.animated,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      blur: blur ?? this.blur,
      growHeight: growHeight ?? this.growHeight,
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      magnification: magnification ?? this.magnification,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
      shape: shape ?? this.shape,
      glassStyle: glassStyle ?? this.glassStyle,
      rest: rest ?? this.rest,
      travelStiffness: travelStiffness ?? this.travelStiffness,
      travelDamping: travelDamping ?? this.travelDamping,
      jelly: jelly ?? this.jelly,
    );
  }

  /// The moving glass pill's resolved look: [glassStyle] when set,
  /// otherwise built from the individual glass-pill fields (preserving the
  /// shipped defaults — a ~11% white tint and the flat refraction knobs).
  LiquidGlassStyle get effectiveGlass {
    final g = glassStyle;
    return LiquidGlassStyle(
      shape: g?.shape ?? shape,
      appearance: g?.appearance ??
          LiquidGlassAppearance(
            color: const Color(0x1CFFFFFF), // white, alpha 28
            blur: blur,
            enableInnerRadiusTransparent: enableInnerRadiusTransparent,
          ),
      refraction: g?.refraction ??
          LiquidGlassRefraction(
            distortion: distortion,
            distortionWidth: distortionWidth,
            magnification: magnification,
            chromaticAberration: 0.002,
          ),
    );
  }

  /// The static rest pill's resolved look: [rest] when set, otherwise a
  /// borderless highlight filled with [color] (the shipped ~15% white),
  /// with corners from [shape]. A border appears only when the resolved
  /// shape carries a `borderColor`.
  LiquidGlassStyle get effectiveRest {
    final r = rest;
    return LiquidGlassStyle(
      shape: r?.shape ?? shape,
      appearance: r?.appearance ?? LiquidGlassAppearance(color: color),
    );
  }
}
