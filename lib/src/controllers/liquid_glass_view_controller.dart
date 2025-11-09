import 'dart:ui';

class LiquidGlassViewController {
  Future<void> Function()? _captureOnce;
  VoidCallback? _startRealtimeCapture;
  VoidCallback? _stopRealtimeCapture;

  void attach({
    required Future<void> Function() captureOnce,
    required VoidCallback startRealtime,
    required VoidCallback stopRealtime,
  }) {
    _captureOnce = captureOnce;
    _startRealtimeCapture = startRealtime;
    _stopRealtimeCapture = stopRealtime;
  }

  void detach() {
    _captureOnce = null;
    _startRealtimeCapture = null;
    _stopRealtimeCapture = null;
  }

  Future<void> captureOnce() async {
    await _captureOnce?.call();
  }

  void startRealtimeCapture() {
    _startRealtimeCapture?.call();
  }

  void stopRealtimeCapture() {
    _stopRealtimeCapture?.call();
  }
}