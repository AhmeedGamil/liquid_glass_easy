import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'liquid_glass_config.dart';
import 'render/impeller_liquid_glass_lens.dart';
import 'render/skia_liquid_glass_lens.dart';
import 'utils/liquid_glass_flex.dart';

export '../controllers/liquid_glass_controller.dart' show LiquidGlassController;
export 'liquid_glass_config.dart'
    show
        LiquidGlass,
        LiquidGlassGeometry,
        LiquidGlassRefraction,
        LiquidGlassAppearance,
        LiquidGlassBehavior;

/// Lens widget that uses the shared shader + image.
///
/// This widget is a thin **coordinator**: it owns the per-lens shared
/// state (the show/hide [AnimationController] and the drag position
/// notifier) and the position/clamping bookkeeping, then delegates the
/// actual rendering to one of two paths:
///
///  • [ImpellerLiquidGlassLens] — `BackdropFilter` + `ImageFilter.shader`,
///    sampling the **live backdrop** directly. Selected when
///    [useImpellerBackdrop] is true.
///  • [SkiaLiquidGlassLens] — `CustomPaint` sampling a **captured**
///    snapshot of the background. The fallback for Skia / Web.
class LiquidGlassWidget extends StatefulWidget {
  final Size parentSize;
  final LiquidGlass config;
  final ui.FragmentShader? sharedShader;
  final ui.FragmentShader? border;

  /// Snapshot of the captured background. Only required on the
  /// Skia / web path. On the Impeller path the shader reads the
  /// live backdrop directly via `ImageFilter.shader` and this is
  /// allowed to be null.
  final ui.Image? sharedImage;

  /// Parent-space rectangle the [sharedImage] covers (Skia path). `null`
  /// means the image is a full-frame capture. Forwarded to
  /// [SkiaLiquidGlassLens] so the shader samples a region capture correctly.
  final Rect? sharedImageRegion;

  /// Paint-time synchronous capture fallback (Skia path). Invoked by the
  /// painters when [sharedImage] is still null — the first frame after
  /// the parent view is created — so the lens can refract the freshly
  /// painted background within that same frame.
  final ui.Image? Function()? captureFallback;

  /// When true, the lens is rendered with `BackdropFilter` +
  /// `ImageFilter.shader` instead of a `CustomPaint` that samples a
  /// captured image. Set by the parent view based on
  /// `ImageFilter.isShaderFilterSupported`.
  final bool useImpellerBackdrop;

  /// Whether the captured backdrop's alpha is folded into coverage on the
  /// Skia path (the shader's `u_honorBackdropAlpha`). Forwarded to
  /// [SkiaLiquidGlassLens]; ignored on the Impeller path (which always
  /// treats the live backdrop as opaque). Set `true` only for the
  /// slider/toggle, whose captured track is authored-transparent.
  final bool honorBackdropAlpha;

  const LiquidGlassWidget(
      {super.key,
      required this.parentSize,
      required this.config,
      this.sharedShader,
      this.sharedImage,
      this.sharedImageRegion,
      this.captureFallback,
      this.border,
      this.useImpellerBackdrop = false,
      this.honorBackdropAlpha = false});

  @override
  State<LiquidGlassWidget> createState() => _LiquidGlassWidgetState();
}

