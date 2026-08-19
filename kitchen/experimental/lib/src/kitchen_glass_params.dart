import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Every knob the experimental glass shader exposes.
///
/// The optical values live in **logical points**, so the same numbers read the
/// same on any device pixel ratio. The shader converts to physical pixels.
@immutable
class KitchenGlassParams {
  const KitchenGlassParams({
    this.cornerRadius = 40,
    this.cornerExponent = 2,
    this.mergeSmoothness = 28,
    this.tint = const ui.Color(0x00FFFFFF),
    this.thickness = 10,
    this.refractiveIndex = 1.5,
    this.dispersion = 5,
    this.magnification = 1,
    this.blur = 0,
    this.fresnelRange = 70,
    this.fresnelIntensity = 0,
    this.fresnelSharpness = 0,
    this.glareRange = 30,
    this.glareConvergence = 0.1,
    this.glareOppositeBias = 1,
    this.glareIntensity = 0.1,
    this.glareSharpness = -0.15,
    this.glareAngleOffset = -0.7853981634,
    this.edgeGain = 6,
    this.debugMode = 0,
  });

  // ── Shape ────────────────────────────────────────────────────────────
  /// Corner rounding of every lobe, in points. Half the short side = capsule.
  final double cornerRadius;

  /// Superellipse exponent: 1 = diamond, 2 = circular, 4+ = squircle.
  final double cornerExponent;

  /// Distance over which two lobes start to fuse into one surface, in points.
  final double mergeSmoothness;

  // ── Material ─────────────────────────────────────────────────────────
  /// Glass colour; the alpha channel is the tint amount (scaled by 0.8).
  final ui.Color tint;

  /// Depth of the refracting slab measured in from the outline, in points.
  /// Everything deeper than this looks straight through.
  final double thickness;

  /// Index of refraction of the slab. 1.0 = no bend, 1.5 = window glass.
  final double refractiveIndex;

  /// Chromatic dispersion: how far apart red and blue walk. 0 disables it and
  /// drops the refracted sample from three taps to one.
  final double dispersion;

  /// Zoom of the content seen through the glass, about the merged blob centre.
  final double magnification;

  /// Radius of the in-shader frost applied to the sampled backdrop, in points.
  /// 0 disables the nine-tap loop entirely.
  final double blur;

  // ── Fresnel rim ──────────────────────────────────────────────────────
  /// Distance in from the outline over which the rim builds, in points.
  final double fresnelRange;

  /// Rim strength. 0 removes the rim.
  final double fresnelIntensity;

  /// Shifts the whole rim ramp; negative pulls it tighter to the outline.
  final double fresnelSharpness;

  // ── Glare ────────────────────────────────────────────────────────────
  /// Distance in from the outline over which the glare builds, in points.
  final double glareRange;

  /// Focuses the highlight toward the light direction (0 = broad, 1 = tight).
  final double glareConvergence;

  /// Multiplier for the highlight on the arc opposite the light direction.
  final double glareOppositeBias;

  /// Glare strength.
  final double glareIntensity;

  /// Shifts the glare ramp; negative pulls it tighter to the outline.
  final double glareSharpness;

  /// Rotates the highlight arcs, in radians.
  final double glareAngleOffset;

  /// Stands in for the surface-normal magnitude the rim and glare are scaled
  /// by. Larger = stronger, harder highlights on the same geometry.
  final double edgeGain;

  /// 0 = glass, 1 = distance field, 2 = surface normals.
  final double debugMode;

