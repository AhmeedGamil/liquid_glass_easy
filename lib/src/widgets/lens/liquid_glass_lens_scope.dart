import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../utils/liquid_glass_adaptivity.dart';

/// A descendant lens that wants background-luminance updates from the
/// view's adaptive sampler (see `LiquidGlassAdaptivity`).
///
/// Pull-model contract: on every sample the view asks each client for
/// its current region (so scrolled/moved lenses stay accurate for free)
/// and pushes back one averaged luminance value.
abstract mixin class LiquidGlassAdaptiveClient {
  /// The lens rect in [backgroundBox] coordinates, or `null` when the
  /// lens isn't laid out yet (that sample is skipped).
  Rect? adaptiveRegion(RenderBox backgroundBox);

  /// Every rect this client's verdict is voted over — ONE pixel pool
  /// across all of them, so a client spanning disjoint strips (the
  /// scaffold's shared-edges judge) gets a single combined vote, not
  /// one per rect. Rects must not overlap (overlap pixels would vote
  /// twice). Defaults to the single [adaptiveRegion].
  List<Rect> adaptiveRegions(RenderBox backgroundBox) {
    final Rect? region = adaptiveRegion(backgroundBox);
    return region == null ? const <Rect>[] : <Rect>[region];
  }

  /// Optional exact mask for [region], expressed in [backgroundBox]
  /// coordinates. `null` means the whole rectangle participates. A shaped
  /// lens supplies its real outline so transparent bounding-box corners do
  /// not influence the verdict.
  ui.Path? adaptiveMaskPath(RenderBox backgroundBox, Rect region) => null;

  /// Receives the background-only sample used by the perceptual lightness
  /// classifier.
  /// The default bridge keeps older custom clients that only override
  /// [onAdaptiveLuminance] working.
  void onAdaptiveSample(LiquidGlassBackdropSample sample) =>
      onAdaptiveLuminance(sample.meanLuminance, sample.lightFraction);

  /// Legacy sample callback: [luminance] is mean relative luminance and
  /// [lightFraction] is the diagnostic share of perceptually light pixels.
  void onAdaptiveLuminance(double luminance, double lightFraction) {}
}

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

  /// Subscribes a lens to the view's low-res background-luminance
  /// sampler (`LiquidGlassAdaptivity`). `null` when the owning view has
  /// no `adaptiveSampling` config — sampling is opt-in per view, and
  /// adaptive descendants fall back to manual/platform verdicts. When
  /// present, the sampler only runs while at least one client is
  /// registered.
  final void Function(LiquidGlassAdaptiveClient client)? registerAdaptiveClient;

  /// Removes a lens from the adaptive sampler; the sampler stops when
  /// the last client leaves. `null` iff [registerAdaptiveClient] is.
  final void Function(LiquidGlassAdaptiveClient client)?
      unregisterAdaptiveClient;

  const LiquidGlassLensScope({
    super.key,
    required this.useImpellerBackdrop,
    required this.captureRevision,
    required this.currentImage,
    required this.captureFallback,
    required this.backgroundRenderBox,
    this.registerAdaptiveClient,
    this.unregisterAdaptiveClient,
    required super.child,
  });

  static LiquidGlassLensScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LiquidGlassLensScope>();
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
        backgroundRenderBox != oldWidget.backgroundRenderBox ||
        registerAdaptiveClient != oldWidget.registerAdaptiveClient ||
        unregisterAdaptiveClient != oldWidget.unregisterAdaptiveClient;
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

  /// See [LiquidGlassLensScope.registerAdaptiveClient]. Carried across
  /// the route so an adaptive lens inside a dialog samples the page's
  /// background like one on the page would.
  final void Function(LiquidGlassAdaptiveClient client)? registerAdaptiveClient;

  /// See [LiquidGlassLensScope.unregisterAdaptiveClient].
  final void Function(LiquidGlassAdaptiveClient client)?
      unregisterAdaptiveClient;

  const LiquidGlassLensScopePortal({
    super.key,
    required this.useImpellerBackdrop,
    required this.captureRevision,
    required this.currentImage,
    required this.captureFallback,
    required this.backgroundRenderBox,
    this.registerAdaptiveClient,
    this.unregisterAdaptiveClient,
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
      registerAdaptiveClient: registerAdaptiveClient,
      unregisterAdaptiveClient: unregisterAdaptiveClient,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(covariant LiquidGlassLensScopePortal oldWidget) {
    return useImpellerBackdrop != oldWidget.useImpellerBackdrop ||
        captureRevision != oldWidget.captureRevision ||
        currentImage != oldWidget.currentImage ||
        captureFallback != oldWidget.captureFallback ||
        backgroundRenderBox != oldWidget.backgroundRenderBox ||
        registerAdaptiveClient != oldWidget.registerAdaptiveClient ||
        unregisterAdaptiveClient != oldWidget.unregisterAdaptiveClient;
  }
}

/// Redirects **where adaptive-sampling clients register**, overriding
/// the enclosing [LiquidGlassLensScope]'s sampler while leaving its
/// rendering half untouched.
///
/// Installed by a host whose slot subtree lives in a view whose captured
/// image is the wrong one to sample — the animated nav bar's OUTER view
/// captures the bar's glass already composited, so adaptive areas and
/// lenses placed there register with the INNER (pre-glass) view's
/// sampler through this scope instead. One sampler per pipeline, and no
/// widget ever reads its own glass back.
class LiquidGlassAdaptiveSamplerScope extends InheritedWidget {
  /// Subscribes a client to the redirected sampler.
  final void Function(LiquidGlassAdaptiveClient client) register;

  /// Removes a client from the redirected sampler.
  final void Function(LiquidGlassAdaptiveClient client) unregister;

  const LiquidGlassAdaptiveSamplerScope({
    super.key,
    required this.register,
    required this.unregister,
    required super.child,
  });

  static LiquidGlassAdaptiveSamplerScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LiquidGlassAdaptiveSamplerScope>();
  }

  @override
  bool updateShouldNotify(covariant LiquidGlassAdaptiveSamplerScope oldWidget) {
    // Hosts hand in identity-stable functions, so this only notifies
    // when the redirect target really changes.
    return register != oldWidget.register || unregister != oldWidget.unregister;
  }
}
