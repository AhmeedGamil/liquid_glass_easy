import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_touch.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_shadow.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass_style.dart';

/// Represents a single lens in the LiquidGlass system, configured
/// through four grouped objects:
///
///  • [LiquidGlassGeometry]   — size, shape, placement (required).
///  • [LiquidGlassRefraction] — how the glass bends light (refraction
///    index and width, magnification, dispersion).
///  • [LiquidGlassAppearance] — tint, blur, saturation.
///  • [LiquidGlassBehavior]   — interaction & lifecycle.
///
/// ```dart
/// LiquidGlass(
///   geometry: LiquidGlassGeometry(
///     position: const LiquidGlassAlignPosition(alignment: Alignment.center),
///     width: 240, height: 160,
///     shape: const LiquidGlassShape.roundedRectangle(cornerRadius: 36),
///   ),
///   refraction: const LiquidGlassRefraction(
///     refractionIndex: 1.02, refractionWidth: 28,
///   ),
///   appearance: const LiquidGlassAppearance(
///     blur: 2, color: Color(0x16FFFFFF),
///   ),
///   behavior: const LiquidGlassBehavior(draggable: true),
///   child: const Center(child: Text('drag me')),
/// );
/// ```
///
/// {@template liquid_glass_internal}
/// **Internal.** This is the classic, position-driven lens engine. App
/// developers should use [LiquidGlassLens] (the layout-driven
/// "lens-anywhere" widget) instead; this type is retained only for the
/// package's own components and is not part of the public API.
/// {@endtemplate}
@internal
class LiquidGlass {
  /// Optional widget key, propagated to the underlying `LiquidGlassWidget`
  /// inside `LiquidGlassView`. Use it to bind a lens `State` to a logical
  /// slot (e.g. a fixed UI position) rather than to its index in `children`.
  /// Without a stable key, inserting/removing other lenses (e.g. a progress
  /// bar) can cause Flutter to reuse the wrong `State` for a lens.
  final Key? key;

  /// Optional widget content displayed inside the lens area.
  ///
  /// Can be used to show overlays, icons, or custom visual elements.
  final Widget? child;

  /// Size and placement of the lens (position, width, height).
  final LiquidGlassGeometry geometry;

  /// The geometric shape of the lens and its border styling. Lives here
  /// (not in [geometry]) so [geometry] is purely size + placement — and
  /// so it parallels [LiquidGlassLens.shape]. Superseded by [style] when
  /// the style sets a shape.
  final LiquidGlassShape shape;

  /// How the glass bends light.
  final LiquidGlassRefraction refraction;

  /// The lens material: tint, blur, saturation.
  final LiquidGlassAppearance appearance;

  /// Interaction & lifecycle: dragging, visibility, controller.
  final LiquidGlassBehavior behavior;

  /// Overall opacity of the rendered lens (`1` = fully opaque). The view
  /// wraps the lens in an `Opacity` when this is below `1`, so the whole
  /// lens — refraction, rim and tint — fades together. Used to cross-fade
  /// a lens out (e.g. the bottom-nav glass pill dissolving into its
  /// static rest pill).
  final double opacity;

  /// The lens's look bundled as one [LiquidGlassStyle] (shape +
  /// appearance + refraction) — the preferred, library-wide styling
  /// vocabulary. When non-null it supersedes the [shape] / [appearance] /
  /// [refraction] groups; a `null` shape inside the style falls back to
  /// [shape]. Consumers read the resolved values via [effectiveShape] /
  /// [effectiveAppearance] / [effectiveRefraction].
  final LiquidGlassStyle? style;

  const LiquidGlass({
    this.key,
    this.child,
    required this.geometry,
    this.shape = const LiquidGlassShape.continuousRoundedRectangle(),
    this.refraction = const LiquidGlassRefraction(),
    this.appearance = const LiquidGlassAppearance(),
    this.behavior = const LiquidGlassBehavior(),
    this.style,
    this.opacity = 1.0,
  });

  /// Outline and border lights after applying [style]: the style's own
  /// where set, else [shape]'s.
  LiquidGlassLitShape get effectiveShape {
    final LiquidGlassLitShape base = LiquidGlassLitShape.of(shape);
    final LiquidGlassStyle? s = style;
    if (s == null) return base;
    return s.litShape(
      fallback: base,
      fallbackSpecular: base.specular,
      fallbackGlow: base.glow,
    );
  }

