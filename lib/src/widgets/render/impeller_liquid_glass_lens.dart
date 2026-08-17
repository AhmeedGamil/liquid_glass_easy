import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../lens/liquid_glass_transform_tracking.dart';
import '../liquid_glass_config.dart';
import '../painters/liquid_glass_uniforms.dart';
import '../utils/liquid_glass_flex.dart';
import '../utils/liquid_glass_shape.dart';

/// Per-frame transform probe for the Impeller lens: the tracking layer
/// fires whenever an ANCESTOR moves this subtree without rebuilding it —
/// a route transition's ScaleTransition, a scroll — which no build-side
/// callback can see. The lens then re-syncs after that frame.
class _LensXformProbe extends SingleChildRenderObjectWidget {
  const _LensXformProbe({required this.onMoved, super.child});

  final VoidCallback onMoved;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLensXformProbe(onMoved);

  @override
  void updateRenderObject(
          BuildContext context, covariant _RenderLensXformProbe renderObject) =>
      renderObject.onMoved = onMoved;
}

class _RenderLensXformProbe extends RenderProxyBox
    with LensTransformTrackingMixin {
  _RenderLensXformProbe(this.onMoved);

  VoidCallback onMoved;

  @override
  void onGlobalTransformChanged() => onMoved();

  @override
  void paint(PaintingContext context, Offset offset) {
    pushTransformTracking(context, offset);
    super.paint(context, offset);
  }
}

/// Impeller render path for a single lens, extracted from
/// `LiquidGlassWidget`.
///
/// Uses `BackdropFilter` + `ImageFilter.shader` so the shader reads the
/// **live backdrop** directly — no `RepaintBoundary` capture. It owns
/// its own `AnimatedBuilder`/`ValueListenableBuilder` so that at rest
/// (no animation, no drag) the parent does zero per-frame work and
/// Impeller can keep the BackdropFilter layer resident across frames.
///
/// All shared state (the show/hide [animation] and the drag [touch]
/// notifier) is owned by the coordinator and passed in by reference.
///
/// ## Screen-space coordinates
/// Under `ImageFilter.shader`, `FlutterFragCoord()` is in **screen
/// (FlutterView) physical pixels** — its origin is the top of the
/// window, NOT the top of the `LiquidGlassView`. So the shader's lens
/// position (`u_touch`) and resolution (`u_resolution`) must be
/// expressed in that same screen space, otherwise the lens shape is
/// drawn offset from where its `ClipRRect` actually clips it and gets
/// cut off (e.g. when the view sits below an `AppBar`). This widget
/// reads its own global offset via `localToGlobal` and adds it to the
/// (parent-relative) lens position, and uses the view size as the
/// resolution. When the view is full-screen at the window origin the
/// offset is zero and the view size equals the parent size, so this is
/// a no-op for that (common) case.
class ImpellerLiquidGlassLens extends StatefulWidget {
  final LiquidGlass config;
  final Size parentSize;

  /// Shared main shader for this lens. May be null while the program is
  /// still loading.
  final ui.FragmentShader? shader;

  /// Drag position (lens top-left), owned by the coordinator. Mutated
  /// here on pan when [LiquidGlass.draggable] is set.
  final ValueNotifier<Offset> touch;

  /// Show/hide animation, owned by the coordinator.
  final Animation<double> animation;

  /// Current touch deformation. [config] already carries the deformed size;
  /// this supplies the matching origin shift and the child's pixel scale.
  /// [LiquidGlassFlexDeform.none] when no press is configured.
  final LiquidGlassFlexDeform flexDeform;

  /// Spring driver fed by this lens's pointer events. Null disables the
  /// press behaviour entirely — no `Listener` is added to the tree.
  final LiquidGlassFlexDriver? flexDriver;

  /// The lens's undeformed size, used to lay the child out at rest before
  /// scaling its pixels.
  final Size flexRestSize;

  const ImpellerLiquidGlassLens({
    super.key,
    required this.config,
    required this.parentSize,
    required this.shader,
    required this.touch,
    required this.animation,
    this.flexDeform = LiquidGlassFlexDeform.none,
    this.flexDriver,
    this.flexRestSize = Size.zero,
  });

  @override
  State<ImpellerLiquidGlassLens> createState() =>
      _ImpellerLiquidGlassLensState();
}

class _ImpellerLiquidGlassLensState extends State<ImpellerLiquidGlassLens> {
  /// The lens layer's top-left in GLOBAL (FlutterView) logical pixels.
  /// Re-read after every layout; only triggers a rebuild when it
  /// actually moves (AppBar present, scroll, rotation, etc.).
  Offset _layerGlobalOffset = Offset.zero;

