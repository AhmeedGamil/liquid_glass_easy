import 'dart:ui' as ui;

import 'components/liquid_glass_lite.dart';

/// Package-wide renderer switches.
class LiquidGlassEngine {
  LiquidGlassEngine._();

  /// Lite glass for every lens on Skia / Web, instead of the capture path.
  ///
  /// Off (the default), a lens inside a `LiquidGlassView` on Skia refracts
  /// the view's captured background. On, the view takes no glass capture at
  /// all and every lens draws `LiquidGlassLite` — frost, tint and a rim cut
  /// from the backdrop, no refraction — the same thing a lens outside any
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

  /// Where a lens drawn lite by the switches above — or while its shaders
  /// load — takes its rim colour from. `backdrop` (the default) reads the
  /// background along the rim as the shader does, for one read; `blend` and
  /// `surface` cost no read; `none` is white light. A style that sets its
  /// own `LiquidGlassStyle.liteGlass` names its own and ignores this.
  static LiquidGlassLitePickup litePickup = LiquidGlassLitePickup.backdrop;
}
