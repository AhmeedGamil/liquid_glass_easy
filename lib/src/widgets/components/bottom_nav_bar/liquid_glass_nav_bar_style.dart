import 'package:flutter/material.dart';

import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_adaptivity.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_lens_motion.dart';
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_shadow.dart';

/// Which renderer(s) get the full iOS-26 **glass-refracting** morphing
/// pill (the dual-pipeline animated bar). See
/// [LiquidGlassTabBar.glassPill] for how to opt in.
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

/// **Item** group for [LiquidGlassTabBar]: how each tab's icon
/// and label render. Defaults mirror the bar's flat parameters, so
/// swapping APIs is lossless.
class LiquidGlassTabItemStyle {
  /// Color of the selected item's icon + label.
  final Color selectedColor;

  /// Color of unselected items' icons + labels.
  final Color unselectedColor;

  /// Icon size for every item.
  final double iconSize;

  /// Icon size for the item **under the glass** — and only there. `null`
  /// (the default) keeps [iconSize], so nothing changes unless asked.
  ///
  /// This is the **glass's** state, not the selection's: it applies
  /// while the moving glass pill is over an item — lifted on it,
  /// dragging across it, sweeping past it mid-travel — and it scales
  /// with how much of the pill still reads as glass, so as the landed
  /// pill sheds into the static rest pill the icon glides back down to
  /// [iconSize] with it instead of popping at the swap. A flat pill is
  /// not glass: the static rest highlight, the sliding tier's soft
  /// pill and a hidden pill never enlarge anything — a selected tab
  /// shows its selection through color and weight alone.
  ///
  /// While the pill travels, the layer inside it draws at this size
  /// while the layer outside stays at [iconSize], so mid-slide the clip
  /// edge joins two sizes. A modest delta reads as the glass magnifying
  /// the icon; a large one reads as a seam.
  final double? underGlassIconSize;

  /// Label font size. Labels are only shown for items that provide one.
  final double labelFontSize;

  /// Label font size for the item **under the glass**. `null` (the
  /// default) keeps [labelFontSize]. Same rules as [underGlassIconSize]:
  /// the glass's state, not the selection's.
  final double? underGlassLabelFontSize;

  /// Vertical gap between the icon and its label, in logical pixels.
  final double iconLabelGap;

  /// Font weight of the selected item's label.
  final FontWeight selectedFontWeight;

  /// Font weight of unselected items' labels.
  final FontWeight unselectedFontWeight;

  const LiquidGlassTabItemStyle({
    this.selectedColor = Colors.white,
    this.unselectedColor = Colors.white70,
    this.iconSize = 24,
    this.underGlassIconSize,
    this.labelFontSize = 10.5,
    this.underGlassLabelFontSize,
    this.iconLabelGap = 2,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedFontWeight = FontWeight.w500,
  });

  /// Resolves the icon/label color for a cell in [selected] state.
  Color colorFor({required bool selected}) =>
      selected ? selectedColor : unselectedColor;

  /// Resolves the icon size for a cell by how much glass is over it:
  /// a lerp from the shared [iconSize] (`0`) to [underGlassIconSize]
  /// (`1`), so the enlargement fades in and out with the glass itself —
  /// through the landing handover it glides back down instead of
  /// popping when the static pill takes over. Selection alone never
  /// changes size.
  double iconSizeFor({required double underGlass}) =>
      iconSize + ((underGlassIconSize ?? iconSize) - iconSize) * underGlass;

  /// Resolves the label font size for a cell by how much glass is over
  /// it — same lerp as [iconSizeFor].
  double labelFontSizeFor({required double underGlass}) =>
      labelFontSize +
      ((underGlassLabelFontSize ?? labelFontSize) - labelFontSize) *
          underGlass;

  /// Resolves the label weight for a cell in [selected] state.
  FontWeight fontWeightFor({required bool selected}) =>
      selected ? selectedFontWeight : unselectedFontWeight;

  LiquidGlassTabItemStyle copyWith({
    Color? selectedColor,
    Color? unselectedColor,
    double? iconSize,
    double? underGlassIconSize,
    double? labelFontSize,
    double? underGlassLabelFontSize,
    double? iconLabelGap,
    FontWeight? selectedFontWeight,
    FontWeight? unselectedFontWeight,
  }) {
    return LiquidGlassTabItemStyle(
      selectedColor: selectedColor ?? this.selectedColor,
      unselectedColor: unselectedColor ?? this.unselectedColor,
      iconSize: iconSize ?? this.iconSize,
      underGlassIconSize: underGlassIconSize ?? this.underGlassIconSize,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      underGlassLabelFontSize:
          underGlassLabelFontSize ?? this.underGlassLabelFontSize,
      iconLabelGap: iconLabelGap ?? this.iconLabelGap,
      selectedFontWeight: selectedFontWeight ?? this.selectedFontWeight,
      unselectedFontWeight: unselectedFontWeight ?? this.unselectedFontWeight,
    );
  }
}

