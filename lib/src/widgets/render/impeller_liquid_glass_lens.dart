import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../liquid_glass_config.dart';
import '../painters/liquid_glass_uniforms.dart';
import '../utils/liquid_glass_elasticity.dart';
import '../utils/liquid_glass_shape.dart';

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
  /// [LiquidGlassElasticityDeform.none] when no press is configured.
  final LiquidGlassElasticityDeform elasticityDeform;

  /// Spring driver fed by this lens's pointer events. Null disables the
  /// press behaviour entirely — no `Listener` is added to the tree.
  final LiquidGlassElasticityDriver? elasticityDriver;

  /// The lens's undeformed size, used to lay the child out at rest before
  /// scaling its pixels.
  final Size elasticityRestSize;

  const ImpellerLiquidGlassLens({
    super.key,
    required this.config,
    required this.parentSize,
    required this.shader,
    required this.touch,
    required this.animation,
    this.elasticityDeform = LiquidGlassElasticityDeform.none,
    this.elasticityDriver,
    this.elasticityRestSize = Size.zero,
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

  /// Re-reads this widget's global offset and rebuilds if it changed.
  void _syncLayerOffset() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final next = box.localToGlobal(Offset.zero);
    if ((next - _layerGlobalOffset).distanceSquared > 0.01) {
      setState(() => _layerGlobalOffset = next);
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
    );
  }

  /// Impeller path build — uses BackdropFilter + ImageFilter.shader so
  /// the shader reads the live backdrop directly. No RepaintBoundary
  /// capture required.
  /// Feeds this lens's pointer events to the press springs. `Listener` (not
  /// `GestureDetector`) so it never joins the gesture arena: it cannot steal
  /// taps from the child's own buttons, nor fight the drag handler below it.
  Widget _wrapElasticity(Widget child) {
    final driver = widget.elasticityDriver;
    if (driver == null) return child;
    final Size rest = widget.elasticityRestSize;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => driver.down(event.localPosition, rest),
      // Deltas, not positions: the lens is deforming under the finger.
      onPointerMove: (event) => driver.move(event.delta),
      onPointerUp: (_) => driver.up(),
      onPointerCancel: (_) => driver.up(),
      child: child,
    );
  }

  Widget _buildImpellerLens(
      BuildContext context, Offset lensPosition, double animValue) {
    final config = widget.config;
    // `config` already carries the deformed size; shifting the origin here
    // keeps the glass, its blur and its content on the same deformed rect.
    lensPosition += widget.elasticityDeform.originShift;
    final useBlur = config.effectiveAppearance.blur.sigmaX > 0 ||
        config.effectiveAppearance.blur.sigmaY > 0;
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
    final Offset screenLensPosition = lensPosition + _layerGlobalOffset;

    _setMainShaderUniformsForBackdrop(
      shader: shader,
      resolution: resolution,
      lensPosition: screenLensPosition,
      animValue: animValue,
      devicePixelRatio: dpr,
    );

    // Order matters: blur FIRST (below), shader SECOND (on top).
    //
    // Stacked BackdropFilters chain — each samples everything painted
    // behind it. By blurring the backdrop under the lens first, the
    // shader pass on top reads the ALREADY-BLURRED backdrop and
    // refracts that. So the background is blurred *before* refraction,
    // not "refract sharp, then blur the result". The shader also draws
    // the border, which stays sharp because it's the topmost pass.
    return Stack(
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
          child: _wrapElasticity(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: config.behavior.draggable
                  ? (details) {
                      widget.touch.value += details.delta;
                    }
                  : null,
              child: liquidGlassClip(
                shape: config.effectiveShape,
                // Clip at the deformed bounds, scale the content inside:
                // the child stretches as pixels (never re-flows) and still
                // cannot spill past the glass edge.
                child: liquidGlassElasticityChild(
                  deform: widget.elasticityDeform,
                  restSize: widget.elasticityRestSize,
                  child: config.child ?? Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
