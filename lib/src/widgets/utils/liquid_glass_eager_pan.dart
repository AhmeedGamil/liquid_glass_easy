import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A [PanGestureRecognizer] that wins the gesture arena the instant a
/// pointer lands, instead of waiting to accumulate drag slop.
///
/// Every grab-and-carry glass control wants the two things that follow
/// from it. The control beats an ancestor [Scrollable]: normally both
/// join the arena and the scrollable wins as soon as the finger drifts
/// vertically, stealing the drag mid-gesture. And paired with
/// [DragStartBehavior.down], `onStart` fires at touch-down, so the thumb
/// swells the instant it is touched rather than after the slop.
class LiquidGlassEagerPanGestureRecognizer extends PanGestureRecognizer {
  LiquidGlassEagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// The gesture map a grab-and-carry control hands to a
/// [RawGestureDetector]: one [LiquidGlassEagerPanGestureRecognizer]
/// reporting **global** positions.
///
/// Global, not deltas, because these controls place the thumb from where
/// the finger is relative to where it landed — the caller converts once,
/// through its own render box.
///
/// [onCancel] defaults to [onUp]: a control that treats a cancelled
/// gesture as a release needs nothing extra.
Map<Type, GestureRecognizerFactory> liquidGlassEagerPanGestures({
  Object? debugOwner,
  required ValueChanged<Offset> onDown,
  required ValueChanged<Offset> onMove,
  required VoidCallback onUp,
  VoidCallback? onCancel,
}) {
  return <Type, GestureRecognizerFactory>{
    LiquidGlassEagerPanGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<
            LiquidGlassEagerPanGestureRecognizer>(
      () => LiquidGlassEagerPanGestureRecognizer(debugOwner: debugOwner),
      (instance) {
        instance
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = (d) {
            onDown(d.globalPosition);
          }
          ..onUpdate = (d) {
            onMove(d.globalPosition);
          }
          ..onEnd = (_) {
            onUp();
          }
          ..onCancel = onCancel ?? onUp;
      },
    ),
  };
}