/// **Magnifier pill** group for [LiquidGlassTabPillStyle]: the invisible
/// second pill mounted **under** the moving glass pill on the Impeller
/// path. It shares the glass pill's silhouette, lift, travel, squash and
/// shed exactly, but is transparent, unblurred, undistorted, rimless and
/// shadowless — its one job is to magnify the **bar** seen under the
/// pill (it sits below the icon shell, so the icons keep their size).
///
/// Impeller only: stacked lenses chain there, so the glass pill above
/// refracts this pill's output. The Skia capture path never mounts it,
/// whatever these fields say.
class LiquidGlassTabMagnifierPillStyle {
  /// Whether the magnifier pill is mounted at all. A feature switch, not
  /// an animated visibility — when mounted it already appears and
  /// retires with the glass pill's own show/hide.
  final bool enabled;

  /// Magnification of the bar seen under the pill. Below `1` the bar
  /// recedes (reads pushed back); `1` is inert. Ramps in with the
  /// pill's lift and back out through the landing handover.
  final double magnification;

  const LiquidGlassTabMagnifierPillStyle({
    this.enabled = true,
    this.magnification = 0.87,
  });

  LiquidGlassTabMagnifierPillStyle copyWith({
    bool? enabled,
    double? magnification,
  }) {
    return LiquidGlassTabMagnifierPillStyle(
      enabled: enabled ?? this.enabled,
      magnification: magnification ?? this.magnification,
    );
  }
}

/// **Selection pill** group for [LiquidGlassTabBar]: everything
/// about the highlight behind the active tab — its look, whether it
/// slides, and whether/where it upgrades to the glass-refracting
/// morphing pill. Defaults mirror the bar's flat parameters, so
/// swapping APIs is lossless.
///
/// The three tiers, all configured here:
///  • glass-refracting morphing pill — **the default** ([mode]
///    [LiquidGlassPillMode.both]): the dual-pipeline pill that refracts
///    the bar itself. The `distortion`/`growHeight`/… knobs below apply
///    to this tier only. A settled bar costs no shader pass, no clip
///    and no capture, on either backend.
///  • sliding highlight — [mode] none + [animated] true: the pill
///    slides between tabs with the iOS-26 icon-reveal, drawn inside
///    the lens (works on every renderer);
///  • static highlight — [mode] none, [animated] false: the flat
///    instant highlight, the cheapest tier of all.
class LiquidGlassTabPillStyle {
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

  /// How much taller than the bar the glass pill stands while it is
  /// lifted (glass [mode]s only) — the pill's main size knob.
  ///
  /// It inflates to this the instant a tab is tapped, holds it for the
  /// whole travel, and comes back down once it has landed.
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

  /// The pill's squash/stretch tuning (glass [mode]s only) — the same
  /// acceleration model [LiquidGlassMotionPill] runs, applied to both
  /// finger-drags and tap-travel.
  ///
  /// The pill's drawn position is sampled every frame, differentiated
  /// twice, and the averaged acceleration scales it oppositely on the two
  /// axes: it stretches wide and flat as it launches off a tab, squashes
  /// narrow and tall as it brakes into the next, and sits undeformed at
  /// constant speed. Force, not speed.
  ///
  /// The default caps the deviation at ±12 %, since this pill travels
  /// inside the bar capsule and a taller overhang would climb out of it.
  final LiquidGlassLensMotionSpec motion;

  /// The Impeller-only **magnifier pill** under the moving glass pill —
  /// see [LiquidGlassTabMagnifierPillStyle]. Defaults to enabled at
  /// magnification `0.87`.
  final LiquidGlassTabMagnifierPillStyle magnifierPill;

