import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'lens/liquid_glass_batch.dart';
import 'lens/liquid_glass_shape_cache.dart';
import 'liquid_glass_config.dart';
import 'liquid_glass_style.dart';

/// Where a lens blurs the content behind it. Matters only for a lens with
/// `blur` above zero. See [LiquidGlassConfiguration.blurMethod] and
/// [LiquidGlassConfiguration.batchBlurMethod].
enum LiquidGlassBlurMethod {
  /// The engine's Gaussian blur, as a backdrop pass under the glass (or,
  /// inside a `LiquidGlassBatch` in `singlePass` mode, folded into the
  /// glass's own pass).
  engine,

  /// The lens's own shader blurs as it samples the backdrop, so the blur
  /// costs no backdrop pass of its own.
  shader,
}

/// Package-wide settings: how glass blurs, how a batch shares its read,
/// the shape cache, and the blur and dispersion overrides.
///
/// A `LiquidGlassBatch` that leaves one of its own settings `null` takes
/// the matching `batch…` value here; a lens outside any batch takes the
/// others. A `LiquidGlassBlender` follows none of the blur settings.
class LiquidGlassConfiguration {
  LiquidGlassConfiguration._();

  /// Where a lens outside any batch blurs.
  ///
  /// [LiquidGlassBlurMethod.engine] (the default) pushes the engine's
  /// Gaussian blur as a backdrop pass of its own under the shader.
  /// [LiquidGlassBlurMethod.shader] blurs inside the lens's shader, so the
  /// blur adds no pass. A lens in a batch follows [batchBlurMethod] instead.
  /// A `LiquidGlassBlender` follows neither; it keeps its own
  /// `useEngineBlur`. Read when a lens builds.
  static LiquidGlassBlurMethod blurMethod = LiquidGlassBlurMethod.engine;

  /// Where a lens in a batch blurs, for every `LiquidGlassBatch` that leaves
  /// its `blurMethod` `null`.
  ///
  /// [LiquidGlassBlurMethod.engine] (the default) blurs with the engine's
  /// Gaussian, and [batchMode] decides how that blur shares the batch's read.
  /// [LiquidGlassBlurMethod.shader] keeps every member on the batch's single
  /// read with no pass of its own. A lens is in a batch when it joins the
  /// batch's shared key, which is Impeller only. Read when a lens builds.
  static LiquidGlassBlurMethod batchBlurMethod = LiquidGlassBlurMethod.engine;

  /// How a batch shares its read, for every `LiquidGlassBatch` that leaves
  /// its `mode` `null`. [LiquidGlassBatchMode.separatePass] by default. Read
  /// when a lens builds.
  static LiquidGlassBatchMode batchMode = LiquidGlassBatchMode.separatePass;

  /// Whether the shader blur of a lens outside any batch keeps the style's
  /// `dispersion`.
  ///
  /// Off (the default), a lens that blurs in its shader draws no colour
  /// fringe: each blur tap is one backdrop read instead of up to three. On,
  /// every tap is dispersed, and the fringe is blurred with the frost.
  /// Engine-blurred lenses keep their dispersion either way. A lens in a
  /// batch follows [batchShaderBlurDispersion] instead. Read when a lens
  /// builds.
  static bool shaderBlurDispersion = false;

  /// [shaderBlurDispersion] for a lens in a batch, for every
  /// `LiquidGlassBatch` that leaves its `shaderBlurDispersion` `null`. Off
  /// by default. Read when a lens builds.
  static bool batchShaderBlurDispersion = false;

  /// Whether lenses and blenders bake their shape into a texture and read it
  /// back, instead of evaluating it for every pixel on every frame.
  ///
  /// On (the default), a shape is baked once and kept while it only moves:
  /// a new size, radius or corner style bakes again, and so does a blender
  /// member moving against the others. A shape that is still changing — a
  /// resize, a merge — is evaluated per pixel and baked once it holds still
  /// for a frame, so an animation never bakes every frame. Impeller on
  /// Android and iOS; other
  /// renderers always evaluate per pixel. Takes effect on the next paint.
  static bool get shapeCache => LiquidGlassShapeCache.enabled;
  static set shapeCache(bool value) => LiquidGlassShapeCache.enabled = value;

  /// Replaces the blur of every lens and blender when set, in the same
  /// units as `LiquidGlassStyle.blur`. The tab bar's glass and magnifier
  /// pills, the slider thumb and the switch thumb keep their own. Read when
  /// a lens builds.
  static double? blurOverride;

  /// Replaces the dispersion of every lens and blender when set, in the
  /// same units as `LiquidGlassStyle.dispersion`. The same glass as for
  /// [blurOverride] keeps its own. Read when a lens builds.
  static double? dispersionOverride;

  /// [appearance] with [blurOverride] applied, unless [context] sits under
  /// a [LiquidGlassOverrideExclude]. Library-internal.
  @internal
  static LiquidGlassAppearance overrideAppearance(
      BuildContext context, LiquidGlassAppearance appearance) {
    final double? blur = blurOverride;
    if (blur != null && LiquidGlassOverrideExclude.of(context)) {
      return appearance;
    }
    return blur == null ? appearance : appearance.copyWith(blur: blur);
  }

  /// [refraction] with [dispersionOverride] applied, unless [context] sits
  /// under a [LiquidGlassOverrideExclude]. Library-internal.
  @internal
  static LiquidGlassRefraction overrideRefraction(
      BuildContext context, LiquidGlassRefraction refraction) {
    final double? dispersion = dispersionOverride;
    if (dispersion != null && LiquidGlassOverrideExclude.of(context)) {
      return refraction;
    }
    return dispersion == null
        ? refraction
        : refraction.copyWith(dispersion: dispersion);
  }

  /// [style] with both overrides applied. Library-internal.
  @internal
  static LiquidGlassStyle overrideStyle(LiquidGlassStyle style) {
    if (blurOverride == null && dispersionOverride == null) return style;
    return style.copyWith(blur: blurOverride, dispersion: dispersionOverride);
  }
}

/// Keeps the glass under it out of [LiquidGlassConfiguration.blurOverride]
/// and [LiquidGlassConfiguration.dispersionOverride]: it keeps its own blur
/// and dispersion. For glass whose look is part of the control — the tab
/// bar's moving pills, the slider and switch thumbs. Library-internal.
@internal
class LiquidGlassOverrideExclude extends InheritedWidget {
  const LiquidGlassOverrideExclude({super.key, required super.child});

  /// Whether [context] sits under an exclusion.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiquidGlassOverrideExclude>() !=
      null;

  @override
  bool updateShouldNotify(LiquidGlassOverrideExclude oldWidget) => false;
}
