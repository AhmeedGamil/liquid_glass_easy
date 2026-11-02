import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'lens/liquid_glass_batch.dart';
import 'lens/liquid_glass_shape_cache.dart';
import 'components/liquid_glass_shadow.dart';
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

  /// Replaces the shadow colour of every lens and blender that has a shadow,
  /// on a light theme, when set. The same glass as for [blurOverride] keeps
  /// its own. Read when a lens builds.
  static Color? shadowColorOverrideLight;

  /// [shadowColorOverrideLight] on a dark theme.
  static Color? shadowColorOverrideDark;

  /// Whether the glow keeps showing over a dark backdrop.
  ///
  /// On (the default), the glow adds its lightness to whatever is behind
  /// the edge, so it shows even over black. Off, its lift fades out over
  /// dark backdrops: whole from a luma of 0.35 up, down to a tenth over
  /// black. The speculars keep their lift either way, and a glow whose
  /// own `color` is opaque keeps it. Every lens and blender; read when the
  /// glass paints.
  static bool rimLiftOnDark = true;

  /// [appearance] with [blurOverride] and the light/dark colour, saturation
  /// and shadow colour overrides applied, unless [context] sits under a
  /// [LiquidGlassOverrideExclude]. Library-internal.
  @internal
  static LiquidGlassAppearance overrideAppearance(
      BuildContext context, LiquidGlassAppearance appearance) {
    final double? blur = blurOverride;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color? color = !LiquidGlassTintOverride.enabled
        ? null
        : dark
            ? LiquidGlassTintOverride.colorDark
            : LiquidGlassTintOverride.colorLight;
    final double? saturation = !LiquidGlassTintOverride.enabled
        ? null
        : dark
            ? LiquidGlassTintOverride.saturationDark
            : LiquidGlassTintOverride.saturationLight;
    final Color? shadowColor =
        dark ? shadowColorOverrideDark : shadowColorOverrideLight;
    if (blur == null &&
        color == null &&
        saturation == null &&
        shadowColor == null) {
      return appearance;
    }
    if (LiquidGlassOverrideExclude.of(context)) return appearance;
    return appearance.copyWith(
      blur: blur,
      color: color,
      saturation: saturation,
      shadow: _recolor(appearance.shadow, shadowColor),
    );
  }

  /// [shadow] in [color]; [shadow] itself when either is null.
  static LiquidGlassShadow? _recolor(LiquidGlassShadow? shadow, Color? color) {
    if (shadow == null || color == null) return shadow;
    return LiquidGlassShadow(
      key: shadow.key,
      blur: shadow.blur,
      opacity: shadow.opacity,
      color: color,
      offset: shadow.offset,
      cornerRadius: shadow.cornerRadius,
      scale: shadow.scale,
      inset: shadow.inset,
      visible: shadow.visible,
      insideGlass: shadow.insideGlass,
      child: shadow.child,
    );
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

  /// [style] with every override applied, the light/dark ones for
  /// [brightness]. Library-internal.
  @internal
  static LiquidGlassStyle overrideStyle(
    LiquidGlassStyle style, {
    Brightness brightness = Brightness.light,
  }) {
    final bool dark = brightness == Brightness.dark;
    final Color? color = !LiquidGlassTintOverride.enabled
        ? null
        : dark
            ? LiquidGlassTintOverride.colorDark
            : LiquidGlassTintOverride.colorLight;
    final double? saturation = !LiquidGlassTintOverride.enabled
        ? null
        : dark
            ? LiquidGlassTintOverride.saturationDark
            : LiquidGlassTintOverride.saturationLight;
    final Color? shadowColor =
        dark ? shadowColorOverrideDark : shadowColorOverrideLight;
    if (blurOverride == null &&
        dispersionOverride == null &&
        color == null &&
        saturation == null &&
        shadowColor == null) {
      return style;
    }
    return style.copyWith(
      blur: blurOverride,
      dispersion: dispersionOverride,
      color: color,
      saturation: saturation,
      shadow: _recolor(style.shadow, shadowColor),
    );
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

/// The global tint: while [enabled], every lens and blender takes
/// [colorLight] and [saturationLight] on a light theme, [colorDark] and
/// [saturationDark] on a dark one, in place of its own colour and
/// saturation, an adaptive verdict's tint included. The tab bar's glass
/// and magnifier pills, the slider thumb and the switch thumb keep their
/// own. Read when a lens builds; the theme is the app's
/// (`Theme.of(context).brightness`).
///
/// Not exported yet: the gallery imports it from `src/`.
class LiquidGlassTintOverride {
  LiquidGlassTintOverride._();

  /// Whether the global tint applies. Off by default.
  static bool enabled = false;

  /// The tint on a light theme: white at about 68% by default.
  static Color colorLight = const Color(0xADFFFFFF);

  /// The tint on a dark theme: a near black (28, 28, 31) at about 55% by
  /// default.
  static Color colorDark = const Color(0x8C1C1C1F);

  /// The saturation on a light theme. `2` by default.
  static double saturationLight = 2.0;

  /// The saturation on a dark theme. `1.2` by default.
  static double saturationDark = 1.2;
}