  const LiquidGlassTabPillStyle({
    this.mode = LiquidGlassPillMode.both,
    this.show = true,
    this.color = const Color(0x2EAEAEB2),
    this.animated = false,
    this.animationDuration = const Duration(milliseconds: 320),
    this.animationCurve = Curves.easeOutCubic,
    this.blur = const LiquidGlassBlur(),
    this.growHeight = 9,
    this.distortion = 0.04,
    this.distortionWidth = 12,
    this.magnification = 1,
    this.enableInnerRadiusTransparent = false,
    this.shape,
    this.glassStyle,
    this.rest,
    this.travelStiffness = 280,
    this.travelDamping = 31.4,
    // Tuned for tab-scale travel: the sampling window and response ease of
    // the motion pill, with the deformation ceiling brought down to ±12 %.
    this.motion = const LiquidGlassLensMotionSpec(
      sampleWindow: 0.3,
      sensitivity: 0.00007,
      maxDeformation: 0.12,
      responseTime: 0.18,
    ),
    this.magnifierPill = const LiquidGlassTabMagnifierPillStyle(),
  });

  /// The tuned default contact shadow of the moving glass pill — a soft
  /// ring that spreads past the rim (no inset tuck, a wider blur), so
  /// the pill reads as floating over the bar. It rides the default-built
  /// appearance in [effectiveGlass], the same place every lens carries
  /// its shadow; author [glassStyle] with its own `appearance.shadow` to
  /// replace it, or with an appearance carrying none to drop it.
  static const LiquidGlassShadow _defaultShadow =
      LiquidGlassShadow(blur: 9, opacity: 0.3, inset: 0);

  LiquidGlassTabPillStyle copyWith({
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
    LiquidGlassLensMotionSpec? motion,
    LiquidGlassTabMagnifierPillStyle? magnifierPill,
  }) {
    return LiquidGlassTabPillStyle(
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
      motion: motion ?? this.motion,
      magnifierPill: magnifierPill ?? this.magnifierPill,
    );
  }

  /// The moving glass pill's resolved look: [glassStyle] when set,
  /// otherwise built from the individual glass-pill fields (preserving the
  /// shipped defaults — **pure refraction**: no tint of its own, since over
  /// glass a fill only flattens the capsule, with a thin-rimmed continuous
  /// capsule shape and the flat refraction knobs).
  LiquidGlassStyle get effectiveGlass {
    final g = glassStyle;
    return LiquidGlassStyle(
      shape: g?.shape ?? shape ?? const LiquidGlassShape(borderWidth: 0.5),
      appearance: g?.appearance ??
          LiquidGlassAppearance(
            color: Colors.transparent,
            blur: blur,
            enableInnerRadiusTransparent: enableInnerRadiusTransparent,
            shadow: _defaultShadow,
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
  /// The palette the static pill flips on whenever the bar adapts and
  /// [rest] names no palette of its own.
  ///
  /// The bar's adaptivity may be its own `style.adaptivity` or one
  /// inherited from an enclosing `LiquidGlassAdaptiveArea` /
  /// `LiquidGlassScaffold` — the source makes no difference to what the
  /// pill has to do. The pill sits ON the capsule and has to contrast
  /// it, so a capsule that darkens over a dark page while the pill holds
  /// a fixed light fill leaves a light pill on a dark bar.
  ///
  /// Set `rest`'s `adaptivity` to override this palette, or
  /// `LiquidGlassAdaptivity.none` to hold a caller-chosen fill fixed.
  ///
  /// Opposite polarity to the bar's glass, and the same as its content:
  /// the pill has to contrast the BAR it sits on, and an adaptive bar
  /// darkens over a dark page and lightens over a light one. The light
  /// side runs a little heavier because black on a bright surface needs
  /// more alpha to read as the same step — at 18%/20% both land near a
  /// 1.6:1 step against the capsule.
  static const LiquidGlassAdaptivity defaultRestAdaptivity =
      LiquidGlassAdaptivity(
    glassColorOnDark: Color(0x2EFFFFFF),
    glassColorOnLight: Color(0x33000000),
  );

  LiquidGlassStyle get effectiveRest {
    final r = rest;
    return LiquidGlassStyle(
      shape: r?.shape ?? shape,
      appearance: r?.appearance ?? LiquidGlassAppearance(color: color),
      // Carried, not dropped: the static pill resolves it against the
      // BAR's verdict, so the pill flips with the bar rather than
      // sampling a backdrop it cannot see (its own rect reads the
      // capsule's tint, not the page).
      adaptivity: r?.adaptivity,
      // Explicitly inert, not merely "ignored". The static pill never
      // reads this, but the moving pill interpolates FROM it, and
      // `LiquidGlassStyle`'s default refraction is the full-strength one
      // (distortion 0.1 over a 30 px band) — stronger than most lifted
      // pills, which inverted the lerp and left the glass still bending
      // the bar at the instant the static pill took over.
      refraction: const LiquidGlassRefraction(
        distortion: 0,
        distortionWidth: 0,
        chromaticAberration: 0,
      ),
    );
  }
}