  /// The linear part of the box's global transform, row-major. Identity
  /// for every lens that only sits somewhere (the common case); real
  /// values when an ancestor scales or rotates it — an animated dialog,
  /// a hero flight — which the shader then honors as a lens→shader map
  /// instead of drawing the untransformed rect and getting clipped.
  double _xformA = 1, _xformB = 0, _xformC = 0, _xformD = 1;

  /// Whether an ancestor carries scale/rotation. Translation-only lenses
  /// keep the exact legacy screen-space uniforms, bit-identical.
  bool get _hasLinearXform =>
      (_xformA - 1).abs() > 1e-4 ||
      _xformB.abs() > 1e-4 ||
      _xformC.abs() > 1e-4 ||
      (_xformD - 1).abs() > 1e-4;

  /// Re-reads the box's CURRENT global transform during build. Ancestor
  /// paint transforms (a running ScaleTransition) update parent-first in
  /// the same frame, so a build-time read is exact — the post-frame sync
  /// alone would hand the shader last frame's matrix the whole flight,
  /// and the border would still clip on the fast early frames.
  void _sampleTransformInBuild() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final s = box.getTransformTo(null).storage;
    _layerGlobalOffset = Offset(s[12], s[13]);
    _xformA = s[0];
    _xformB = s[4];
    _xformC = s[1];
    _xformD = s[5];
  }

  /// The previous post-frame sample, kept apart from what build consumed.
  /// Comparing successive FRAMES (not build vs. now — the build-time
  /// sample makes those equal by construction) is what keeps the rebuild
  /// chain alive for the whole flight of an animated ancestor transform.
  double _lastA = 1, _lastB = 0, _lastC = 0, _lastD = 1;
  Offset _lastOffset = Offset.zero;

  /// Re-reads this widget's global transform and rebuilds if it changed —
  /// against what the last build consumed OR against last frame's sample.
  void _syncLayerOffset() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    // Column-major storage: [0]=a, [4]=b, [1]=c, [5]=d, [12..13]=t.
    final s = box.getTransformTo(null).storage;
    final next = Offset(s[12], s[13]);
    bool differs(double a, double b, double c, double d, Offset o) =>
        (next - o).distanceSquared > 0.01 ||
        (s[0] - a).abs() > 1e-4 ||
        (s[4] - b).abs() > 1e-4 ||
        (s[1] - c).abs() > 1e-4 ||
        (s[5] - d).abs() > 1e-4;
    final bool staleBuild =
        differs(_xformA, _xformB, _xformC, _xformD, _layerGlobalOffset);
    final bool moving = differs(_lastA, _lastB, _lastC, _lastD, _lastOffset);
    _lastA = s[0];
    _lastB = s[4];
    _lastC = s[1];
    _lastD = s[5];
    _lastOffset = next;
    if (staleBuild || moving) {
      setState(() {
        _layerGlobalOffset = next;
        _xformA = s[0];
        _xformB = s[4];
        _xformC = s[1];
        _xformD = s[5];
      });
    }
  }

  /// Pushes the same uniform set the Skia painter uses, but without
  /// binding the image sampler — the live backdrop is bound
  /// automatically by `ImageFilter.shader`.
  ///
  /// Under `ImageFilter.shader`, `FlutterFragCoord()` returns
  /// **physical pixels**, not logical pixels. The Skia/CustomPaint path
  /// runs in logical pixels because the shader is bound via
  /// `Paint.shader`. To keep the GLSL untouched and behaving
  /// identically on both paths, every pixel-space uniform is scaled by
  /// [devicePixelRatio] here.
  ///
  /// [resolution] and [lensPosition] are passed in **screen space**
  /// (see the class doc) so the shader's geometry lines up with the
  /// screen-relative `FlutterFragCoord()`.
  void _setMainShaderUniformsForBackdrop({
    required ui.FragmentShader shader,
    required Size resolution,
    required Offset lensPosition,
    required double animValue,
    required double devicePixelRatio,
    required bool linearXform,
  }) {
    final cfg = widget.config;
    final shape = cfg.effectiveShape;

    final double configuredDistortionWidth =
        cfg.effectiveRefraction.effectiveDistortionWidth;
    final double effectiveDistortionWidth =
        configuredDistortionWidth - animValue * configuredDistortionWidth;
    final double effectiveMagnification =
        animValue + (cfg.effectiveRefraction.magnification * (1 - animValue));
    final double effectiveSaturation =
        animValue + (cfg.effectiveAppearance.saturation * (1 - animValue));
    final double effectiveChromaticAberration =
        cfg.effectiveRefraction.chromaticAberration * (1 - animValue);
    final double effectiveBorderAlpha = 1 - animValue;

    // The main shader always draws the border itself. On the Impeller
    // blur path the blur is painted BELOW this shader pass, so the
    // shader refracts the blurred backdrop while its border stays sharp
    // (drawn last, on top) — no separate border pass needed. Spatial
    // uniforms are scaled to physical px via `scale: devicePixelRatio`,
    // because `ImageFilter.shader`'s `FlutterFragCoord()` is physical.
    packLiquidGlassUniforms(
      shader,
      shape: shape,
      // Evaluate the shape at REST size: the deformation stretches the whole
      // outline instead of leaving a fixed radius to grow flat runs.
      shapeScale: widget.flexDeform.scaleFrom(widget.flexRestSize),
      scale: devicePixelRatio,
      resolution: resolution,
      lensPosition: lensPosition,
      lensWidth: cfg.geometry.width,
      lensHeight: cfg.geometry.height,
      magnification: effectiveMagnification,
      distortion: cfg.effectiveRefraction.effectiveDistortion,
      distortionWidth: effectiveDistortionWidth,
      enableInnerRadiusTransparent:
          cfg.effectiveAppearance.enableInnerRadiusTransparent,
      diagonalFlip: cfg.effectiveRefraction.diagonalFlip,
      // Full border-band width in logical px: doubled (the outer half is
      // clipped by the lens shape), plus the optical-mode extra. Passing
      // it here — rather than adding a constant inside the shader — lets
      // `packLiquidGlassUniforms` apply `scale` (dpr) so the rim has the
      // same logical width on Impeller as it does on Skia.
      borderWidth: shape.borderWidth * 2.0 +
          (shape.isOpticalBorder && shape.borderWidth > 0 ? 2.0 : 0.0),
      borderAlpha: effectiveBorderAlpha,
      chromaticAberration: effectiveChromaticAberration,
      saturation: effectiveSaturation,
      refractionMode: cfg.effectiveRefraction.refractionMode,
      refractionType: cfg.effectiveRefraction.refractionType,
      includeLensColor: true,
      lensColor: cfg.effectiveAppearance.color,
      // Impeller's live backdrop alpha is not a transparency signal
      // (reads 0 over dark regions); ignore it so the rim/body survive.
      honorBackdropAlpha: false,
      // Under ancestor scale/rotation the shader runs its geometry in
      // lens space through this map; identity keeps the legacy path.
      xformA: linearXform ? _xformA : 1,
      xformB: linearXform ? _xformB : 0,
      xformC: linearXform ? _xformC : 0,
      xformD: linearXform ? _xformD : 1,
      xformOffset: linearXform ? _layerGlobalOffset : Offset.zero,
    );
  }

  /// Impeller path build — uses BackdropFilter + ImageFilter.shader so
  /// the shader reads the live backdrop directly. No RepaintBoundary
  /// capture required.
  /// Feeds this lens's pointer events to the press springs. `Listener` (not
  /// `GestureDetector`) so it never joins the gesture arena: it cannot steal
  /// taps from the child's own buttons, nor fight the drag handler below it.
  Widget _wrapFlex(Widget child) {
    final driver = widget.flexDriver;
    if (driver == null) return child;
    final Size rest = widget.flexRestSize;
    return Listener(
      behavior: HitTestBehavior.translucent,
      // Every event carries its pointer id: the driver holds one finger's
      // worth of state, and a Listener reports all of them.
      onPointerDown: (event) =>
          driver.down(event.localPosition, rest, pointer: event.pointer),
      // Deltas, not positions: the lens is deforming under the finger.
      onPointerMove: (event) =>
          driver.move(event.delta, pointer: event.pointer),
      onPointerUp: (event) => driver.up(pointer: event.pointer),
      onPointerCancel: (event) => driver.up(pointer: event.pointer),
      child: child,
    );
  }

  Widget _buildImpellerLens(
      BuildContext context, Offset lensPosition, double animValue) {
    final config = widget.config;
    // `config` already carries the deformed size; shifting the origin here
    // keeps the glass, its blur and its content on the same deformed rect.
    lensPosition += widget.flexDeform.originShift;
    final useBlur = config.effectiveAppearance.blur.sigmaX > 0 ||
        config.effectiveAppearance.blur.sigmaY > 0;
    // The shader stretches the OUTLINE, so the clip has to stretch with it or
    // the blur beneath leaks past the glass edge at the corners.
    final Offset clipScale =
        widget.flexDeform.clipScaleFrom(widget.flexRestSize);
    final shader = widget.shader;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (shader == null) return const SizedBox.shrink();

    // Screen-space geometry for the shader (see class doc). The widget
    // layout below still uses the parent-relative `lensPosition`; only
    // the shader uniforms are shifted into screen space.
    final viewSize = MediaQuery.sizeOf(context);
    final Size resolution = (viewSize.width > 0 && viewSize.height > 0)
        ? viewSize
        : widget.parentSize;
    // Fresh matrix for THIS frame; the post-frame sync only schedules the
    // rebuilds that get us here while the transform keeps moving.
    _sampleTransformInBuild();
    // Under ancestor scale/rotation the position stays LENS-LOCAL and the
    // whole placement — translation included — rides the xform map, so
    // the shader's geometry lands exactly where the widget clip does.
    final bool linearXform = _hasLinearXform;
    final Offset screenLensPosition =
        linearXform ? lensPosition : lensPosition + _layerGlobalOffset;

    _setMainShaderUniformsForBackdrop(
      shader: shader,
      resolution: resolution,
      lensPosition: screenLensPosition,
      animValue: animValue,
      devicePixelRatio: dpr,
      linearXform: linearXform,
    );

    // Order matters: blur FIRST (below), shader SECOND (on top).
    //
    // Stacked BackdropFilters chain — each samples everything painted
    // behind it. By blurring the backdrop under the lens first, the
    // shader pass on top reads the ALREADY-BLURRED backdrop and
    // refracts that. So the background is blurred *before* refraction,
    // not "refract sharp, then blur the result". The shader also draws
    // the border, which stays sharp because it's the topmost pass.
    return _LensXformProbe(
      onMoved: _onLayerMoved,
      child: Stack(
      children: [
        // Blur the backdrop under the lens first, clipped to the lens
        // shape. This is the input the shader will refract.
        if (useBlur && liquidGlassUsesRoundedClip(config.effectiveShape))
          Positioned(
            left: lensPosition.dx,
            top: lensPosition.dy,
            width: config.geometry.width,
            height: config.geometry.height,
            child: IgnorePointer(
              ignoring: true,
              child: liquidGlassClip(
                shape: config.effectiveShape,
                shapeScale: clipScale,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: config.effectiveAppearance.blur.sigmaX,
                    sigmaY: config.effectiveAppearance.blur.sigmaY,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

        // Live-backdrop-sampling shader pass over the whole parent
        // rect. With blur on, the backdrop it reads is the blurred
        // patch above. The shapeMask zeroes everything outside the
        // lens, so output is transparent there.
        Positioned(
          left: lensPosition.dx,
          top: lensPosition.dy,
          width: config.geometry.width,
          height: config.geometry.height,
          child: IgnorePointer(
            ignoring: true,
            child: liquidGlassClip(
              shape: config.effectiveShape,
              shapeScale: clipScale,
              child: BackdropFilter(
                filter: ui.ImageFilter.shader(shader),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),

        // Draggable lens hit target + child content.
        Positioned(
          left: lensPosition.dx,
          top: lensPosition.dy,
          width: config.geometry.width - config.effectiveShape.borderWidth / 2,
          height:
              config.geometry.height - config.effectiveShape.borderWidth / 2,
          child: _wrapFlex(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: config.behavior.draggable
                  ? (details) {
                      widget.touch.value += details.delta;
                    }
                  : null,
              child: liquidGlassClip(
                shape: config.effectiveShape,
                shapeScale: clipScale,
                // Clip at the deformed bounds, scale the content inside:
                // the child stretches as pixels (never re-flows) and still
                // cannot spill past the glass edge.
                child: liquidGlassFlexChild(
                  deform: widget.flexDeform,
                  restSize: widget.flexRestSize,
                  child: config.child ?? Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  /// Deferred re-sync for the transform probe: it fires during scene
  /// building, where setState is illegal — check after the frame lands.
  void _onLayerMoved() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLayerOffset());
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync the lens layer's global offset after this frame settles;
    // only rebuilds when it actually changes. At rest the lens does no
    // per-frame work, so this fires only on (re)layout / drag / anim.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLayerOffset());

    // The lens rebuilds when either the show/hide animation ticks OR
    // the touch position changes. When neither is active (the common
    // case at rest), this subtree is fully idle and Impeller can keep
    // the BackdropFilter layer resident across frames.
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) => ValueListenableBuilder<Offset>(
        valueListenable: widget.touch,
        builder: (context, offset, _) =>
            _buildImpellerLens(context, offset, widget.animation.value),
      ),
    );
  }
}
