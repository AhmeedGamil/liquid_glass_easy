import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens_scope.dart';
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_shaders.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';
// Flutter only re-exports `internal` from foundation.dart on newer SDKs.
// ignore: unnecessary_import
import 'package:meta/meta.dart';

// Main container that renders LiquidGlass lenses on top of a background
class LiquidGlassView extends StatefulWidget {
  /// Controls the LiquidGlass rendering performance and synchronization pipeline.
  /// Manages how often background captures and shader updates occur to balance
  /// visual quality and frame rate performance.
  final LiquidGlassViewController? controller;

  /// The list of individual `LiquidGlass` lenses rendered in this view.
  /// Each lens defines its own shape, distortion, and behavior.
  ///
  /// **Internal.** This is the classic, position-driven path; it is only
  /// populated through the [LiquidGlassView.withPositionedLenses]
  /// constructor, used by the package's own components. The public
  /// constructor always leaves it empty. App developers place
  /// `LiquidGlassLens` widgets inside [child] instead.
  final List<LiquidGlass> children;

  /// An arbitrary widget tree rendered **on top of** [backgroundWidget]
  /// and below the [children] lenses. Place `LiquidGlassLens` widgets
  /// anywhere inside it — in a `Stack`, a `Column`, a scrollable — and
  /// they connect to this view automatically:
  ///
  ///  * On Impeller they refract the live backdrop behind them.
  ///  * On Skia / Web they refract this view's captured
  ///    [backgroundWidget] (which is required for refraction there).
  final Widget? child;

  /// The device pixel ratio used when capturing and rendering the lens effects.
  /// Higher values enhance lens content quality and clarity but also significantly
  /// impact performance by increasing GPU memory usage and rendering cost.
  ///
  /// If the background widget covers the entire screen, this setting can cause a
  /// **high performance impact**. In such cases, it is recommended to keep the
  /// value **below 1.0** and rely on blur effects for smoother visuals instead of
  /// higher pixel density.
  ///
  /// A value of **0.0** uses the device’s default pixel ratio, while **1.0** is the
  /// maximum recommended value for maintaining a balance between visual quality
  /// and frame rate.
  final double pixelRatio;

  /// Enables or disables real-time background capture for the lenses.
  /// When `true`, the background beneath each lens is updated every frame,
  /// producing dynamic refraction.
  /// When `false`, a cached snapshot is reused for better efficiency.
  final bool realTimeCapture;

  /// Determines whether lens rendering is synchronized with Flutter’s frame callbacks.
  /// When `true`, updates are aligned with Flutter’s rendering pipeline, resulting in
  /// smoother animations and generally faster performance.
  ///
  /// When `false`, updates run asynchronously, which can provide higher throughput
  /// on powerful devices, but may introduce slight delays or
  /// less consistent frame timing.
  ///
  /// It is slower than synchronous mode, but it becomes very stable
  /// when the pixel ratio is low (e.g., around 0.5).
  final bool useSync;

  /// The widget tree drawn behind all LiquidGlass lenses.
  /// Typically a static or animated background (such as an `Image`, `Stack`, or
  /// complex layout) over which the lenses apply refraction and effects.
  ///
  /// Required: a `LiquidGlassView` exists to provide the captured
  /// background its lenses refract. On **Skia / Web** this is the
  /// capture source. On **Impeller** it renders normally behind the
  /// content and the live backdrop sampling picks it up.
  ///
  /// If you don't need a refractable background (Impeller only), don't
  /// use a `LiquidGlassView` at all — place `LiquidGlassLens` widgets
  /// directly in your tree; they work standalone there.
  final Widget backgroundWidget;

  /// Controls how frequently the background is re-captured while real-time updates are enabled.
  ///
  /// - [LiquidGlassRefreshRate.low] = ~10 FPS (energy saving)
  /// - [LiquidGlassRefreshRate.medium] = ~24 FPS (balanced)
  /// - [LiquidGlassRefreshRate.high] = ~60 FPS (smooth)
  /// - [LiquidGlassRefreshRate.deviceRefreshRate] = tries to match the display refresh rate
  final LiquidGlassRefreshRate refreshRate;

