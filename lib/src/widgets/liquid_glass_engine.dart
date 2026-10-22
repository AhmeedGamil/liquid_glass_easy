import 'dart:ui' as ui;

import 'lens/liquid_glass_shape_cache.dart';

/// Package-wide renderer switches.
class LiquidGlassEngine {
  LiquidGlassEngine._();

  /// Lite glass for every lens on Skia / Web, instead of the capture path.
  ///
  /// Off (the default), a lens inside a `LiquidGlassView` on Skia refracts
  /// the view's captured background. On, the view takes no glass capture at
  /// all and every lens draws `LiquidGlassLite` — frost, tint and a painted
  /// rim, no refraction — the same thing a lens outside any
  /// view draws. The adaptive sampler is not a glass capture and keeps
  /// running. Set it once, before the first lens builds:
  ///
  /// ```dart
  /// LiquidGlassEngine.liteGlassOnSkia = true;
  /// ```
  ///
  /// A single lens can opt in on its own through
  /// `LiquidGlassStyle.liteGlass`.
  static bool liteGlassOnSkia = false;

  /// Lite glass for every lens on Impeller, instead of the shader.
  ///
  /// Off (the default), a lens on Impeller refracts the live backdrop through
  /// its fragment shader. On, every lens draws `LiquidGlassLite` instead: no
  /// shader pass, no slot in the lens budget. Same rule as [liteGlassOnSkia],
  /// on the other engine.
  static bool liteGlassOnImpeller = false;

  /// Whether every lens is drawing lite glass right now: the switch for the
  /// engine this app runs on.
  static bool get liteGlass => ui.ImageFilter.isShaderFilterSupported
      ? liteGlassOnImpeller
      : liteGlassOnSkia;

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
}
