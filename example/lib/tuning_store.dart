import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Shared, in-memory tuning store.
//
// The tuner pages (nav motion tuner, slider motion tuner) WRITE to these
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
  final LiquidGlassLensMotionSpec motion;
  final double travelStiffness;
  final double travelDamping;
  final double growHeight;

  /// Light direction (degrees) of the bar capsule's rim.
  final double lightDirection;

  /// The bar capsule's frosted background tint.
  final Color background;

  const NavTuning({
    required this.motion,
    required this.travelStiffness,
    required this.travelDamping,
    required this.growHeight,
    required this.lightDirection,
    required this.background,
  });

  /// Shipped defaults — mirror [LiquidGlassTabPillStyle]'s tuned motion and
  /// the scaffold demo's dark frost, with light direction 39.
  static const NavTuning defaults = NavTuning(
    motion: LiquidGlassLensMotionSpec(
      sampleWindow: 0.3,
      sensitivity: 0.00007,
      maxDeformation: 0.12,
      responseTime: 0.18,
    ),
    travelStiffness: 280,
    travelDamping: 31.4,
    growHeight: 12,
    lightDirection: 39,
    background: Color(0x40000000),
  );

  NavTuning copyWith({
    LiquidGlassLensMotionSpec? motion,
    double? travelStiffness,
    double? travelDamping,
    double? growHeight,
    double? lightDirection,
    Color? background,
  }) {
    return NavTuning(
      motion: motion ?? this.motion,
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