  /// Override for the Impeller fast-path detection.
  ///
  /// When non-null, forces the renderer to use the
  /// `BackdropFilter(filter: ImageFilter.shader(...))` path (`true`)
  /// or the legacy `RepaintBoundary` + `toImage` capture path
  /// (`false`).
  ///
  /// When null (the default), the renderer auto-detects via
  /// `ui.ImageFilter.isShaderFilterSupported`. Note that this getter
  /// can return `true` on Skia in newer Flutter versions even when
  /// Impeller is disabled — if you launch with
  /// `--no-enable-impeller` and lenses fail to render, set this to
  /// `false` explicitly.
  final bool? useImpellerBackdrop;

  /// Per-lens region capture (Skia **sync** path only).
  ///
  /// When `true`, each per-frame capture grabs one small sub-image per
  /// lens (the lens's own rect plus a small safety margin) instead of
  /// rasterizing the whole [backgroundWidget], and the shader remaps
  /// each sub-image via `u_imageOffset`/`u_imageSize`. Refraction
  /// always samples inward, so the lens rect is all the shader needs.
  ///
  /// This is a performance optimization for views whose lenses cover a
  /// small fraction of a large background (e.g. one draggable lens over
  /// a full-screen photo): the capture cost scales with the captured
  /// area. With many lenses spread across the view the per-capture
  /// overhead multiplies, so measure before enabling.
  ///
  /// No effect on the Impeller path (which samples the live backdrop
  /// directly, with no captures at all) or on views with
  /// `useSync: false` (async captures are always full-frame).
  final bool regionCapture;

  /// **Internal.** Whether each `children` lens folds the captured
  /// backdrop's alpha into its coverage (the shader's
  /// `u_honorBackdropAlpha`), on the Skia capture path only. Defaults to
  /// `false` — the capture is treated as opaque (matching Impeller), which
  /// keeps the optical rim and avoids washing the lens body white. Set
  /// `true` only when the captured `backgroundWidget` carries *authored*
  /// transparency that must show through the glass — i.e. the
  /// slider/toggle track. No effect on the Impeller path or on lens-
  /// anywhere `child` lenses.
  final bool honorBackdropAlpha;

  /// Creates a liquid-glass view: a background-capture / refraction
  /// provider. Place `LiquidGlassLens` widgets anywhere inside [child] —
  /// they connect to this view automatically. There is no positioned-lens
  /// slot in the public API.
  const LiquidGlassView(
      {super.key,
      this.controller,
      required this.backgroundWidget,
      this.child,
      this.pixelRatio = 1.0,
      this.realTimeCapture = true,
      this.useSync = true,
      this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
      this.useImpellerBackdrop,
      this.regionCapture = false})
      : children = const [],
        honorBackdropAlpha = false;

  /// **Internal.** The classic, position-driven path: renders a list of
  /// [LiquidGlass] lenses ([children]) over [backgroundWidget]. Retained
  /// for the package's own components (slider, toggle, nav bars, demos);
  /// app developers use [LiquidGlassLens] placed in [child] instead.
  @internal
  const LiquidGlassView.withPositionedLenses(
      {super.key,
      this.controller,
      required this.backgroundWidget,
      this.children = const [],
      this.child,
      this.pixelRatio = 1.0,
      this.realTimeCapture = true,
      this.useSync = true,
      this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
      this.useImpellerBackdrop,
      this.regionCapture = false,
      this.honorBackdropAlpha = false});

  @override
  State<LiquidGlassView> createState() => _LiquidGlassViewState();
}

