// -----------------------------------------------------------------------------
// SHARED, REUSABLE STYLE GROUPS  (experimental / sandbox)
// -----------------------------------------------------------------------------
// These are the *scalable* categorization groups for the package's drop-in
// components (bottom nav bar, app bar, slider, toggle, and future ones).
//
// The idea mirrors the existing grouped `LiquidGlass` API in
// `liquid_glass_config.dart`: small immutable group objects with `copyWith`
// and defaults that exactly reproduce the values currently hardcoded across
// the components — so adopting a group is lossless until a caller opts in.
//
// This file is intentionally SELF-CONTAINED and additive: nothing here is
// imported by the existing components yet. It exists so the grouped API can be
// built and tested in isolation (see `liquid_glass_styled_nav_bar.dart`)
// without touching shipping code. Once validated it can be promoted and the
// existing components can adopt these groups one at a time.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../liquid_glass_config.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_refresh_rate.dart';

// The capsule's glass look is configured by the package's EXISTING config
// groups (LiquidGlassRefraction / LiquidGlassAppearance / LiquidGlassShape),
// passed as optional overrides directly to the styled component — so there is
// no wrapper "surface" type here. This file holds the component-side groups:
// motion timing, nav-bar item styling, the moving glass pill, and the
// capture/render pipeline.

/// **Motion** group — animation timing, shared by anything that animates
/// (the nav pill slide today; slider/toggle thumbs later).
///
/// Defaults reproduce the bottom-nav slide (320 ms, `easeOutCubic`).
class LiquidGlassMotion {
  /// How long the primary transition takes.
  final Duration duration;

  /// Easing curve for the primary transition.
  final Curve curve;

  const LiquidGlassMotion({
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
  });

  LiquidGlassMotion copyWith({Duration? duration, Curve? curve}) {
    return LiquidGlassMotion(
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
    );
  }
}

/// **Nav-bar item** group — the *component-specific* content styling for the
/// bottom nav bar: icon/label colors and sizes plus the selection highlight.
///
/// This is the small, unique-per-component group; the glass look comes from
/// the config groups (refraction / appearance / shape) passed to the
/// component, and the timing from [LiquidGlassMotion]. Defaults reproduce the
/// values currently hardcoded in the animated nav bar's shell + rest pill.
class LiquidGlassNavBarItemStyle {
  /// Color of the selected item's icon + label.
  final Color selectedItemColor;

  /// Color of unselected items' icons + labels.
  final Color unselectedItemColor;

  /// Icon size for every item.
  final double iconSize;

  /// Label font size (labels only show for items that provide one).
  final double labelFontSize;

  /// Whether to draw the soft pill behind the selected item.
  final bool showSelectionPill;

  /// Color of the selection pill behind the active item.
  final Color selectionColor;

  const LiquidGlassNavBarItemStyle({
    this.selectedItemColor = Colors.white,
    this.unselectedItemColor = Colors.white70,
    this.iconSize = 24,
    this.labelFontSize = 10.5,
    this.showSelectionPill = true,
    this.selectionColor = const Color(0x26FFFFFF), // white, alpha 38
  });

  LiquidGlassNavBarItemStyle copyWith({
    Color? selectedItemColor,
    Color? unselectedItemColor,
    double? iconSize,
    double? labelFontSize,
    bool? showSelectionPill,
    Color? selectionColor,
  }) {
    return LiquidGlassNavBarItemStyle(
      selectedItemColor: selectedItemColor ?? this.selectedItemColor,
      unselectedItemColor: unselectedItemColor ?? this.unselectedItemColor,
      iconSize: iconSize ?? this.iconSize,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      showSelectionPill: showSelectionPill ?? this.showSelectionPill,
      selectionColor: selectionColor ?? this.selectionColor,
    );
  }
}

/// **Pill** group — the moving glass selection pill's look + size (the
/// iOS-26 morphing pill that slides between tabs). Defaults reproduce the
/// shipping bar's pill.
class LiquidGlassTabPillStyle {
  /// Blur behind the moving glass pill.
  final LiquidGlassBlur blur;

  /// How much **taller** the pill grows than the bar at peak travel — the
  /// pill's size knob. Peak height is `barHeight + growHeight`.
  final double growHeight;

  /// Refraction strength of the pill's glass.
  final double distortion;

  /// Width of the pill's refraction band, in px.
  final double distortionWidth;

  /// Complete refraction configuration for the moving pill. When set, this
  /// supersedes [distortion], [distortionWidth], and [magnification].
  final LiquidGlassRefraction? refraction;

  /// Magnification of the content seen through the pill (`1` = none).
  final double magnification;

  /// When `true`, the pill's inner area is transparent.
  final bool enableInnerRadiusTransparent;

  const LiquidGlassTabPillStyle({
    this.blur = const LiquidGlassBlur(),
    this.growHeight = 16,
    this.distortion = 0.06,
    this.distortionWidth = 10,
    this.refraction,
    this.magnification = 1,
    this.enableInnerRadiusTransparent = false,
  });

  LiquidGlassTabPillStyle copyWith({
    LiquidGlassBlur? blur,
    double? growHeight,
    double? distortion,
    double? distortionWidth,
    LiquidGlassRefraction? refraction,
    double? magnification,
    bool? enableInnerRadiusTransparent,
  }) {
    return LiquidGlassTabPillStyle(
      blur: blur ?? this.blur,
      growHeight: growHeight ?? this.growHeight,
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      refraction: refraction ?? this.refraction,
      magnification: magnification ?? this.magnification,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
    );
  }
}

/// **Render** group — the capture/render pipeline settings forwarded to the
/// internal `LiquidGlassView`(s). Defaults match the component defaults.
class LiquidGlassRenderConfig {
  /// Capture resolution for the inner view (`1.0` = logical; `0.0` = device
  /// pixel ratio).
  final double pixelRatio;

  /// Whether captures are pushed synchronously to the lenses.
  final bool useSync;

  /// Force the Impeller backdrop path (`true`) or the Skia capture path
  /// (`false`). `null` auto-detects the renderer.
  final bool? useImpellerBackdrop;

  /// Whether the inner view captures every frame (keeps the bar's refraction
  /// live as the body scrolls). `false` = snapshot-at-rest, woken on a morph.
  final bool realTimeCapture;

  /// Capture cadence for the internal views.
  final LiquidGlassRefreshRate refreshRate;

  const LiquidGlassRenderConfig({
    this.pixelRatio = 1.0,
    this.useSync = true,
    this.useImpellerBackdrop,
    this.realTimeCapture = true,
    this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
  });

  LiquidGlassRenderConfig copyWith({
    double? pixelRatio,
    bool? useSync,
    bool? useImpellerBackdrop,
    bool? realTimeCapture,
    LiquidGlassRefreshRate? refreshRate,
  }) {
    return LiquidGlassRenderConfig(
      pixelRatio: pixelRatio ?? this.pixelRatio,
      useSync: useSync ?? this.useSync,
      useImpellerBackdrop: useImpellerBackdrop ?? this.useImpellerBackdrop,
      realTimeCapture: realTimeCapture ?? this.realTimeCapture,
      refreshRate: refreshRate ?? this.refreshRate,
    );
  }
}
