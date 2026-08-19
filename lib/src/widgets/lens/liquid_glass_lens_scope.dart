import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Connection between a `LiquidGlassView` and the `LiquidGlassLens`
/// widgets living anywhere inside its `child` subtree.
///
/// This is the **registration half** of the lens-anywhere design: the
/// view exposes everything a descendant lens needs to render, and the
/// lens looks it up with [maybeOf]. How the lens then paints (live
/// Impeller backdrop vs. sampling the view's captured background) is an
/// implementation detail behind this contract — the widget tree shape
/// never changes when the renderer does.
class LiquidGlassLensScope extends InheritedWidget {
  /// Whether the owning view renders lenses through
  /// `BackdropFilter(ImageFilter.shader(...))` (Impeller) instead of
  /// the capture pipeline (Skia / Web).
  final bool useImpellerBackdrop;

  /// Bumped after every successful background capture (Skia path).
  /// Lenses repaint when this ticks; the actual image is read through
  /// [currentImage] at paint time so paint never holds a stale frame.
  final ValueListenable<int> captureRevision;

  /// Latest captured background snapshot, or null before the first
  /// capture lands. Always a full-frame capture of the view's
  /// background boundary.
  final ui.Image? Function() currentImage;

  /// Paint-time synchronous capture fallback — rasterizes the already-
  /// painted background boundary when [currentImage] is still null (the
  /// view's very first frame), so a lens refracts on frame one.
  final ui.Image? Function() captureFallback;

  /// The render box of the background `RepaintBoundary` — the
  /// coordinate space the captured image lives in. Lenses map their own
  /// rect into this space with `getTransformTo`.
  final RenderBox? Function() backgroundRenderBox;

  const LiquidGlassLensScope({
    super.key,
    required this.useImpellerBackdrop,
    required this.captureRevision,
    required this.currentImage,
    required this.captureFallback,
    required this.backgroundRenderBox,
    required super.child,
  });

  static LiquidGlassLensScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LiquidGlassLensScope>();
  }

  @override
  bool updateShouldNotify(covariant LiquidGlassLensScope oldWidget) {
    // The function members are instance-method tear-offs from the view's
    // State, which compare equal across rebuilds of the same State, so
    // this only notifies on a real configuration change.
    return useImpellerBackdrop != oldWidget.useImpellerBackdrop ||
        captureRevision != oldWidget.captureRevision ||
        currentImage != oldWidget.currentImage ||
        captureFallback != oldWidget.captureFallback ||
        backgroundRenderBox != oldWidget.backgroundRenderBox;
  }
}

/// Carries a view's [LiquidGlassLensScope] across a route boundary.
///
/// A dialog or menu opened with `showGeneralDialog` builds inside the
/// navigator's overlay, not inside the view that captured the page, so a
/// lens up there has no capture to refract and the Skia path falls back
/// to flat frost. The view plants one of these around its whole subtree;
/// `InheritedTheme.capture` — the same call that carries `Theme` into a
/// route — collects it, and [wrap] re-plants a real scope inside the
/// route. On Impeller nothing changes: the lens was already sampling the
/// live backdrop and never needed the scope at all.
///
/// Lenses do not look this up, only the scope proper. That is deliberate:
/// a lens sitting in the view's own `backgroundWidget` still finds
/// nothing and stays frosted, rather than refracting a capture of itself.
class LiquidGlassLensScopePortal extends InheritedTheme {
  /// See [LiquidGlassLensScope.useImpellerBackdrop].
  final bool useImpellerBackdrop;

  /// See [LiquidGlassLensScope.captureRevision].
  final ValueListenable<int> captureRevision;

  /// See [LiquidGlassLensScope.currentImage].
  final ui.Image? Function() currentImage;

  /// See [LiquidGlassLensScope.captureFallback].
  final ui.Image? Function() captureFallback;

  /// See [LiquidGlassLensScope.backgroundRenderBox].
  final RenderBox? Function() backgroundRenderBox;

  const LiquidGlassLensScopePortal({
    super.key,
    required this.useImpellerBackdrop,
    required this.captureRevision,
    required this.currentImage,
    required this.captureFallback,
    required this.backgroundRenderBox,
    required super.child,
  });

  @override
  Widget wrap(BuildContext context, Widget child) {
    return LiquidGlassLensScope(
      useImpellerBackdrop: useImpellerBackdrop,
      captureRevision: captureRevision,
      currentImage: currentImage,
      captureFallback: captureFallback,
      backgroundRenderBox: backgroundRenderBox,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(covariant LiquidGlassLensScopePortal oldWidget) {
    return useImpellerBackdrop != oldWidget.useImpellerBackdrop ||
        captureRevision != oldWidget.captureRevision ||
        currentImage != oldWidget.currentImage ||
        captureFallback != oldWidget.captureFallback ||
        backgroundRenderBox != oldWidget.backgroundRenderBox;
  }
}
