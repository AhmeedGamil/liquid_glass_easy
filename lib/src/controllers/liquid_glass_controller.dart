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

  /// Shows the LiquidGlass lens with an animation.
  ///
  /// This method animates the distortion from its starting value
  /// (`distortionBegin`) up to `1.0`, making the lens fully visible.
  ///
  /// Parameters:
  /// - [animationTimeMillisecond]: Optional override for the animation duration.
  ///   If not provided, the default duration inside the widget is used.
  ///
  /// - [onComplete]: Optional callback executed after the animation finishes.
  ///
  /// Use this when you want to reveal the lens with a smooth transition.
  void showLiquidGlass({int? animationTimeMillisecond, VoidCallback? onComplete}) {
    _showLiquidGlass?.call(
      animationTimeMillisecond: animationTimeMillisecond,
      onComplete: onComplete,
    );
  }

  /// Hides the LiquidGlass lens with an animation.
  ///
  /// This method animates the distortion from `1.0` back down to
  /// `distortionBegin`, making the lens appear to fade out or soften.
  ///
  /// Parameters:
  /// - [animationTimeMillisecond]: Optional override for how long the hide
  ///   animation should take.
  ///
  /// - [onComplete]: Optional callback triggered after the hide animation ends.
  ///
  /// Use this when you want to dismiss the lens smoothly.
  void hideLiquidGlass({int? animationTimeMillisecond, VoidCallback? onComplete}) {
    _hideLiquidGlass?.call(
      animationTimeMillisecond: animationTimeMillisecond,
      onComplete: onComplete,
    );
  }

  /// Instantly resets the LiquidGlass lens position.
  ///
  /// This method does **not** animate. It immediately snaps the lens back to
  /// its default/original position.
  ///
  /// Useful for:
  /// - resetting drag gestures,
  /// - centering the lens,
  /// - restoring position after navigation changes.
  void resetLiquidGlassPosition() {
    _resetLiquidGlassPosition?.call();
  }
}
