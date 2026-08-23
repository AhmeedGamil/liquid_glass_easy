import 'dart:ui';

import 'package:meta/meta.dart';

import '../widgets/lens/liquid_glass_lens_scope.dart';

class LiquidGlassViewController {
  Future<void> Function()? _captureOnce;
  VoidCallback? _startRealtimeCapture;
  VoidCallback? _stopRealtimeCapture;
  void Function(LiquidGlassAdaptiveClient client)? _registerAdaptiveClient;
  void Function(LiquidGlassAdaptiveClient client)? _unregisterAdaptiveClient;

  void attach({
    required Future<void> Function() captureOnce,
    required VoidCallback startRealtime,
    required VoidCallback stopRealtime,
    void Function(LiquidGlassAdaptiveClient client)? registerAdaptiveClient,
    void Function(LiquidGlassAdaptiveClient client)? unregisterAdaptiveClient,
  }) {
    _captureOnce = captureOnce;
    _startRealtimeCapture = startRealtime;
    _stopRealtimeCapture = stopRealtime;
    _registerAdaptiveClient = registerAdaptiveClient;
    _unregisterAdaptiveClient = unregisterAdaptiveClient;
  }

  void detach() {
    _captureOnce = null;
    _startRealtimeCapture = null;
    _stopRealtimeCapture = null;
    _registerAdaptiveClient = null;
    _unregisterAdaptiveClient = null;
  }

  /// Captures a single static frame of the background widget of the LiquidGlassView.
  ///
  /// This performs a one-time capture and updates all attached LiquidGlass
  /// lenses using that snapshot. No continuous updates are performed.
  ///
  /// Use this when:
  /// - you want a snapshot-based lens (static blur/distortion),
  /// - performance is more important than real-time capturing,
  /// - the background does not need continuous updates.
  ///
  /// If real-time capture is active, this does **not** stop it.
  Future<void> captureOnce() async {
    await _captureOnce?.call();
  }

  /// Starts real-time capturing of the background widget of the LiquidGlassView.
  ///
  /// This continuously updates the background at a rate determined
  /// by the internal refresh pipeline. It enables fully dynamic
  /// LiquidGlass effects (blurring, distortion, magnification, etc.) that
  /// react to movement or animations behind the lens.
  ///
  /// Use this when:
  /// - you want the lens background to change with the scene,
  /// - you want a live "glass" effect instead of a static snapshot.
  ///
  /// The update rate depends on your internal configuration
  /// (e.g., refresh rate, device pixel ratio, async/sync mode).
  void startRealtimeCapture() {
    _startRealtimeCapture?.call();
  }

  /// Stop real-time capturing of the background widget of the LiquidGlassView.
  ///
  /// After calling this, the LiquidGlassView stops updating the background content
  /// and uses static background using the last captured frame.
  ///
  /// Use this when:
  /// - the lens no longer needs the background to be updated,
  /// - improving performance or battery usage,
  /// - switching screens or reducing load.
  ///
  /// Safe to call even if real-time capture is not active.
  void stopRealtimeCapture() {
    _stopRealtimeCapture?.call();
  }

  /// Subscribes a client to the attached view's adaptive sampler. Used
  /// by hosts (the animated nav bar) to redirect out-of-view clients to
  /// this view's single sampler. No-op while detached or when the view
  /// has no `adaptiveSampling`.
  @internal
  void registerAdaptiveClient(LiquidGlassAdaptiveClient client) {
    _registerAdaptiveClient?.call(client);
  }

  /// Removes a client from the attached view's adaptive sampler.
  @internal
  void unregisterAdaptiveClient(LiquidGlassAdaptiveClient client) {
    _unregisterAdaptiveClient?.call(client);
  }
}
