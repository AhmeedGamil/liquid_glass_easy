import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Shared, in-memory tuning store.
//
// The tuner pages (nav jelly tuner, slider jelly tuner) WRITE to these
// notifiers; the polished demos (scaffold demo, slider & toggle page)
// LISTEN via [ValueListenableBuilder]. Values live only for the current
// session — they are NOT persisted to disk. Restarting the app resets
// everything to the shipped defaults.
//
//   TuningStore.instance.nav.value = ...; // a tuner commits
// =============================================================

/// Everything the bottom-nav glass pill + bar reads from the tuner.
@immutable
class NavTuning {
  final LiquidGlassJellyConfig jelly;
  final double travelStiffness;
  final double travelDamping;
  final double growHeight;

  /// Light direction (degrees) of the bar capsule's rim.
  final double lightDirection;

  /// The bar capsule's frosted background tint.
  final Color background;

  const NavTuning({
    required this.jelly,
    required this.travelStiffness,
    required this.travelDamping,
    required this.growHeight,
    required this.lightDirection,
    required this.background,
  });

  /// Shipped defaults — mirror [LiquidGlassNavPillStyle]'s tuned jelly and
  /// the scaffold demo's dark frost, with light direction 39.
  static const NavTuning defaults = NavTuning(
    jelly: LiquidGlassJellyConfig(
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
    travelStiffness: 280,
    travelDamping: 31.4,
    growHeight: 12,
    lightDirection: 39,
    background: Color(0x40000000),
  );

  NavTuning copyWith({
    LiquidGlassJellyConfig? jelly,
    double? travelStiffness,
    double? travelDamping,
    double? growHeight,
    double? lightDirection,
    Color? background,
  }) {
    return NavTuning(
      jelly: jelly ?? this.jelly,
      travelStiffness: travelStiffness ?? this.travelStiffness,
      travelDamping: travelDamping ?? this.travelDamping,
      growHeight: growHeight ?? this.growHeight,
      lightDirection: lightDirection ?? this.lightDirection,
      background: background ?? this.background,
    );
  }
}

/// What the [LiquidGlassSlider] reads from its tuner.
@immutable
class SliderTuning {
  final LiquidGlassLensMotionSpec motion;

  const SliderTuning({required this.motion});

  /// Shipped defaults — mirror [LiquidGlassSlider]'s tuned motion.
  static const SliderTuning defaults = SliderTuning(
    motion: LiquidGlassLensMotionSpec(),
  );

  SliderTuning copyWith({LiquidGlassLensMotionSpec? motion}) =>
      SliderTuning(motion: motion ?? this.motion);
}

/// In-memory holder for the demo tuning values. No disk persistence: a
/// tuner writes a notifier, the matching demo listens, and the values are
/// gone on restart.
class TuningStore {
  TuningStore._();
  static final TuningStore instance = TuningStore._();

  final ValueNotifier<NavTuning> nav =
      ValueNotifier<NavTuning>(NavTuning.defaults);
  final ValueNotifier<SliderTuning> slider =
      ValueNotifier<SliderTuning>(SliderTuning.defaults);

  /// Restores both groups to the shipped defaults (in memory).
  void resetAll() {
    nav.value = NavTuning.defaults;
    slider.value = SliderTuning.defaults;
  }
}