  KitchenGlassParams copyWith({
    double? cornerRadius,
    double? cornerExponent,
    double? mergeSmoothness,
    ui.Color? tint,
    double? thickness,
    double? refractiveIndex,
    double? dispersion,
    double? magnification,
    double? blur,
    double? fresnelRange,
    double? fresnelIntensity,
    double? fresnelSharpness,
    double? glareRange,
    double? glareConvergence,
    double? glareOppositeBias,
    double? glareIntensity,
    double? glareSharpness,
    double? glareAngleOffset,
    double? edgeGain,
    double? debugMode,
  }) {
    return KitchenGlassParams(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      cornerExponent: cornerExponent ?? this.cornerExponent,
      mergeSmoothness: mergeSmoothness ?? this.mergeSmoothness,
      tint: tint ?? this.tint,
      thickness: thickness ?? this.thickness,
      refractiveIndex: refractiveIndex ?? this.refractiveIndex,
      dispersion: dispersion ?? this.dispersion,
      magnification: magnification ?? this.magnification,
      blur: blur ?? this.blur,
      fresnelRange: fresnelRange ?? this.fresnelRange,
      fresnelIntensity: fresnelIntensity ?? this.fresnelIntensity,
      fresnelSharpness: fresnelSharpness ?? this.fresnelSharpness,
      glareRange: glareRange ?? this.glareRange,
      glareConvergence: glareConvergence ?? this.glareConvergence,
      glareOppositeBias: glareOppositeBias ?? this.glareOppositeBias,
      glareIntensity: glareIntensity ?? this.glareIntensity,
      glareSharpness: glareSharpness ?? this.glareSharpness,
      glareAngleOffset: glareAngleOffset ?? this.glareAngleOffset,
      edgeGain: edgeGain ?? this.edgeGain,
      debugMode: debugMode ?? this.debugMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KitchenGlassParams &&
        other.cornerRadius == cornerRadius &&
        other.cornerExponent == cornerExponent &&
        other.mergeSmoothness == mergeSmoothness &&
        other.tint == tint &&
        other.thickness == thickness &&
        other.refractiveIndex == refractiveIndex &&
        other.dispersion == dispersion &&
        other.magnification == magnification &&
        other.blur == blur &&
        other.fresnelRange == fresnelRange &&
        other.fresnelIntensity == fresnelIntensity &&
        other.fresnelSharpness == fresnelSharpness &&
        other.glareRange == glareRange &&
        other.glareConvergence == glareConvergence &&
        other.glareOppositeBias == glareOppositeBias &&
        other.glareIntensity == glareIntensity &&
        other.glareSharpness == glareSharpness &&
        other.glareAngleOffset == glareAngleOffset &&
        other.edgeGain == edgeGain &&
        other.debugMode == debugMode;
  }

  @override
  int get hashCode => Object.hashAll([
        cornerRadius,
        cornerExponent,
        mergeSmoothness,
        tint,
        thickness,
        refractiveIndex,
        dispersion,
        magnification,
        blur,
        fresnelRange,
        fresnelIntensity,
        fresnelSharpness,
        glareRange,
        glareConvergence,
        glareOppositeBias,
        glareIntensity,
        glareSharpness,
        glareAngleOffset,
        edgeGain,
        debugMode,
      ]);

  // ── Presets ──────────────────────────────────────────────────────────

  /// Thin, near-clear glass with a strong magnifying pull — reads well on a
  /// small element such as a knob or thumb.
  static const KitchenGlassParams lens = KitchenGlassParams(
    thickness: 6,
    refractiveIndex: 1.1,
    dispersion: 15,
    magnification: 0.9,
    fresnelRange: 70,
    fresnelIntensity: 0,
    fresnelSharpness: 0,
    glareRange: 30,
    glareConvergence: 0.1,
    glareOppositeBias: 1,
    glareIntensity: 0.1,
    glareSharpness: -0.1,
    glareAngleOffset: -0.7853981634,
  );

  /// Thicker, denser glass with a frosted, tinted body — the panel material.
  static const KitchenGlassParams regular = KitchenGlassParams(
    tint: ui.Color(0xCCE6F2FF),
    thickness: 10,
    refractiveIndex: 1.5,
    dispersion: 5,
    magnification: 1,
    blur: 6,
    fresnelRange: 70,
    fresnelIntensity: 0,
    fresnelSharpness: 0,
    glareRange: 30,
    glareConvergence: 0.1,
    glareOppositeBias: 1,
    glareIntensity: 0.1,
    glareSharpness: -0.15,
    glareAngleOffset: -0.7853981634,
  );

  /// Almost invisible glass that mostly magnifies, with a cool cast.
  static const KitchenGlassParams thumb = KitchenGlassParams(
    tint: ui.Color(0x26E6F2FF),
    thickness: 10,
    refractiveIndex: 1.11,
    dispersion: 5,
    magnification: 1.3,
    fresnelRange: 70,
    fresnelIntensity: 0,
    fresnelSharpness: 0,
    glareRange: 30,
    glareConvergence: 0,
    glareOppositeBias: 0,
    glareIntensity: 0.01,
    glareSharpness: -0.2,
    glareAngleOffset: 2.8274333882,
  );

  /// Heavy, showy glass: wide rim, hard glare, obvious prism fringe.
  static const KitchenGlassParams crystal = KitchenGlassParams(
    tint: ui.Color(0x1AFFFFFF),
    thickness: 18,
    refractiveIndex: 1.52,
    dispersion: 18,
    magnification: 1.05,
    fresnelRange: 120,
    fresnelIntensity: 0.6,
    fresnelSharpness: -0.05,
    glareRange: 60,
    glareConvergence: 0.25,
    glareOppositeBias: 1.4,
    glareIntensity: 0.35,
    glareSharpness: -0.08,
    glareAngleOffset: -0.7853981634,
    edgeGain: 4,
  );

  static const Map<String, KitchenGlassParams> presets = <String, KitchenGlassParams>{
    'Lens': lens,
    'Regular': regular,
    'Thumb': thumb,
    'Crystal': crystal,
  };
}