  /// Appearance after applying [style]: `style.appearance` when a [style]
  /// is set, else the [appearance] group.
  LiquidGlassAppearance get effectiveAppearance =>
      style?.appearance ?? appearance;

  /// Refraction after applying [style]: `style.refraction` when a [style]
  /// is set, else the [refraction] group.
  LiquidGlassRefraction get effectiveRefraction =>
      style?.refraction ?? refraction;

  /// Returns a copy of this lens config with the given groups replaced.
  ///
  /// Note this always returns a base [LiquidGlass]; subclass identity
  /// (e.g. [LiquidGlass] components) is not preserved, but every visual
  /// value is — which is all [LiquidGlassView] reads. Used internally by
  /// `LiquidGlassScaffold` to re-position a slot (e.g. shift the app bar
  /// below the status bar) without rebuilding the developer's widget.
  /// To change a single value, copy the group:
  /// `lens.copyWith(geometry: lens.geometry.copyWith(width: 240))`.
  LiquidGlass copyWith({
    Key? key,
    Widget? child,
    LiquidGlassGeometry? geometry,
    LiquidGlassShape? shape,
    LiquidGlassRefraction? refraction,
    LiquidGlassAppearance? appearance,
    LiquidGlassBehavior? behavior,
    LiquidGlassStyle? style,
    double? opacity,
  }) {
    return LiquidGlass(
      key: key ?? this.key,
      child: child ?? this.child,
      geometry: geometry ?? this.geometry,
      shape: shape ?? this.shape,
      refraction: refraction ?? this.refraction,
      appearance: appearance ?? this.appearance,
      behavior: behavior ?? this.behavior,
      style: style ?? this.style,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// **Geometry** group: where the lens is and how big — size + placement.
/// The lens's outline lives in [LiquidGlass.shape] / [LiquidGlassStyle],
/// not here, so geometry is purely position + size.
///
/// One of the configuration groups accepted by [LiquidGlass].
///
/// {@macro liquid_glass_internal}
@internal
class LiquidGlassGeometry {
  /// The placement of the lens (absolute offset or relative alignment).
  final LiquidGlassPosition position;

  /// The width of the lens in logical pixels.
  final double width;

  /// The height of the lens in logical pixels.
  final double height;

  /// Whether the lens may extend outside the parent's bounds (vs. being
  /// clamped inside it).
  final bool outOfBoundaries;

  const LiquidGlassGeometry({
    required this.position,
    this.width = 200,
    this.height = 100,
    this.outOfBoundaries = false,
  });

  LiquidGlassGeometry copyWith({
    LiquidGlassPosition? position,
    double? width,
    double? height,
    bool? outOfBoundaries,
  }) {
    return LiquidGlassGeometry(
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      outOfBoundaries: outOfBoundaries ?? this.outOfBoundaries,
    );
  }
}

/// The renderers' own carrier for what a [LiquidGlassStyle] holds flat:
/// `refractionIndex`, `refractionWidth`, `magnification` and
/// `dispersion`.
@internal
class LiquidGlassRefraction {
  /// How hard the edge bends what is behind it (`1.0` = no bending).
  final double refractionIndex;

  /// Width of the bending band along the edge, in logical pixels.
  final double refractionWidth;

  /// Magnification of the content seen through the lens (`1.0` = none).
  final double magnification;

  /// Colour fringe in the bending band; see `LiquidGlassStyle.dispersion`.
  final double dispersion;

  const LiquidGlassRefraction({
    this.refractionIndex = 1.1,
    this.refractionWidth = 12,
    this.magnification = 1,
    this.dispersion = 0,
  });

  /// The same refraction with its bend scaled by [factor] (`1` = as
  /// authored, `0` = none). The band keeps its width.
  LiquidGlassRefraction withEffectFactor(double factor) =>
      copyWith(refractionIndex: 1.0 + (refractionIndex - 1.0) * factor);

  /// The same refraction with its band [factor] times as wide.
  LiquidGlassRefraction withWidthFactor(double factor) =>
      copyWith(refractionWidth: refractionWidth * factor);

  /// Linearly interpolates between two refractions.
  static LiquidGlassRefraction lerp(
      LiquidGlassRefraction a, LiquidGlassRefraction b, double t) {
    double mix(double x, double y) => x + (y - x) * t;
    return LiquidGlassRefraction(
      refractionIndex: mix(a.refractionIndex, b.refractionIndex),
      refractionWidth: mix(a.refractionWidth, b.refractionWidth),
      magnification: mix(a.magnification, b.magnification),
      dispersion: mix(a.dispersion, b.dispersion),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassRefraction &&
          other.refractionIndex == refractionIndex &&
          other.refractionWidth == refractionWidth &&
          other.magnification == magnification &&
          other.dispersion == dispersion;

  @override
  int get hashCode => Object.hash(
      refractionIndex, refractionWidth, magnification,
      dispersion);

  LiquidGlassRefraction copyWith({
    double? refractionIndex,
    double? refractionWidth,
    double? magnification,
    double? dispersion,
  }) {
    return LiquidGlassRefraction(
      refractionIndex: refractionIndex ?? this.refractionIndex,
      refractionWidth: refractionWidth ?? this.refractionWidth,
      magnification: magnification ?? this.magnification,
      dispersion: dispersion ?? this.dispersion,
    );
  }
}

/// **Material** group: the lens's appearance — tint, blur, saturation and
/// inner transparency (everything visual that isn't optical refraction).
///
/// The renderers' own carrier for what a [LiquidGlassStyle] holds flat:
/// `color`, `blur`, `saturation` and `shadow`.
@internal
class LiquidGlassAppearance {
  /// Color saturation of the output (`1.0` = unchanged, `0.0` = grayscale).
  final double saturation;

  /// Blur applied to the content beneath the glass, as a Gaussian sigma.
  final double blur;

  /// Base color tint of the lens (often semi-transparent).
  final Color color;

  /// Contact shadow around the lens. See [LiquidGlassStyle.shadow].
  final LiquidGlassShadow? shadow;

  const LiquidGlassAppearance({
    this.saturation = 1.0,
    this.blur = 0.0,
    this.color = Colors.transparent,
    this.shadow,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassAppearance &&
          other.saturation == saturation &&
          other.blur == blur &&
          other.color == color &&
          other.shadow == shadow;

  @override
  int get hashCode => Object.hash(saturation, blur, color, shadow);

  LiquidGlassAppearance copyWith({
    double? saturation,
    double? blur,
    Color? color,
    LiquidGlassShadow? shadow,
  }) {
    return LiquidGlassAppearance(
      saturation: saturation ?? this.saturation,
      blur: blur ?? this.blur,
      color: color ?? this.color,
      shadow: shadow ?? this.shadow,
    );
  }
}

/// **Behavior** group: interaction and lifecycle.
///
/// One of the four configuration groups accepted by [LiquidGlass].
///
/// {@macro liquid_glass_internal}
@internal
class LiquidGlassBehavior {
  /// Whether the lens can be dragged by the user.
  final bool draggable;

  /// Whether the lens is currently visible.
  final bool visibility;

  /// Programmatic controller for show/hide/reposition.
  final LiquidGlassController? controller;

  /// Makes the lens deform under touch without moving it — press and it
  /// compresses, drag and it elongates along the pull, pinches in the cross
  /// axis and leans after the finger, then springs back with a wobble.
  ///
  /// `null` (the default) disables it completely: no gesture listener, no
  /// ticker, and the lens config reaches the renderer untouched.
  final LiquidGlassTouch? touch;

  const LiquidGlassBehavior({
    this.draggable = false,
    this.visibility = true,
    this.controller,
    this.touch,
  });

  LiquidGlassBehavior copyWith({
    bool? draggable,
    bool? visibility,
    LiquidGlassController? controller,
    LiquidGlassTouch? touch,
  }) {
    return LiquidGlassBehavior(
      draggable: draggable ?? this.draggable,
      visibility: visibility ?? this.visibility,
      controller: controller ?? this.controller,
      touch: touch ?? this.touch,
    );
  }
}
