import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Whether the gallery paints itself dark.
///
/// The Settings page flips it with a glass switch; the gallery's
/// [MaterialApp] rebuilds from it, so every demo opened from the menu
/// inherits the brightness through `Theme.of(context)` without knowing
/// this notifier exists.
///
/// Lives in its own file so a page can read or flip it without importing
/// the gallery that imports the page.
final ValueNotifier<bool> darkMode = ValueNotifier<bool>(true);

/// Whether every lens in the gallery draws lite glass — frost, tint and rim,
/// no shader and no capture — on whichever engine the app is on.
///
/// Flipping it sets both `LiquidGlassEngine` switches; the gallery's
/// [MaterialApp] rebuilds from it too, so a page already on screen redraws
/// its lenses instead of waiting to be reopened.
final ValueNotifier<bool> liteGlass = ValueNotifier<bool>(false)
  ..addListener(() {
    LiquidGlassEngine.liteGlassOnSkia = liteGlass.value;
    LiquidGlassEngine.liteGlassOnImpeller = liteGlass.value;
  });

/// Whether lenses and blenders read a baked shape instead of evaluating it
/// per pixel; flips `LiquidGlassConfiguration.shapeCache`.
final ValueNotifier<bool> shapeCache = ValueNotifier<bool>(true)
  ..addListener(() => LiquidGlassConfiguration.shapeCache = shapeCache.value);

/// Whether the gallery shows Flutter's performance overlay — the raster
/// and UI frame graphs — over every page. The Settings page flips it; the
/// gallery's [MaterialApp] rebuilds from it.
final ValueNotifier<bool> performanceOverlay = ValueNotifier<bool>(false);

/// The gallery's page backdrop for [brightness]: a deep violet wash in the
/// dark, the same hue bleached to near-paper in the light.
///
/// Shared by the home menu and the Settings page so the two read as one
/// surface when you push between them.
LinearGradient galleryBackground(Brightness brightness) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [Color(0xFF0B0A12), Color(0xFF17112E), Color(0xFF241543)]
        : const [Color(0xFFF7F6FB), Color(0xFFEFE9FB), Color(0xFFE6DDF7)],
  );
}

/// The theme every demo page is opened under.
///
/// Lives here rather than in the gallery because the pages are opened
/// from more than one place — the gallery, a standalone `-t` entry
/// point, the docs-site build — and a page that looks different
/// depending on who pushed it is a page nobody can check.
ThemeData galleryTheme(Brightness brightness) => ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C5CFF),
        brightness: brightness,
      ),
      useMaterial3: true,
    );

/// Whether batches split an engine blur into a pass of its own; sets
/// `LiquidGlassConfiguration.batchMode`, which a lens reads when it builds.
final ValueNotifier<bool> separatePassBatch = ValueNotifier<bool>(true)
  ..addListener(() => LiquidGlassConfiguration.batchMode = separatePassBatch.value
      ? LiquidGlassBatchMode.separatePass
      : LiquidGlassBatchMode.singlePass);

/// Whether the gallery's views, scaffolds, batches, sheets and dialogs
/// batch their glass at all. The Settings page flips it; a page reads it
/// when it builds.
final ValueNotifier<bool> galleryBatchEnabled = ValueNotifier<bool>(true);

/// The `batch` flag every view, scaffold, sheet and dialog is given.
bool get galleryBatch => galleryBatchEnabled.value;

/// Whether a lens outside any batch blurs inside its shader instead of an
/// engine blur pass; sets `LiquidGlassConfiguration.blurMethod`, which a lens reads
/// when it builds.
final ValueNotifier<bool> shaderBlur = ValueNotifier<bool>(
    LiquidGlassConfiguration.blurMethod == LiquidGlassBlurMethod.shader)
  ..addListener(() => LiquidGlassConfiguration.blurMethod = shaderBlur.value
      ? LiquidGlassBlurMethod.shader
      : LiquidGlassBlurMethod.engine);

/// The same for a lens in a batch; sets `LiquidGlassConfiguration.batchBlurMethod`.
final ValueNotifier<bool> batchShaderBlur = ValueNotifier<bool>(
    LiquidGlassConfiguration.batchBlurMethod == LiquidGlassBlurMethod.shader)
  ..addListener(() => LiquidGlassConfiguration.batchBlurMethod = batchShaderBlur.value
      ? LiquidGlassBlurMethod.shader
      : LiquidGlassBlurMethod.engine);

/// Whether a batched lens's shader blur keeps the dispersion; sets
/// `LiquidGlassConfiguration.batchShaderBlurDispersion`.
final ValueNotifier<bool> batchShaderBlurDispersion =
    ValueNotifier<bool>(LiquidGlassConfiguration.batchShaderBlurDispersion)
      ..addListener(() => LiquidGlassConfiguration.batchShaderBlurDispersion =
          batchShaderBlurDispersion.value);

/// Whether an unbatched lens's shader blur keeps the dispersion; sets
/// `LiquidGlassConfiguration.shaderBlurDispersion`.
final ValueNotifier<bool> shaderBlurDispersion =
    ValueNotifier<bool>(LiquidGlassConfiguration.shaderBlurDispersion)
      ..addListener(() =>
          LiquidGlassConfiguration.shaderBlurDispersion = shaderBlurDispersion.value);

/// Whether [glassBlur] and [glassDispersion] replace every lens's own.
final ValueNotifier<bool> overrideGlass = ValueNotifier<bool>(false)
  ..addListener(_applyGlassOverrides);

/// The blur every lens takes while [overrideGlass] is on.
final ValueNotifier<double> glassBlur = ValueNotifier<double>(3.0)
  ..addListener(_applyGlassOverrides);

/// The dispersion every lens takes while [overrideGlass] is on.
final ValueNotifier<double> glassDispersion = ValueNotifier<double>(0.0)
  ..addListener(_applyGlassOverrides);

void _applyGlassOverrides() {
  final bool on = overrideGlass.value;
  LiquidGlassConfiguration.blurOverride = on ? glassBlur.value : null;
  LiquidGlassConfiguration.dispersionOverride = on ? glassDispersion.value : null;
}