class _LiquidGlassViewState extends State<LiquidGlassView>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _image;

  /// Parent-space rectangle [_image] covers, or `null` when [_image] is a
  /// full-frame capture. Set together with [_image] on every capture so the
  /// two never drift (a region image with a stale/null region would
  /// mis-sample). Drives the shader's `u_imageOffset`/`u_imageSize`.
  Rect? _imageRegion;

  Map<String, dynamic> _shaders = {};

  /// Bumped after every successful background capture. Descendant
  /// `LiquidGlassLens` widgets (the lens-anywhere API) listen to this
  /// through [LiquidGlassLensScope] and repaint, reading the new
  /// [_image] at paint time. Deliberately NOT bumped by the paint-time
  /// fallback capture — notifying listeners mid-paint is illegal; the
  /// lenses read that fallback directly through the scope instead.
  final ValueNotifier<int> _captureRevision = ValueNotifier<int>(0);

  /// Drives the per-frame capture pipeline on the **Skia / Web** path
  /// only. On the Impeller path each lens samples the live backdrop
  /// directly via `ImageFilter.shader`, so no parent-side ticker is
  /// needed and this is left null. Avoiding a perpetual
  /// vsync-driven `AnimatedBuilder` rebuild is one of the biggest
  /// wins on mobile Impeller — when no lens is animating and the
  /// user is not dragging, the parent does zero per-frame work.
  ///
  /// It runs only while something needs a frame ([_needsFramePump]): it
  /// is the vsync pump itself, not merely a gate on the capture.
  AnimationController? _controller;
  bool _realtimeCaptureEnabled = false;
  bool isWeb = kIsWeb;

  /// True when the BackdropFilter+ImageFilter.shader path should be
  /// used instead of the classic capture+CustomPaint pipeline.
  ///
  /// Both `true` and `null` mean "prefer Impeller, fall back to Skia":
  /// the shader path is only taken when the engine actually supports it
  /// (`ui.ImageFilter.isShaderFilterSupported`). Only an explicit
  /// `false` forces the Skia capture path. Forcing the shader path on a
  /// backend that does not support it asserts, so we never do — `true`
  /// is a preference, not an override.
  late final bool _useImpeller =
      (widget.useImpellerBackdrop ?? true) &&
          ui.ImageFilter.isShaderFilterSupported;

  /// Whether per-lens shader instances are required. Both Impeller
  /// (BackdropFilter compositing is deferred, so uniforms can't be
  /// shared) and the web HTML/Canvaskit pipeline need this.
  bool get _usePerLensShaders => _useImpeller || isWeb;

  /// True when [_image] belongs to an earlier frame, so the next lens to
  /// paint must re-capture before sampling it. Only the synchronous
  /// Skia path sets this — see [_capturesAtPaintTime].
  bool _imageStale = false;

  /// Whether this view refreshes its capture **inside** the frame that
  /// uses it, rather than after that frame has painted.
  ///
  /// The pump runs in the transient-callback phase, before the frame is
  /// built or painted, so anything it rasterizes there is last frame's
  /// picture; capturing after `endOfFrame` instead only moves the
  /// staleness to the consumer, which then paints a frame behind. On the
  /// sync path there is a third option: mark the cache stale in the
  /// pump and let the first lens to paint rasterize the background —
  /// which, being an earlier sibling in the Stack, has already painted
  /// THIS frame. Same one `toImageSync` per frame, no lag.
  ///
  /// The async path (`useSync: false`) keeps the after-the-frame
  /// `toImage()` it exists for, and so does [LiquidGlassView.regionCapture]
  /// — a paint-time capture is full-frame, and would leave the per-lens
  /// sub-images (which carry their own rects) frozen at whatever the
  /// pump last produced.
  bool get _capturesAtPaintTime =>
      !_useImpeller && widget.useSync && !widget.regionCapture;

  @override
  void initState() {
    super.initState();
    _realtimeCaptureEnabled = widget.realTimeCapture;

    // Impeller path skips the capture pipeline entirely — each lens
    // samples the backdrop live via `ImageFilter.shader`. We
    // therefore avoid creating the perpetual ticker on Impeller so
    // that an idle screen does no per-vsync Dart work at all.
    if (!_useImpeller) {
      DateTime lastCaptureTime = DateTime.now();

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(days: 2),
      )..addListener(() async {
          if (!_realtimeCaptureEnabled) return;
          final interval = _refreshInterval;
          // deviceRefreshRate → every frame; otherwise throttle to the
          // selected rate.
          if (interval != null) {
            final now = DateTime.now();
            if (now.difference(lastCaptureTime) < interval) return;
            lastCaptureTime = now;
          }
          if (_capturesAtPaintTime) {
            _markCaptureStale();
            return;
          }
          await _captureWidgetSafe();
        });
    }
    widget.controller?.attach(
      captureOnce: _captureOnce,
      startRealtime: _startRealtimeCapture,
      stopRealtime: _stopRealtimeCapture,
    );

    // If the programs were already compiled by a previous view (any
    // page after the first), build the shaders synchronously so
    // `shadersReady` is true on the very first frame. Otherwise fall
    // back to the async load (first launch only).
    if (LiquidGlassShaders.isLoadedFor(_useImpeller)) {
      _buildShaders();
    } else {
      _loadShaders().then((_) {
        if (mounted) setState(() {});
      });
    }

    // Skia / Web only: kick off the first capture as soon as the first
    // frame has painted. This is independent of shader loading — the
    // two run in parallel instead of the capture waiting behind the
    // shader future. Impeller samples the backdrop live per lens and
    // never needs a capture.
    if (!_useImpeller) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // The frame just painted, so the boundary layer is ready —
        // skip the extra endOfFrame wait that would cost a full frame.
        await _captureWidgetSafe(waitForEndOfFrame: false);
        if (mounted) setState(() {});
      });
      // Only pump when something needs it: a running controller
      // schedules a frame every vsync, gate or no gate.
      _syncFramePump();
    }
  }

  Duration? get _refreshInterval {
    switch (widget.refreshRate) {
      case LiquidGlassRefreshRate.low:
        return const Duration(milliseconds: 100); // ~10 FPS
      case LiquidGlassRefreshRate.medium:
        return const Duration(milliseconds: 42); // ~24 FPS
      case LiquidGlassRefreshRate.high:
        return const Duration(milliseconds: 16); // ~60 FPS
      case LiquidGlassRefreshRate.deviceRefreshRate:
        return null; // no throttling → capture every frame
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If config changes and no animation is running → update instantly

    if (_usePerLensShaders &&
        widget.children.length != oldWidget.children.length) {
      _recreateShaders(widget.children.length);
    }
    if (widget.realTimeCapture != oldWidget.realTimeCapture) {
      _applyRealtimeCapture(widget.realTimeCapture);
    } else if (widget.children.isEmpty != oldWidget.children.isEmpty) {
      // Gaining a positioned lens claims the pump; losing the last one
      // releases it.
      _syncFramePump();
    }
  }

  Size get captureSize {
    final renderBox =
        _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }

  List<ui.FragmentShader> _createShaderList(
    ui.FragmentShader Function() create,
    int count,
  ) {
    return List.generate(count, (_) => create());
  }

  Future<void> _loadShaders() async {
    try {
      await LiquidGlassShaders.ensureLoaded(_useImpeller);
    } catch (_) {
      // Shaders unavailable (broken build / unsupported test env):
      // `_shaders` stays empty, so lenses simply don't render instead
      // of crashing the surrounding app.
      return;
    }
    _buildShaders();
  }

  /// Builds the per-view shader instances from the already-compiled
  /// shared programs (see [LiquidGlassShaders]). Synchronous so it can
  /// run inside [initState] when the programs are cached.
  void _buildShaders() {
    if (_usePerLensShaders) {
      // Impeller and web need one dedicated FragmentShader per lens.
      // BackdropFilter compositing (Impeller) and the web pipeline are
      // deferred, so successive draw calls would otherwise reuse the
      // same shader object with the last uniforms set, producing
      // context-switch artifacts (old lens content leaking, new lens
      // appearing transparent).
      final count = widget.children.length;
      _shaders = {
        'liquid_glass_list': _createShaderList(
            () => LiquidGlassShaders.createMainShader(_useImpeller), count),
        'liquid_glass_border_list': _createShaderList(
            () => LiquidGlassShaders.createBorderShader(_useImpeller), count),
      };
    } else {
      // Skia native draws each CustomPaint immediately, so a single
      // shared shader instance is safe and cheaper.
      _shaders = {
        'liquid_glass': LiquidGlassShaders.createMainShader(_useImpeller),
        'liquid_glass_border':
            LiquidGlassShaders.createBorderShader(_useImpeller),
      };
    }
  }

  Future<void> _recreateShaders(int newCount) async {
    if (!_usePerLensShaders) return;
    if (!LiquidGlassShaders.isLoadedFor(_useImpeller)) return;

    setState(() {
      _shaders['liquid_glass_list'] = _createShaderList(
          () => LiquidGlassShaders.createMainShader(_useImpeller), newCount);
      _shaders['liquid_glass_border_list'] = _createShaderList(
          () => LiquidGlassShaders.createBorderShader(_useImpeller), newCount);
    });
  }

  /// Safely captures the background RepaintBoundary.
  ///
  /// Important behavior (please keep — do not remove without testing on
  /// release/profile builds on Android):
  /// - On release/profile builds with Impeller (Android), a
  ///   `RenderRepaintBoundary` can still have no composited `layer` even
  ///   after `endOfFrame` (especially for small or freshly mounted
  ///   boundaries, or ones containing `Image.file`). In that case
  ///   `toImageSync` throws "Null check operator used on a null value".
  /// - So we first check `boundary.layer != null`; if the layer is not
  ///   ready we go straight to the async `toImage()`, which can wait for
  ///   composition to complete.
  /// - If `toImageSync` still throws, we catch it and also fall back to
  ///   async `toImage()`.
  /// - If async `toImage()` also fails, we soft-fail — we do not crash
  ///   the app; the frame is simply skipped and the UI keeps using the
  ///   previous `_image`.
  Future<void> _captureWidgetSafe({bool waitForEndOfFrame = true}) async {
    try {
      final context = _repaintKey.currentContext;
      if (context == null) return;

      final boundary = context.findRenderObject();
      if (boundary is RenderRepaintBoundary && boundary.attached) {
        // Callers running inside a post-frame callback pass false: the
        // frame has already painted, and awaiting endOfFrame there
        // would schedule + wait out one extra frame. The layer-null
        // check below still routes to async toImage() if composition
        // isn't ready, so skipping the wait stays safe.
        if (waitForEndOfFrame) {
          await WidgetsBinding.instance.endOfFrame;
        }
        if (!context.mounted) return;

        double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        double pixelRatio =
            widget.pixelRatio <= 0 ? devicePixelRatio : widget.pixelRatio;
        if (pixelRatio > devicePixelRatio) {
          pixelRatio = devicePixelRatio;
        }

        // ignore: invalid_use_of_protected_member
        final bool layerReady = boundary.layer != null;
        final bool preferSync = widget.useSync && layerReady;

        ui.Image? newImage;
        // Per-lens captures (regionCapture): one small image + its
        // parent-space rect for EACH lens child, index-aligned with
        // widget.children. Null → this capture was full-frame.
        List<ui.Image?>? newImagesPerLens;
        List<Rect?>? newRegionsPerLens;

        if (preferSync) {
          try {
            // Region-capture (Skia): capture each lens's own rect
            // (+ margin) as a separate sub-image and bind it directly —
            // the shader remaps it via u_imageOffset/u_imageSize, so no
            // full-size recomposite is needed. Opt-in per view via
            // LiquidGlassView.regionCapture; when false the original
            // full-frame path runs.
            // Region capture only updates the per-legacy-lens images,
            // not the shared full-frame [_image] that lens-anywhere
            // lenses sample — so force full-frame whenever a `child`
            // subtree (which may contain such lenses) is present.
            if (widget.regionCapture && widget.child == null) {
              // ignore: invalid_use_of_protected_member
              final layer = boundary.layer as OffsetLayer?;
              if (layer != null && widget.children.isNotEmpty) {
                final images = <ui.Image?>[];
                final regions = <Rect?>[];
                bool any = false;
                for (final child in widget.children) {
                  final Offset tl = child.geometry.position.resolve(
                      boundary.size,
                      Size(child.geometry.width, child.geometry.height));
                  final Rect r = (tl &
                          Size(child.geometry.width, child.geometry.height))
                      .inflate(_kRegionCaptureMargin)
                      .intersect(Offset.zero & boundary.size);
                  if (r.isEmpty) {
                    images.add(null);
                    regions.add(null);
                    continue;
                  }
                  images.add(layer.toImageSync(r, pixelRatio: pixelRatio));
                  regions.add(r);
                  any = true;
                }
                if (any) {
                  newImagesPerLens = images;
                  newRegionsPerLens = regions;
                }
              }
            }
            if (newImagesPerLens == null) {
              newImage = boundary.toImageSync(pixelRatio: pixelRatio);
            }
          } catch (_) {
            newImagesPerLens = null;
            newRegionsPerLens = null;
            try {
              newImage = await boundary.toImage(pixelRatio: pixelRatio);
            } catch (_) {
              newImage = null;
            }
          }
        } else {
          try {
            newImage = await boundary.toImage(pixelRatio: pixelRatio);
          } catch (_) {
            newImage = null;
          }
        }

        if (newImage == null && newImagesPerLens == null) return;
        if (!context.mounted) return;

        if (newImagesPerLens != null) {
          _imagesPerLens = newImagesPerLens;
          _regionsPerLens = newRegionsPerLens;
        } else {
          _image = newImage;
          _imageRegion = null;
          _imageStale = false;
          _imagesPerLens = null;
          _regionsPerLens = null;
          // Wake the lens-anywhere lenses (scope listeners). Safe here:
          // captures run from the ticker / post-frame callbacks, never
          // inside paint.
          _captureRevision.value++;
        }
      }
    } catch (_) {
      // Soft-fail: skip this frame, the UI keeps working.
    }
  }

  // ===== Per-lens region capture (Skia) =====
  // Opt-in via LiquidGlassView.regionCapture. Each lens gets its own
  // captured rect, inflated by this safety margin. The shader itself
  // never samples outside the lens rect (refraction pulls inward) —
  // the buffer covers a fast-moving lens drifting a few px past the
  // region between capture and paint, and magnification < 1 (which
  // scales samples outward).
  static const double _kRegionCaptureMargin = 24.0;

  /// Per-lens captured images and their parent-space rects, index-
  /// aligned with `widget.children`. Non-null only while
  /// `widget.regionCapture` is enabled and the last capture succeeded;
  /// entries can be null for off-screen lenses (those fall back to
  /// [_image]).
  List<ui.Image?>? _imagesPerLens;
  List<Rect?>? _regionsPerLens;

  /// Device pixel ratio, refreshed on every build for use inside
  /// paint-time code (where InheritedWidget lookups are not allowed).
  double _devicePixelRatio = 1.0;

  /// Synchronous paint-time capture for the Skia / Web path.
  ///
  /// Called by the lens painters during their `paint()` when the capture
  /// they would sample is missing or stale — the very first frame after
  /// this view is created (page change, first mount), and every live
  /// frame on the sync path ([_capturesAtPaintTime]). The background
  /// RepaintBoundary is an earlier sibling in the Stack, so by the time
  /// a lens paints, the boundary's layer has already been painted **this
  /// frame** and `toImageSync` can rasterize it immediately.
  ///
  /// That timing is the whole point. A capture taken before the frame
  /// (the pump) or after it (`endOfFrame`) is a frame behind whatever
  /// samples it, which on a moving lens shows up as the backdrop
  /// trailing the glass — and on a lens whose pipeline was asleep, as
  /// the snapshot from when it went to sleep. Here the picture and the
  /// lens sampling it are the same frame. The first lens to paint pays
  /// for the rasterization and caches it into [_image]; the rest of the
  /// frame's lenses reuse it.
  ///
  /// Always captures the full frame — never a region — because the
  /// painters calling this were built with null `imageOffset`/`imageSize`
  /// (full-frame sampling). Region capture resumes with the normal
  /// per-frame pipeline. The result is cached into [_image] so the other
  /// lenses painting in the same frame reuse it instead of re-capturing.
  ///
  /// Soft-fails to the previous capture — a frame-old backdrop beats a
  /// lens that skips its glass for a frame — or to null when there has
  /// never been one, matching the existing capture pipeline's behavior.
  ui.Image? _capturePaintTimeSync() {
    if (_image != null && !_imageStale) return _image;
    try {
      final context = _repaintKey.currentContext;
      if (context == null) return _image;
      final boundary = context.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) {
        return _image;
      }
      // ignore: invalid_use_of_protected_member
      final layer = boundary.layer;
      if (layer is! OffsetLayer) return _image;

      double pixelRatio =
          widget.pixelRatio <= 0 ? _devicePixelRatio : widget.pixelRatio;
      if (pixelRatio > _devicePixelRatio) {
        pixelRatio = _devicePixelRatio;
      }

      final img = layer.toImageSync(
        Offset.zero & boundary.size,
        pixelRatio: pixelRatio,
      );
      _image = img;
      _imageRegion = null;
      _imageStale = false;
      return img;
    } catch (_) {
      return _image;
    }
  }

  Future<void> _captureOnce() async {
    await _captureWidgetSafe();
    if (mounted) setState(() {});
  }

  /// Flips the capture pipeline on or off, controller included.
  ///
  /// The flag alone is not enough: the controller is the per-vsync pump,
  /// so a running one keeps scheduling frames even while the listener
  /// returns early. Stopping it is what makes an idle view free.
  void _applyRealtimeCapture(bool enabled) {
    if (_realtimeCaptureEnabled == enabled) return;
    _realtimeCaptureEnabled = enabled;
    // Waking: whatever is cached dates from when the pipeline went to
    // sleep, and the pump's first refresh is a frame away — so the lens
    // would refract that snapshot on the one frame it is most
    // conspicuous, the frame the glass appears on. Retire it here and
    // the very next paint rasterizes the live background instead.
    if (enabled && _capturesAtPaintTime) _markCaptureStale();
    _syncFramePump();
  }

  /// Retires the cached capture for this frame and wakes every lens
  /// sampling it, so one of them re-rasterizes the background during
  /// paint. Cheap: nothing is captured until a lens actually asks.
  void _markCaptureStale() {
    _imageStale = true;
    // Lens-anywhere lenses read the capture at paint time; without this
    // a frame where nothing else touched them would reuse the retired
    // picture instead of taking a new one.
    _captureRevision.value++;
  }

  /// Whether anything still needs a frame every vsync.
  ///
  /// Captures do, obviously. So do positioned [children] lenses: on the
  /// Skia path they read their show/hide value at *build* time, and this
  /// controller's `AnimatedBuilder` is the only thing that rebuilds them,
  /// so a stopped pump would freeze a fade halfway.
  bool get _needsFramePump =>
      _realtimeCaptureEnabled || widget.children.isNotEmpty;

  void _syncFramePump() {
    final controller = _controller;
    if (controller == null) return;
    if (_needsFramePump) {
      if (!controller.isAnimating) controller.forward();
    } else {
      controller.stop();
    }
  }

  void _startRealtimeCapture() {
    if (_realtimeCaptureEnabled) return;
    setState(() {
      _applyRealtimeCapture(true);
    });
  }

  void _stopRealtimeCapture() {
    if (!_realtimeCaptureEnabled) return;
    setState(() {
      _applyRealtimeCapture(false);
    });
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _controller?.dispose();
    _captureRevision.dispose();
    super.dispose();
  }

  // ===== Lens-anywhere scope accessors =====
  // Instance-method tear-offs stay `==` across rebuilds, so the scope
  // only notifies dependents on real configuration changes.

  /// Latest full-frame capture for descendant `LiquidGlassLens` widgets.
  ///
  /// Null while the cache is retired, which is what sends the lens on to
  /// its `captureFallback` ([_capturePaintTimeSync]) for a picture of
  /// the frame it is painting into.
  ui.Image? _currentImageForLens() => _imageStale ? null : _image;

  /// The background boundary box — the coordinate space captures live in.
  RenderBox? _backgroundBoxForLens() =>
      _repaintKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    _devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Stack(
      // Tight constraints for both the captured background and the
      // lens-rendering layer. Without this, in a loose Stack, the
      // RepaintBoundary and the LayoutBuilder can end up at
      // different sizes (or with stale captureSize), which makes
      // alignment-based lens positions resolve against the wrong
      // parent size on first build and on page changes.
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: widget.backgroundWidget,
        ),
        // Lens-anywhere subtree: any widget tree with `LiquidGlassLens`
        // widgets inside it, connected to this view through the scope.
        // Painted above the background and below the classic lenses.
        if (widget.child != null)
          LiquidGlassLensScope(
            useImpellerBackdrop: _useImpeller,
            captureRevision: _captureRevision,
            currentImage: _currentImageForLens,
            captureFallback: _capturePaintTimeSync,
            backgroundRenderBox: _backgroundBoxForLens,
            child: widget.child!,
          ),
        // The lens layout itself is identical on both paths. The
        // difference is what triggers it to rebuild:
        //  - Skia / Web: rebuilds whenever the captured background
        //    image is refreshed (driven by `_controller`).
        //  - Impeller:  rebuilds only on layout changes; each
        //    `LiquidGlassWidget` watches its own animation
        //    controller + touch notifier, so the parent does no
        //    per-frame work when nothing is animating or being
        //    dragged.
        if (_useImpeller)
          _buildLensLayout()
        else
          AnimatedBuilder(
            animation: _controller!,
            builder: (context, _) => _buildLensLayout(),
          ),
      ],
    );
  }

  Widget _buildLensLayout() {
    // Both paths gate solely on shader availability. Impeller samples
    // the live backdrop via BackdropFilter; Skia no longer waits for
    // the first capture either — when `_image` is still null the
    // painters capture the freshly painted background synchronously
    // during paint via [_capturePaintTimeSync], so lenses render on
    // the very first frame of a new view.
    final bool shadersReady = _usePerLensShaders
        ? _shaders.containsKey('liquid_glass_list')
        : _shaders.containsKey('liquid_glass');
    final bool canRender = shadersReady;

    return LayoutBuilder(builder: (context, constraints) {
      // Use the layout constraints as the authoritative parent
      // size. On the Skia path `captureSize` (read from the
      // RepaintBoundary's render box) is only valid after first
      // layout; on the Impeller path the lenses render before any
      // capture happens, so `Size.zero` would push every alignment
      // to (0, 0).
      final Size resolvedParentSize =
          constraints.biggest.isFinite ? constraints.biggest : captureSize;

      final shaderList =
          _shaders['liquid_glass_list'] as List<ui.FragmentShader>?;
      final borderList =
          _shaders['liquid_glass_border_list'] as List<ui.FragmentShader>?;

      return Stack(children: [
        ...widget.children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          final bool indexReady = !_usePerLensShaders ||
              (shaderList != null &&
                  borderList != null &&
                  index < shaderList.length &&
                  index < borderList.length);

          if (canRender && indexReady) {
            // Per-lens region capture: when this lens has its own
            // captured sub-image, bind that (+ its rect); otherwise
            // fall back to the shared full-frame capture.
            final perImgs = _imagesPerLens;
            final bool hasOwn = perImgs != null &&
                index < perImgs.length &&
                perImgs[index] != null;
            // Use `config.key` when provided, otherwise a stable
            // index-based key. This prevents Flutter from reusing
            // a lens `State` across the wrong slot when `children`
            // change (insert/remove/reorder).
            final Widget lens = LiquidGlassWidget(
              config: child,
              parentSize: resolvedParentSize,
              sharedShader: _usePerLensShaders
                  ? shaderList![index]
                  : _shaders['liquid_glass'] as ui.FragmentShader?,
              border: _usePerLensShaders
                  ? borderList![index]
                  : _shaders['liquid_glass_border'] as ui.FragmentShader?,
              // A retired cache is handed over as null so the painter
              // falls through to the paint-time capture. Region images
              // are untouched: they carry their own rect, which the
              // full-frame fallback would not match.
              sharedImage: hasOwn
                  ? perImgs[index]
                  : (_imageStale ? null : _image),
              sharedImageRegion:
                  hasOwn ? _regionsPerLens![index] : _imageRegion,
              captureFallback: _useImpeller ? null : _capturePaintTimeSync,
              useImpellerBackdrop: _useImpeller,
              honorBackdropAlpha: widget.honorBackdropAlpha,
            );
            // Always wrap in Opacity so the whole lens (refraction + rim +
            // tint) can fade together. The key lives on the wrapper so the
            // element type at this Stack slot stays stable as opacity
            // crosses 1.0 (otherwise the lens would remount mid-fade) and
            // so a lens keeps its State across children insert/remove.
            // Opacity short-circuits at 1.0/0.0, so the opaque case is free.
            return Opacity(
              key: child.key ?? ValueKey('lg_index_$index'),
              opacity: child.opacity.clamp(0.0, 1.0),
              child: lens,
            );
          } else {
            return const SizedBox.shrink();
          }
        }),
      ]);
    });
  }
}