class _LiquidGlassWidgetState extends State<LiquidGlassWidget>
    with TickerProviderStateMixin {
  late final ValueNotifier<Offset> _touchNotifier;
  late AnimationController _animController;

  /// Spring driver behind [LiquidGlassBehavior.touch]. Created on first
  /// use, so a lens without a `touch` never allocates a ticker.
  ///
  /// Deliberately kept OUT of the position bookkeeping below: `_touchNotifier`
  /// and every clamp in [didUpdateWidget] resolve against the **rest** config
  /// only. The deformation is applied once, at the very end of [build], on
  /// the way to the render path — never stored, never fed back.
  LiquidGlassFlexDriver? _ownedFlexDriver;
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.config.behavior.visibility ? 0 : 1, // initial value
    );
    // only attach trigger if controller exists
    // Attach controller if provided
    widget.config.behavior.controller?.attach(
        showLiquidGlass: _showLiquidGlass,
        hideLiquidGlass: _hideLiquidGlass,
        resetLiquidGlassPosition:
            _resetLiquidGlassPosition); // Resolve initial position
    final initialPosition = widget.config.geometry.position.resolve(
      widget.parentSize,
      Size(widget.config.geometry.width, widget.config.geometry.height),
    );
    _touchNotifier = ValueNotifier<Offset>(initialPosition);
  }

  void setPosition() {
    final initialPosition = widget.config.geometry.position.resolve(
      widget.parentSize,
      Size(widget.config.geometry.width, widget.config.geometry.height),
    );
    _touchNotifier.value = initialPosition;
  }

  void _hideLiquidGlass(
      {int? animationTimeMillisecond, VoidCallback? onComplete}) {
    final duration = Duration(milliseconds: animationTimeMillisecond ?? 600);

    if (duration.inMilliseconds == 0) {
      // Jump instantly
      _animController.value = 1.0;
      if (onComplete != null) onComplete();
    } else {
      _animController.value = 0.0;
      _animController
          .animateTo(
        1,
        duration: duration,
        curve: Curves.easeInOut,
      )
          .whenComplete(() {
        if (onComplete != null) onComplete();
      });
    }
  }

  void _showLiquidGlass(
      {int? animationTimeMillisecond, VoidCallback? onComplete}) {
    final duration = Duration(milliseconds: animationTimeMillisecond ?? 600);

    if (duration.inMilliseconds == 0) {
      // Jump instantly
      _animController.value = 0.0;
      if (onComplete != null) onComplete();
    } else {
      _animController.value = 1.0;
      _animController
          .animateTo(
        0,
        duration: duration,
        curve: Curves.easeInOut,
      )
          .whenComplete(() {
        if (onComplete != null) onComplete();
      });
    }
  }

  void _resetLiquidGlassPosition() {
    setPosition();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If config changes and no animation is running → update instantly
    if (!_animController.isAnimating &&
        widget.config.behavior.visibility != oldWidget.config.behavior.visibility) {
      if (widget.config.behavior.visibility) {
        if (_animController.isAnimating) _animController.stop();
        _animController.value = 0;
      } else {
        if (_animController.isAnimating) _animController.stop();
        _animController.value = 1;
      }
    }

    // --- Handle parent size / layout changes
    final parentSize = widget.parentSize;
    final oldParentSize = oldWidget.parentSize;
    final config = widget.config;
    if (parentSize.width != oldParentSize.width ||
        parentSize.height != oldParentSize.height ||
        config.geometry.width != oldWidget.config.geometry.width ||
        config.geometry.height != oldWidget.config.geometry.height ||
        config.geometry.position != oldWidget.config.geometry.position) {
      // Compute old and new resolved centers
      final oldResolvedPosition = oldWidget.config.geometry.position.resolve(
        oldParentSize,
        Size(oldWidget.config.geometry.width, oldWidget.config.geometry.height),
      );
      final resolvedPosition = config.geometry.position.resolve(
        parentSize,
        Size(config.geometry.width, config.geometry.height),
      );

      // Calculate proportional scaling factors
      // final scaleX = parentSize.width / oldParentSize.width;
      // final scaleY = parentSize.height / oldParentSize.height;

      // Maintain the same relative touch offset ratio inside the parent.
      //
      // Guard against a degenerate old parent size. On the Impeller path
      // a lens is created before layout settles, so its first
      // `oldParentSize` is `Size(0, 0)`. Dividing by that yields NaN,
      // and the clamp below turns NaN into the max bound — slamming the
      // lens to the bottom-right corner. When the old size has no area we
      // can't preserve a relative ratio anyway, so just snap to the
      // freshly resolved position.
      final bool canScale = oldParentSize.width > 0 && oldParentSize.height > 0;
      final Offset oldTouch = _touchNotifier.value;

      Offset newTouch;
      if (canScale) {
        final Offset relative = Offset(
          (oldTouch.dx - oldResolvedPosition.dx) / oldParentSize.width,
          (oldTouch.dy - oldResolvedPosition.dy) / oldParentSize.height,
        );
        // Apply scaling and update position proportionally.
        newTouch = Offset(
          resolvedPosition.dx + relative.dx * parentSize.width,
          resolvedPosition.dy + relative.dy * parentSize.height,
        );
      } else {
        newTouch = resolvedPosition;
      }

      // Clamp lens inside parent bounds — but only when the lens is NOT
      // allowed out of bounds. With outOfBoundaries == true, the lens must
      // be free to extend beyond the parent (e.g. a list row scrolling off
      // the top/bottom); clamping here would pin it to the edge and break
      // the spacing between lenses.
      if (!widget.config.geometry.outOfBoundaries) {
        final double maxX =
            parentSize.width - config.geometry.width.clamp(0.0, parentSize.width);
        final double maxY =
            parentSize.height - config.geometry.height.clamp(0.0, parentSize.height);

        newTouch = Offset(
          newTouch.dx.clamp(0.0, maxX),
          newTouch.dy.clamp(0.0, maxY),
        );
      }

      _touchNotifier.value = newTouch;
    }
    // config.geometry.width.clamp(0.0, parentSize.width);
    // config.geometry.height.clamp(0.0, parentSize.height);
    if (!widget.config.geometry.outOfBoundaries) {
      // --- clamp comes here, completely outside the condition ---
      final double maxX =
          parentSize.width - config.geometry.width.clamp(0.0, parentSize.width);
      final double maxY =
          parentSize.height - config.geometry.height.clamp(0.0, parentSize.height);

      _touchNotifier.value = Offset(
        _touchNotifier.value.dx.clamp(0.0, maxX),
        _touchNotifier.value.dy.clamp(0.0, maxY),
      );
    }
  }

  @override
  void dispose() {
    widget.config.behavior.controller?.detach();
    // Only the driver this state created — an externally supplied one
    // belongs to whoever handed it in.
    _ownedFlexDriver?.dispose();
    _touchNotifier.dispose();
    _animController.dispose();
    super.dispose();
  }

  LiquidGlassFlexDriver _ensureFlexDriver(LiquidGlassFlex spec) =>
      (_ownedFlexDriver ??=
          LiquidGlassFlexDriver(vsync: this, spec: spec))
        ..spec = spec
        ..restSize = Size(
          widget.config.geometry.width,
          widget.config.geometry.height,
        );

  @override
  Widget build(BuildContext context) {
    if (_animController.value >= 1) return const SizedBox.shrink();

    final LiquidGlassFlex? flex = widget.config.behavior.touch?.flex;
    if (flex == null) {
      return _buildPath(widget.config, LiquidGlassFlexDeform.none, null);
    }

    // Deform last: the rest config drives every layout decision above, and
    // only the copy handed to the render path carries the deformation.
    final driver = _ensureFlexDriver(flex);
    return ValueListenableBuilder<LiquidGlassFlexDeform>(
      valueListenable: driver,
      builder: (context, deform, _) => _buildPath(
        liquidGlassFlexConfig(widget.config, flex, deform),
        deform,
        driver,
      ),
    );
  }

  /// Picks the render path. Each path widget owns its own rendering and
  /// rebuild scope; this coordinator only owns the shared state
  /// (animation + drag position + press springs) and passes it down by
  /// reference.
  ///
  /// [config] is already deformed when a press is active; [deform] carries
  /// the matching origin shift and content scale, which the render paths
  /// apply to the lens position and the child respectively.
  Widget _buildPath(
    LiquidGlass config,
    LiquidGlassFlexDeform deform,
    LiquidGlassFlexDriver? flexDriver,
  ) {
    final Size flexRestSize = Size(
      widget.config.geometry.width,
      widget.config.geometry.height,
    );

    if (widget.useImpellerBackdrop) {
      return ImpellerLiquidGlassLens(
        config: config,
        parentSize: widget.parentSize,
        shader: widget.sharedShader,
        touch: _touchNotifier,
        animation: _animController,
        flexDeform: deform,
        flexDriver: flexDriver,
        flexRestSize: flexRestSize,
      );
    }

    return SkiaLiquidGlassLens(
      config: config,
      parentSize: widget.parentSize,
      shader: widget.sharedShader,
      image: widget.sharedImage,
      imageFallback: widget.captureFallback,
      borderShader: widget.border,
      touch: _touchNotifier,
      animValue: _animController.value,
      imageRegion: widget.sharedImageRegion,
      honorBackdropAlpha: widget.honorBackdropAlpha,
      flexDeform: deform,
      flexDriver: flexDriver,
      flexRestSize: flexRestSize,
    );
  }
}
