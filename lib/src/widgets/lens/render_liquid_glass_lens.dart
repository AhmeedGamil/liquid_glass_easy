import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../liquid_glass_config.dart';
import '../painters/liquid_glass_uniforms.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_transform_tracking.dart';

/// How a [RenderLiquidGlassLens] produces its glass effect.
enum LiquidGlassLensRenderMode {
  /// `BackdropFilter` + `ImageFilter.shader`: the shader reads the live
  /// backdrop directly. Requires Impeller (or any engine where
  /// `ImageFilter.isShaderFilterSupported` is true). Needs no
  /// background capture at all.
  impellerBackdrop,

  /// `Paint.shader` sampling the parent view's **captured** background
  /// image. Requires an ancestor `LiquidGlassView` with a
  /// `backgroundWidget` (the Skia / Web path).
  skiaCapture,
}

/// Layout-driven liquid-glass lens render object.
///
/// The lens **is** this box: its size comes from layout and its position
/// from the render tree — there are no position/width/height inputs.
/// Uniforms are computed at paint time from the box's actual transform,
/// and [LensTransformTrackingMixin] repaints the lens whenever an
/// ancestor moves it (scroll, transitions) without rebuilding anything.
///
/// This render object is **animation-free by design**: it paints exactly
/// the [refraction]/[appearance]/[borderAlpha] values it is given. The
/// show/hide animation lives entirely in the widget layer, which passes
/// already-interpolated values down (and flips [glassEnabled] off when
/// fully hidden so the backdrop cost disappears).
///
/// Paint order (both modes): glass effect first, then the child on top.
/// The child itself is clipped by the widget layer, not here.
class RenderLiquidGlassLens extends RenderProxyBox
    with LensTransformTrackingMixin {
  RenderLiquidGlassLens({
    required LiquidGlassLensRenderMode mode,
    required ui.FragmentShader mainShader,
    ui.FragmentShader? borderShader,
    required LiquidGlassShape shape,
    Offset shapeScale = const Offset(1, 1),
    required LiquidGlassRefraction refraction,
    required LiquidGlassAppearance appearance,
    required double borderAlpha,
    required bool glassEnabled,
    required Size screenSize,
    required double devicePixelRatio,
    ValueListenable<int>? captureRevision,
    ui.Image? Function()? currentImage,
    ui.Image? Function()? captureFallback,
    RenderBox? Function()? backgroundRenderBox,
  })  : _mode = mode,
        _mainShader = mainShader,
        _borderShader = borderShader,
        _shape = shape,
        _shapeScale = shapeScale,
        _refraction = refraction,
        _appearance = appearance,
        _borderAlpha = borderAlpha,
        _glassEnabled = glassEnabled,
        _screenSize = screenSize,
        _devicePixelRatio = devicePixelRatio,
        _captureRevision = captureRevision,
        _currentImage = currentImage,
        _captureFallback = captureFallback,
        _backgroundRenderBox = backgroundRenderBox;

  LiquidGlassLensRenderMode _mode;
  set mode(LiquidGlassLensRenderMode value) {
    if (_mode == value) return;
    _mode = value;
    markNeedsPaint();
  }

  ui.FragmentShader _mainShader;
  set mainShader(ui.FragmentShader value) {
    if (_mainShader == value) return;
    _mainShader = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _borderShader;
  set borderShader(ui.FragmentShader? value) {
    if (_borderShader == value) return;
    _borderShader = value;
    markNeedsPaint();
  }

  LiquidGlassShape _shape;
  set shape(LiquidGlassShape value) {
    if (identical(_shape, value)) return;
    _shape = value;
    markNeedsPaint();
  }

  /// Deformed size / rest size; `(1,1)` when undeformed. Drives the shader's
  /// rest-space shape evaluation so a stretched circle stays an ellipse.
  Offset _shapeScale;
  set shapeScale(Offset value) {
    if (_shapeScale == value) return;
    _shapeScale = value;
    markNeedsPaint();
  }

  LiquidGlassRefraction _refraction;
  set refraction(LiquidGlassRefraction value) {
    if (identical(_refraction, value)) return;
    _refraction = value;
    markNeedsPaint();
  }

  LiquidGlassAppearance _appearance;
  set appearance(LiquidGlassAppearance value) {
    if (identical(_appearance, value)) return;
    _appearance = value;
    markNeedsPaint();
  }

  /// Opacity of the lens border/rim (`1` = fully drawn). The widget
  /// layer fades this during the show/hide animation.
  double _borderAlpha;
  set borderAlpha(double value) {
    if (_borderAlpha == value) return;
    _borderAlpha = value;
    markNeedsPaint();
  }

  /// Whether the glass effect paints at all. The widget layer turns
  /// this off when the lens is fully hidden, so a hidden lens costs no
  /// backdrop passes — only its child is painted.
  bool _glassEnabled;
  set glassEnabled(bool value) {
    if (_glassEnabled == value) return;
    _glassEnabled = value;
    markNeedsPaint();
  }

  /// Logical size of the FlutterView, used as the shader resolution on
  /// the Impeller path (where `FlutterFragCoord()` is screen-space).
  Size _screenSize;
  set screenSize(Size value) {
    if (_screenSize == value) return;
    _screenSize = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  ValueListenable<int>? _captureRevision;
  set captureRevision(ValueListenable<int>? value) {
    if (_captureRevision == value) return;
    if (attached) _captureRevision?.removeListener(markNeedsPaint);
    _captureRevision = value;
    if (attached) _captureRevision?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  ui.Image? Function()? _currentImage;
  set currentImage(ui.Image? Function()? value) {
    if (_currentImage == value) return;
    _currentImage = value;
    markNeedsPaint();
  }

  ui.Image? Function()? _captureFallback;
  set captureFallback(ui.Image? Function()? value) {
    if (_captureFallback == value) return;
    _captureFallback = value;
    markNeedsPaint();
  }

  RenderBox? Function()? _backgroundRenderBox;
  set backgroundRenderBox(RenderBox? Function()? value) {
    if (_backgroundRenderBox == value) return;
    _backgroundRenderBox = value;
    markNeedsPaint();
  }

  final LayerHandle<ClipRRectLayer> _clipLayerHandle =
      LayerHandle<ClipRRectLayer>();
  final LayerHandle<BackdropFilterLayer> _blurLayerHandle =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<BackdropFilterLayer> _shaderLayerHandle =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRRectLayer> _skiaBlurClipLayerHandle =
      LayerHandle<ClipRRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _captureRevision?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _captureRevision?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayerHandle.layer = null;
    _blurLayerHandle.layer = null;
    _shaderLayerHandle.layer = null;
    _skiaBlurClipLayerHandle.layer = null;
    super.dispose();
  }

  bool get _useBlur =>
      _appearance.blur.sigmaX > 0 || _appearance.blur.sigmaY > 0;

  /// Packs the shared uniform block straight from the current values —
  /// no interpolation here; the widget layer already resolved any
  /// show/hide animation into [_refraction]/[_appearance]/[_borderAlpha].
  void _packUniforms(
    ui.FragmentShader shader, {
    required Size resolution,
    required Offset lensPosition,
    required double scale,
    required double borderWidth,
    required bool includeLensColor,
    // Lens-anywhere lenses never honor the captured backdrop's alpha: the
    // capture is treated as opaque so the optical rim/body survive over dark
    // or empty regions. Only the slider/toggle (a separate painter path) opt
    // in. Both paint paths here inherit this; Impeller also passes it
    // explicitly for clarity.
    bool honorBackdropAlpha = false,
    Offset imageOffset = Offset.zero,
    Size? imageSize,
  }) {
    packLiquidGlassUniforms(
      shader,
      shape: _shape,
      shapeScale: _shapeScale,
      scale: scale,
      resolution: resolution,
      lensPosition: lensPosition,
      lensWidth: size.width,
      lensHeight: size.height,
      magnification: _refraction.magnification,
      distortion: _refraction.effectiveDistortion,
      distortionWidth: _refraction.effectiveDistortionWidth,
      enableInnerRadiusTransparent: _appearance.enableInnerRadiusTransparent,
      diagonalFlip: _refraction.diagonalFlip,
      borderWidth: borderWidth,
      borderAlpha: _borderAlpha,
      chromaticAberration: _refraction.chromaticAberration,
      saturation: _appearance.saturation,
      refractionMode: _refraction.refractionMode,
      refractionType: _refraction.refractionType,
      includeLensColor: includeLensColor,
      lensColor: _appearance.color,
      honorBackdropAlpha: honorBackdropAlpha,
      imageOffset: imageOffset,
      imageSize: imageSize,
    );
  }

  double get _fullBorderWidth =>
      _shape.borderWidth * 2.0 +
      (_shape.isOpticalBorder && _shape.borderWidth > 0 ? 2.0 : 0.0);

  @override
  void paint(PaintingContext context, Offset offset) {
    pushTransformTracking(context, offset);

    // Disabled (fully hidden) or zero-sized: skip the glass entirely —
    // no backdrop cost — but keep painting the child; whether IT hides
    // stays the caller's call.
    if (!_glassEnabled || size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    switch (_mode) {
      case LiquidGlassLensRenderMode.impellerBackdrop:
        _paintImpeller(context, offset);
      case LiquidGlassLensRenderMode.skiaCapture:
        _paintSkiaCapture(context, offset);
    }
  }

  // ── Impeller: live backdrop, no captures ──────────────────────────

  void _paintImpeller(PaintingContext context, Offset offset) {
    // Under ImageFilter.shader, FlutterFragCoord() is screen-space
    // physical pixels, so position/resolution are global. Computed at
    // paint time, where the transform is exact for this frame.
    final Offset globalTopLeft =
        MatrixUtils.transformPoint(getTransformTo(null), Offset.zero);

    _packUniforms(
      _mainShader,
      resolution: _screenSize,
      lensPosition: globalTopLeft,
      scale: _devicePixelRatio,
      // The main shader draws its own border on this path: the blur
      // pass sits BELOW the shader pass, so the rim stays sharp.
      borderWidth: _fullBorderWidth,
      includeLensColor: true,
      // Impeller's live backdrop alpha is not a transparency signal
      // (reads 0 over dark regions); ignore it so the rim/body survive.
      honorBackdropAlpha: false,
    );

    final double radius = liquidGlassClipCornerRadius(_shape);
    final RRect localRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    _clipLayerHandle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      localRRect,
      (PaintingContext context, Offset offset) {
        // Order matters: blur first (below), shader second (on top) —
        // stacked BackdropFilters chain, so the shader refracts the
        // already-blurred backdrop and draws its sharp border last.
        if (_useBlur) {
          final blurLayer = _blurLayerHandle.layer ??= BackdropFilterLayer();
          blurLayer.filter = ui.ImageFilter.blur(
            sigmaX: _appearance.blur.sigmaX,
            sigmaY: _appearance.blur.sigmaY,
          );
          context.pushLayer(
              blurLayer, (PaintingContext context, Offset offset) {}, offset);
        } else {
          _blurLayerHandle.layer = null;
        }

        final shaderLayer = _shaderLayerHandle.layer ??= BackdropFilterLayer();
        shaderLayer.filter = ui.ImageFilter.shader(_mainShader);
        context.pushLayer(
            shaderLayer, (PaintingContext context, Offset offset) {}, offset);
      },
      oldLayer: _clipLayerHandle.layer,
    );

    // Child on top of the glass.
    super.paint(context, offset);
  }

  // ── Skia / Web: sample the view's captured background ─────────────

  void _paintSkiaCapture(PaintingContext context, Offset offset) {
    final RenderBox? viewBox = _backgroundRenderBox?.call();
    final ui.Image? image = _currentImage?.call() ?? _captureFallback?.call();
    if (viewBox == null ||
        !viewBox.attached ||
        !viewBox.hasSize ||
        image == null) {
      // Soft-fail like the legacy pipeline: skip the glass this frame.
      super.paint(context, offset);
      return;
    }

    // The captured image lives in the background boundary's coordinate
    // space; map this lens's rect into it. Skia Paint.shader evaluates
    // FlutterFragCoord() in the draw's local space, so translating the
    // canvas into view space makes fragments, uniforms and the sampled
    // image all agree — wherever this lens sits in the tree.
    final Offset lensPosInView =
        MatrixUtils.transformPoint(getTransformTo(viewBox), Offset.zero);
    final Size viewSize = viewBox.size;
    final bool useBlur = _useBlur;
    final double radius = liquidGlassClipCornerRadius(_shape);

    _packUniforms(
      _mainShader,
      resolution: viewSize,
      lensPosition: lensPosInView,
      scale: 1.0,
      // Blur path: suppress the main-pass border; a sharp border pass
      // is drawn on top of the blur below (mirrors the legacy painter).
      borderWidth: useBlur ? 0.0 : _fullBorderWidth,
      includeLensColor: true,
    );
    _mainShader.setImageSampler(0, image);

    final Rect viewSpaceRect = lensPosInView & size;
    final RRect viewSpaceRRect =
        RRect.fromRectAndRadius(viewSpaceRect, Radius.circular(radius));

    final ui.Canvas canvas = context.canvas;
    canvas
      ..save()
      ..translate(offset.dx - lensPosInView.dx, offset.dy - lensPosInView.dy)
      ..clipRRect(viewSpaceRRect)
      ..drawRRect(viewSpaceRRect, Paint()..shader = _mainShader)
      ..restore();

    if (useBlur && liquidGlassUsesRoundedClip(_shape)) {
      // Backdrop blur above the refraction, clipped to the lens shape.
      final RRect localRRect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      );
      _skiaBlurClipLayerHandle.layer = context.pushClipRRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        localRRect,
        (PaintingContext context, Offset offset) {
          final blurLayer = _blurLayerHandle.layer ??= BackdropFilterLayer();
          blurLayer.filter = ui.ImageFilter.blur(
            sigmaX: _appearance.blur.sigmaX,
            sigmaY: _appearance.blur.sigmaY,
          );
          context.pushLayer(
              blurLayer, (PaintingContext context, Offset offset) {}, offset);
        },
        oldLayer: _skiaBlurClipLayerHandle.layer,
      );

      // Sharp border pass on top of the blur.
      final ui.FragmentShader? borderShader = _borderShader;
      if (borderShader != null) {
        _packUniforms(
          borderShader,
          resolution: viewSize,
          lensPosition: lensPosInView,
          scale: 1.0,
          borderWidth: _fullBorderWidth,
          includeLensColor: false,
        );
        borderShader.setImageSampler(0, image);
        final ui.Canvas borderCanvas = context.canvas;
        borderCanvas
          ..save()
          ..translate(
              offset.dx - lensPosInView.dx, offset.dy - lensPosInView.dy)
          ..drawRRect(viewSpaceRRect, Paint()..shader = borderShader)
          ..restore();
      }
    } else {
      _skiaBlurClipLayerHandle.layer = null;
      _blurLayerHandle.layer = null;
    }

    // Child on top of the glass.
    super.paint(context, offset);
  }
}
