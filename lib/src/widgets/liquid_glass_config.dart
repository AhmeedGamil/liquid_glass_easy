import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_elasticity.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_type.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass_style.dart';

/// Represents a single lens in the LiquidGlass system, configured
/// through four grouped objects:
///
///  • [LiquidGlassGeometry]   — size, shape, placement (required).
///  • [LiquidGlassRefraction] — how the glass bends light (distortion,
///    magnification, chromatic aberration, refraction mode).
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
///     distortion: 0.12, distortionWidth: 28,
///   ),
///   appearance: const LiquidGlassAppearance(
///     blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2), color: Color(0x16FFFFFF),
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

  /// Shape after applying [style]: `style.shape` when set, else [shape].
  LiquidGlassShape get effectiveShape => style?.shape ?? shape;

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

/// **Refraction** group: how the glass bends light — the optical
/// distortion of the content behind the lens.
///
/// One of the four configuration groups accepted by [LiquidGlass].
class LiquidGlassRefraction {
  /// Legacy/default standard distortion strength (`0.0`–`1.0`).
  ///
  /// Used only when [refractionType] is `null`.
  final double distortion;

  /// Legacy/default standard distortion-band width, in logical pixels.
  ///
  /// Used only when [refractionType] is `null`.
  final double distortionWidth;

  /// Magnification of the content seen through the lens (`1.0` = none).
  final double magnification;

  /// Strength of the chromatic aberration (color-channel separation).
  final double chromaticAberration;

  /// Geometry used to direct the refraction (shape vs. radial).
  final LiquidGlassRefractionMode refractionMode;

  /// Optional calculation-specific controls.
  ///
  /// When `null`, [distortion] and [distortionWidth] select the standard
  /// calculation for backward compatibility. When non-null, those legacy
  /// fields are ignored and this object's values are used instead.
  final LiquidGlassRefractionType? refractionType;

  /// Diagonal mirroring/flip of the refraction direction.
  final double diagonalFlip;

  const LiquidGlassRefraction({
    this.distortion = 0.1,
    this.distortionWidth = 30,
    this.magnification = 1,
    this.chromaticAberration = 0.003,
    this.refractionMode = LiquidGlassRefractionMode.shapeRefraction,
    this.refractionType,
    this.diagonalFlip = 0,
  });

  /// Strength fed to the shader's `u_distortion` uniform.
  ///
  /// For [StandardRefraction] this is the legacy distortion. For
  /// [OpticalRefraction] it carries [OpticalRefraction.depth] — the
  /// optical displacement strength rides the same wire, so the shader's
  /// physical path scales its travel distance by it.
  double get effectiveDistortion => switch (refractionType) {
        StandardRefraction(:final distortion) => distortion,
        OpticalRefraction(:final depth) => depth,
        null => distortion,
      };

  /// Refractive index for the optical calculation (`1.0` = no bending).
  double get effectiveRefractionIndex => switch (refractionType) {
        OpticalRefraction(:final refraction) => refraction,
        _ => 1.0,
      };

  /// Width resolved from [refractionType], or the legacy [distortionWidth].
  double get effectiveDistortionWidth =>
      refractionType?.width ?? distortionWidth;

  LiquidGlassRefraction copyWith({
    double? distortion,
    double? distortionWidth,
    double? magnification,
    double? chromaticAberration,
    LiquidGlassRefractionMode? refractionMode,
    LiquidGlassRefractionType? refractionType,

    /// Clears a configured type and restores the legacy standard controls.
    bool clearRefractionType = false,
    double? diagonalFlip,
  }) {
    return LiquidGlassRefraction(
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      magnification: magnification ?? this.magnification,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      refractionMode: refractionMode ?? this.refractionMode,
      refractionType:
          clearRefractionType ? null : refractionType ?? this.refractionType,
      diagonalFlip: diagonalFlip ?? this.diagonalFlip,
    );
  }
}

/// **Material** group: the lens's appearance — tint, blur, saturation and
/// inner transparency (everything visual that isn't optical refraction).
///
/// One of the four configuration groups accepted by [LiquidGlass].
class LiquidGlassAppearance {
  /// Color saturation of the output (`1.0` = unchanged, `0.0` = grayscale).
  final double saturation;

  /// Blur applied to the content beneath the glass.
  final LiquidGlassBlur blur;

  /// Base color tint of the lens (often semi-transparent).
  final Color color;

  /// Whether the inner, non-distorted region is transparent.
  final bool enableInnerRadiusTransparent;

  const LiquidGlassAppearance({
    this.saturation = 1.0,
    this.blur = const LiquidGlassBlur(),
    this.color = Colors.transparent,
    this.enableInnerRadiusTransparent = false,
  });

  LiquidGlassAppearance copyWith({
    double? saturation,
    LiquidGlassBlur? blur,
    Color? color,
    bool? enableInnerRadiusTransparent,
  }) {
    return LiquidGlassAppearance(
      saturation: saturation ?? this.saturation,
      blur: blur ?? this.blur,
      color: color ?? this.color,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
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
  final LiquidGlassElasticity? elasticity;

  const LiquidGlassBehavior({
    this.draggable = false,
    this.visibility = true,
    this.controller,
    this.elasticity,
  });

  LiquidGlassBehavior copyWith({
    bool? draggable,
    bool? visibility,
    LiquidGlassController? controller,
    LiquidGlassElasticity? elasticity,
  }) {
    return LiquidGlassBehavior(
      draggable: draggable ?? this.draggable,
      visibility: visibility ?? this.visibility,
      controller: controller ?? this.controller,
      elasticity: elasticity ?? this.elasticity,
    );
  }
}
