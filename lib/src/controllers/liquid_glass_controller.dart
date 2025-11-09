import 'dart:ui';

class LiquidGlassController {
  void Function({int? animationTimeMillisecond, VoidCallback? onComplete})?
  _showLiquidGlass;
  void Function({int? animationTimeMillisecond, VoidCallback? onComplete})?
  _hideLiquidGlass;
  void Function()?
  _resetLiquidGlassPosition;
  void attach({
    required void Function({int? animationTimeMillisecond, VoidCallback? onComplete}) showLiquidGlass,
    required void Function({int? animationTimeMillisecond, VoidCallback? onComplete}) hideLiquidGlass,
    required void Function()resetLiquidGlassPosition,

  }) {
    _showLiquidGlass = showLiquidGlass;
    _hideLiquidGlass = hideLiquidGlass;
    _resetLiquidGlassPosition=resetLiquidGlassPosition;
  }

  void detach() {
    _showLiquidGlass = null;
    _hideLiquidGlass = null;
    _resetLiquidGlassPosition=null;
  }

  /// Animate from distortionBegin → 1
  void showLiquidGlass({int? animationTimeMillisecond, VoidCallback? onComplete}) {
    _showLiquidGlass?.call(
      animationTimeMillisecond: animationTimeMillisecond,
      onComplete: onComplete,
    );
  }

  /// Animate from 1 → distortionBegin
  void hideLiquidGlass({int? animationTimeMillisecond, VoidCallback? onComplete}) {
    _hideLiquidGlass?.call(
      animationTimeMillisecond: animationTimeMillisecond,
      onComplete: onComplete,
    );
  }

  void resetLiquidGlassPosition() {
    _resetLiquidGlassPosition?.call();
  }
}
