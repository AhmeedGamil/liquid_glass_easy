import 'package:flutter/foundation.dart';

import 'liquid_glass_config.dart';
import 'utils/liquid_glass_adaptivity.dart';
import 'utils/liquid_glass_shape.dart';

/// The **look** of a liquid-glass surface, bundled into one reusable
/// descriptor: its [shape] (corners + border), its [appearance] (fill
/// tint, blur, saturation, inner transparency) and its [refraction]
/// (how it bends the content behind it).
///
/// This is the single styling vocabulary shared across the library —
/// `LiquidGlassLens`, the `LiquidGlass` lens config, and the components
/// (buttons, bars, the nav pill, …) all describe their glass with the
/// same object. A surface is fully `geometry` (where + how big) +
/// **style** (how it looks) + behavior (how it acts).
///
/// Non-refracting consumers — e.g. the static (non-glass) selection pill
/// or the frosted fallback — read the subset they can render ([shape] +
/// [appearance]) and simply ignore [refraction].
///
/// ```dart
/// const LiquidGlassStyle(
///   shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 24),
///   appearance: LiquidGlassAppearance(color: Color(0x22FFFFFF)),
///   refraction: LiquidGlassRefraction(distortion: 0.08),
/// );
/// ```
@immutable
class LiquidGlassStyle {
  /// Corners + border of the surface. When `null`, the consumer picks a
  /// sensible default (e.g. the nav pill falls back to a height-tracking
  /// capsule), so a style can describe appearance/refraction without
  /// pinning the shape.
  final LiquidGlassShape? shape;

  /// Fill tint, blur, saturation and inner transparency.
  final LiquidGlassAppearance appearance;

  /// How the glass bends the content behind it. Ignored by
  /// non-refracting consumers.
  final LiquidGlassRefraction refraction;

  /// iOS-style adaptivity: glass tint + content color flip between two
  /// palettes based on the background behind the lens. `null` (default)
  /// disables the feature entirely. Honored by `LiquidGlassLens`; while
  /// active, its glass color overrides [appearance]'s `color`.
  final LiquidGlassAdaptivity? adaptivity;

  const LiquidGlassStyle({
    this.shape,
    this.appearance = const LiquidGlassAppearance(),
    this.refraction = const LiquidGlassRefraction(),
    this.adaptivity,
  });

  /// Returns a copy with the given fields replaced.
  LiquidGlassStyle copyWith({
    LiquidGlassShape? shape,
    LiquidGlassAppearance? appearance,
    LiquidGlassRefraction? refraction,
    LiquidGlassAdaptivity? adaptivity,
  }) {
    return LiquidGlassStyle(
      shape: shape ?? this.shape,
      appearance: appearance ?? this.appearance,
      refraction: refraction ?? this.refraction,
      adaptivity: adaptivity ?? this.adaptivity,
    );
  }

  /// Overlays [other] on top of this style: [other]'s [appearance] and
  /// [refraction] replace this one's, and its [shape] and [adaptivity]
  /// win when set (falling back to this style's when `null`).
  /// Returns this style unchanged when [other] is `null`. Useful for a
  /// base/theme style with per-surface overrides.
  LiquidGlassStyle merge(LiquidGlassStyle? other) {
    if (other == null) return this;
    return LiquidGlassStyle(
      shape: other.shape ?? shape,
      appearance: other.appearance,
      refraction: other.refraction,
      adaptivity: other.adaptivity ?? adaptivity,
    );
  }
}
