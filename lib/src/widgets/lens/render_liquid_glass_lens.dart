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

/// How the Impeller shader pass is clipped. Library-internal.
///
/// The shader draws the outline itself, with an anti-aliasing ramp centred
/// on it. What clips the pass decides whether the outer half of that ramp
/// survives, and what the pass's coverage is — which the engine rounds out
/// to whole pixels every frame.
enum LiquidGlassShaderClip {
  /// The exact outline, as in 4.0.0: the ramp's outer half is trimmed, so
  /// the edge is exactly the shape. The coverage is the lens box,
  /// fractional; the frame is packed against the engine's rounded copy of it
  /// ([RenderLiquidGlassLens._passRounding]) so the content does not
  /// re-frame while the lens moves or squashes.
  outlineTracked,

  /// The exact outline with the frame packed naively — 4.0.0 as shipped,
  /// in-flight wobble included. Kept only to A/B [outlineTracked] against.
  outline,

  /// A rect two logical px past the box, snapped out to whole physical
  /// pixels, as in 4.1.0: the rounding is a no-op, so nothing re-frames,
  /// and the ramp's outer half stays — the edge reads ~0.5 lp softer. The
  /// package's moving pills (tab bar, slider, switch) use this.
  snapped,
}

/// The Impeller lens's shader pass, resolved at **compositing time**.
///
/// The one job of this layer is timing. A scroll moves the lens by
/// re-offsetting retained layers — the lens's `paint()` never runs, so
/// uniforms packed at paint time are one frame stale, and the glass
/// visibly trails its own (always-correct) clip. Scene building is the
/// one stage that is both late enough (layout and paint are final) and
/// guaranteed to run every frame ([alwaysNeedsAddToScene]), so the
/// transform sampled here is exact: pack the uniforms, wrap the shader,
/// push the backdrop — all inside [addToScene]. `pushBackdropFilter`
/// converts the filter to its native form right here, so the uniforms
/// it captures are the ones just packed.
class _ImpellerShaderBackdropLayer extends ContainerLayer {
  /// The lens this layer paints for. Cleared on detach so a dead render
  /// object is never sampled.
  RenderLiquidGlassLens? renderObject;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final RenderLiquidGlassLens? lens = renderObject;
    if (lens == null || !lens.attached) return;
    lens._packImpellerMainUniforms();
    engineLayer = builder.pushBackdropFilter(
      lens._impellerFilter,
      oldLayer: engineLayer as ui.BackdropFilterEngineLayer?,
      // Set inside a LiquidGlassBatch: every member pushes the same key, so
      // the engine reads the backdrop once and they all sample that copy.
      backdropId: lens._backdropId,
    );
    addChildrenToScene(builder);
    builder.pop();
  }
}

/// Layout-driven liquid-glass lens render object.
///
/// The lens **is** this box: its size comes from layout and its position
/// from the render tree — there are no position/width/height inputs.
/// On the Impeller path the shader uniforms are packed at **compositing
/// time** by [_ImpellerShaderBackdropLayer], so they always carry this
/// frame's final transform — even when a scroll moves the lens by
/// re-offsetting retained layers without ever repainting it. The Skia
/// path packs at paint time and uses [LensTransformTrackingMixin] to
/// repaint when an ancestor moves it (one frame late by construction).
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
    Offset clipScale = const Offset(1, 1),
    required LiquidGlassRefraction refraction,
    required LiquidGlassAppearance appearance,
    required double borderAlpha,
    required bool glassEnabled,
    bool honorBackdropAlpha = false,
    required Size screenSize,
    required double devicePixelRatio,
    int? backdropId,
    required LiquidGlassShaderClip shaderClip,
    ValueListenable<int>? captureRevision,
    ui.Image? Function()? currentImage,
    ui.Image? Function()? captureFallback,
    RenderBox? Function()? backgroundRenderBox,
  })  : _mode = mode,
        _backdropId = backdropId,
        _shaderClip = shaderClip,
        _honorBackdropAlpha = honorBackdropAlpha,
        _mainShader = mainShader,
        _borderShader = borderShader,
        _shape = shape,
        _shapeScale = shapeScale,
        _clipScale = clipScale,
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

  /// The `LiquidGlassBatch` this lens belongs to, as the shared backdrop key
  /// every member hands to `pushBackdropFilter`. Impeller reads the backdrop
  /// once per key, so a batch of any size costs one read instead of one each.
  ///
  /// It also changes what this lens pushes: a batched lens with blur folds
  /// the Gaussian into its single backdrop pass (see [_paintImpellerBatched])
  /// instead of stacking a second one under it. `null` — no batch — keeps the
  /// two-pass path.
  /// See [LiquidGlassShaderClip]. Impeller, unbatched path only — the
  /// batched pass keeps its padded rect, which the composed blur needs.
  LiquidGlassShaderClip _shaderClip;
  set shaderClip(LiquidGlassShaderClip value) {
    if (_shaderClip == value) return;
    _shaderClip = value;
    markNeedsPaint();
  }

  int? _backdropId;
  set backdropId(int? value) {
    if (_backdropId == value) return;
    _backdropId = value;
    // The key is baked into the pushed engine layer, so start a fresh one
    // rather than handing the old layer to a push with a different id.
    _shaderLayerHandle.layer?.renderObject = null;
    _shaderLayerHandle.layer = null;
    markNeedsPaint();
  }

  /// Whether the shader folds the captured backdrop's alpha into its own
  /// coverage. Skia capture path only.
  ///
  /// `false` treats the capture as opaque, which matches Impeller and is
  /// right for a view whose background is a full page. Set it when the
  /// captured background carries **authored** transparency that has to
  /// show through the glass — a slider's track, say — where opaque
  /// treatment renders the lens's overhang as a dark body.
  bool _honorBackdropAlpha;
  set honorBackdropAlpha(bool value) {
    if (_honorBackdropAlpha == value) return;
    _honorBackdropAlpha = value;
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

  /// The clips' scale. Same as [_shapeScale] normally; pinned to `(1,1)` under
  /// the shader-only debug mode so the mismatch can be seen.
  Offset _clipScale;
  set clipScale(Offset value) {
    if (_clipScale == value) return;
    _clipScale = value;
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

  /// The lens outline as an RRect, stretched by [_shapeScale].
  ///
  /// The shader evaluates the shape at REST size and scales the domain, so the
  /// corner it draws is ELLIPTICAL (`r*sx` by `r*sy`). A circular RRect crosses
  /// that outline instead of matching it: near the cap apex it sits INSIDE the
  /// glass and shaves the rim off entirely. `Radius.elliptical` is the same
  /// curve the shader draws, so the two coincide.
  RRect _outlineRRect(Rect rect) {
    final double r = liquidGlassClipCornerRadius(_shape);
    final double sx = _clipScale.dx <= 0 ? 1.0 : _clipScale.dx;
    final double sy = _clipScale.dy <= 0 ? 1.0 : _clipScale.dy;
    return (sx == 1.0 && sy == 1.0)
        ? RRect.fromRectAndRadius(rect, Radius.circular(r))
        : RRect.fromRectAndRadius(rect, Radius.elliptical(r * sx, r * sy));
  }

  // The outline costs a few hundred pow/trig calls to build, and `paint` asks
  // for it up to three times a frame (glass clip, shader draw, blur clip).
  // Keyed on everything `liquidGlassOutlinePath` reads, so a stale one is not
  // representable — no setter has to remember to invalidate it.
  Path? _cachedOutline;
  Size? _cachedOutlineSize;
  double? _cachedOutlineRadius;
  Offset? _cachedOutlineScale;
  LiquidGlassCornerStyle? _cachedOutlineCorner;

  /// [_outlineRRect]'s counterpart for the squircle and continuous curves,
  /// whose outline an `RRect` can only approximate. Honors the shape's
  /// [LiquidGlassClipQuality].
  Path _outlinePath(Rect rect) {
    final double radius = liquidGlassClipCornerRadius(_shape);
    if (_cachedOutline == null ||
        _cachedOutlineSize != rect.size ||
        _cachedOutlineRadius != radius ||
        _cachedOutlineScale != _clipScale ||
        _cachedOutlineCorner != _shape.cornerStyle) {
      _cachedOutline = liquidGlassOutlinePath(_shape, rect.size, _clipScale);
      _cachedOutlineSize = rect.size;
      _cachedOutlineRadius = radius;
      _cachedOutlineScale = _clipScale;
      _cachedOutlineCorner = _shape.cornerStyle;
    }
    // `shift` copies, so skip it where the offset is zero — which is both
    // clip call sites, and the Skia draw too once an ancestor transform
    // puts it in lens space. Only the view-space draw needs the shifted
    // copy: its shader reads FlutterFragCoord() in the draw's own space.
    return rect.topLeft == Offset.zero
        ? _cachedOutline!
        : _cachedOutline!.shift(rect.topLeft);
  }

  /// Whether this lens clips with [_outlinePath] instead of [_outlineRRect].
  bool get _exactClip => liquidGlassUsesExactClipPath(_shape);

  final LayerHandle<ClipRRectLayer> _clipLayerHandle =
      LayerHandle<ClipRRectLayer>();
  final LayerHandle<ClipPathLayer> _clipPathLayerHandle =
      LayerHandle<ClipPathLayer>();
  final LayerHandle<ClipPathLayer> _skiaBlurClipPathLayerHandle =
      LayerHandle<ClipPathLayer>();
  final LayerHandle<BackdropFilterLayer> _blurLayerHandle =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<_ImpellerShaderBackdropLayer> _shaderLayerHandle =
      LayerHandle<_ImpellerShaderBackdropLayer>();
  final LayerHandle<ClipRectLayer> _shaderClipRectLayerHandle =
      LayerHandle<ClipRectLayer>();
  final LayerHandle<ClipRRectLayer> _shaderClipRRectLayerHandle =
      LayerHandle<ClipRRectLayer>();
  final LayerHandle<ClipPathLayer> _shaderClipPathLayerHandle =
      LayerHandle<ClipPathLayer>();
  final LayerHandle<ClipRRectLayer> _skiaBlurClipLayerHandle =
      LayerHandle<ClipRRectLayer>();

  /// The lens-local rect the shader pass was pushed inside this paint: the
  /// bound of whichever clip layer holds [_shaderLayerHandle]'s layer. Known
  /// in lens space here and in layer space there, it is what lines the two
  /// frames up in [_ancestorClipInSurface].
  Rect? _pushedShaderClip;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _captureRevision?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _captureRevision?.removeListener(markNeedsPaint);
    _shaderLayerHandle.layer?.renderObject = null;
    super.detach();
  }

  @override
  void dispose() {
    _clipLayerHandle.layer = null;
    _clipPathLayerHandle.layer = null;
    _blurLayerHandle.layer = null;
    _shaderLayerHandle.layer = null;
    _shaderClipRectLayerHandle.layer = null;
    _shaderClipRRectLayerHandle.layer = null;
    _shaderClipPathLayerHandle.layer = null;
    _skiaBlurClipLayerHandle.layer = null;
    _skiaBlurClipPathLayerHandle.layer = null;
    super.dispose();
  }

  bool get _useBlur =>
      _appearance.blur.sigmaX > 0 || _appearance.blur.sigmaY > 0;

  /// The batched pass's clip, in lens-local logical px, while the blur is
  /// composed into the shader — and `null` on every other path.
  ///
  /// Set at paint time, read back at compositing time: it is both the flag
  /// that says "compose the blur in" and the frame the uniforms are packed
  /// against, since composing bounds the shader's input to this rect.
  Rect? _batchClip;

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
    // Lens→shader affine map for ancestor scale/rotation. Shader space is
    // the screen on Impeller, the captured view on Skia.
    double xformA = 1,
    double xformB = 0,
    double xformC = 0,
    double xformD = 1,
    Offset xformOffset = Offset.zero,
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
      xformA: xformA,
      xformB: xformB,
      xformC: xformC,
      xformD: xformD,
      xformOffset: xformOffset,
    );
  }

  double get _fullBorderWidth =>
      _shape.borderWidth * 2.0 +
      (_shape.isOpticalBorder && _shape.borderWidth > 0 ? 2.0 : 0.0);

  @override
  void paint(PaintingContext context, Offset offset) {
    // The Impeller pass samples its own transform at compositing time
    // (see _ImpellerShaderBackdropLayer); only the Skia capture path
    // still needs the probe to repaint when an ancestor moves it.
    if (_mode == LiquidGlassLensRenderMode.skiaCapture) {
      pushTransformTracking(context, offset);
    }

    // Disabled (fully hidden) or zero-sized: skip the glass entirely —
    // no backdrop cost — but keep painting the child; whether IT hides
    // stays the caller's call.
    if (!_glassEnabled || size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    switch (_mode) {
      case LiquidGlassLensRenderMode.impellerBackdrop:
        // A batch shares one backdrop read across all its lenses, which only
        // works if each is a single pass — a different paint path, not just a
        // key on the same one.
        if (_backdropId != null) {
          _paintImpellerBatched(context, offset);
        } else {
          _paintImpeller(context, offset);
        }
      case LiquidGlassLensRenderMode.skiaCapture:
        _paintSkiaCapture(context, offset);
    }
  }

  // ── Impeller: live backdrop, no captures ──────────────────────────

  /// Packs the main-shader uniforms for the Impeller backdrop pass.
  ///
  /// Under ImageFilter.shader, FlutterFragCoord() is physical pixels
  /// measured from the corner of whatever surface the pass renders into
  /// — normally the window, so position and resolution are global.
  /// Called from [_ImpellerShaderBackdropLayer.addToScene] during scene
  /// building — after all layout and paint — so the transform is final
  /// for the frame, scroll offsets included.
  void _packImpellerMainUniforms() {
    // That surface is not always the window. An ancestor can render this
    // lens into a filtered subpass — Android's stretch overscroll does,
    // for exactly as long as the pull lasts — and the fragments then
    // arrive in THAT texture's space, while the clip rides the layer tree
    // and lands correctly regardless. Measuring the geometry from the same
    // corner the fragments do is what keeps the two together; a null
    // ancestor is the ordinary case and means the window.
    final RenderObject? subpassAncestor =
        liquidGlassFilterSubpassAncestor(this);
    final Matrix4 transform = getTransformTo(subpassAncestor);
    // Column-major storage: [0]=a, [4]=b, [1]=c, [5]=d, [12..13]=t.
    final s = transform.storage;
    // Ancestor scale/rotation? The clip rides the layer tree and gets it
    // for free; the shader paints from these uniforms and does not. So
    // the geometry goes LENS-LOCAL — position included — and the shader
    // maps fragments through the inverse of this lens→screen map (and
    // refracted samples forward). Translation-only keeps the legacy
    // screen-space uniforms bit-identical.
    final bool linearXform = (s[0] - 1).abs() > 1e-4 ||
        s[4].abs() > 1e-4 ||
        s[1].abs() > 1e-4 ||
        (s[5] - 1).abs() > 1e-4;
    // The surface the pass renders into is also the one it SAMPLES: the
    // backdrop arrives as that texture, so the sampling window is its size.
    // A subpass is smaller than the window by whatever sits outside the
    // filtered subtree, and dividing by the window instead squeezes the
    // whole page into the glass — the rows above and below the lens end up
    // refracted inside it.
    final Size? subpassSize =
        subpassAncestor is RenderBox ? subpassAncestor.size : null;
    // Batched with a composed blur, the shader reads an intermediate bounded
    // by the pass's clip, so FlutterFragCoord starts at that rect's top-left:
    // pack the whole frame there — origin, resolution and sampling window —
    // or the pieces desync and the glass slides inside its own outline. The
    // rect that counts is the one the ENGINE ends up with, not the one we
    // asked for; see [_composedPassRect].
    final Rect? clip = _batchClip;
    final Rect? clipInScreen = clip == null
        ? null
        : _composedPassRect(transform,
            MatrixUtils.transformRect(transform, clip),
            subpassAncestor,
            subpassSize);
    final Offset origin = clipInScreen?.topLeft ?? Offset.zero;
    // Outline-clipped plain pass: the coverage is the fractional lens box,
    // and the engine rounds it out. The shader's frame is shifted by the
    // fraction the rounding eats, so the content lands where it would have
    // on a whole-pixel box. Zero on the pixel grid, where the snapped clip
    // and this agree by construction.
    final Offset track = (clip == null &&
            !linearXform &&
            _shaderClip == LiquidGlassShaderClip.outlineTracked)
        ? _passRounding(transform, subpassAncestor, subpassSize)
        : Offset.zero;
    _packUniforms(
      _mainShader,
      resolution: clipInScreen?.size ?? subpassSize ?? _screenSize,
      lensPosition: linearXform
          ? Offset.zero
          : MatrixUtils.transformPoint(transform, Offset.zero) - origin + track,
      scale: _devicePixelRatio,
      // The main shader draws its own border on this path: the blur
      // pass sits BELOW the shader pass, so the rim stays sharp.
      borderWidth: _fullBorderWidth,
      includeLensColor: true,
      // Impeller's live backdrop alpha is not a transparency signal
      // (reads 0 over dark regions); ignore it so the rim/body survive.
      honorBackdropAlpha: false,
      // Clip-local snapshot → sample it from its own origin, window = the
      // rect. Tracked: the full-surface texture, seen from the shifted frame.
      imageOffset: track,
      imageSize: clipInScreen?.size,
      xformA: linearXform ? s[0] : 1,
      xformB: linearXform ? s[4] : 0,
      xformC: linearXform ? s[1] : 0,
      xformD: linearXform ? s[5] : 1,
      xformOffset: linearXform ? Offset(s[12], s[13]) - origin : Offset.zero,
    );
  }

  /// Where the composed pass's intermediate actually lands, in surface
  /// coordinates.
  ///
  /// [_pushShaderPass] asks for a clip; the engine gives it that rect
  /// INTERSECTED with every clip already on the stack, and bounds the
  /// composed intermediate by the result. So the origin `FlutterFragCoord()`
  /// counts from is the intersection's top-left, not the one we asked for —
  /// and the two part company the moment an ancestor cuts our rect.
  ///
  /// Losing the right or bottom edge is harmless: a rect cut there keeps its
  /// origin. Losing the LEFT or TOP moves it, and the glass is then drawn
  /// that far from the outline it belongs to — the lens slides bodily out of
  /// its own box while its child stays put. It is not an edge case either:
  /// this clip is padded by three sigma of blur plus the whole refraction
  /// band, so it hangs tens of logical pixels outside the lens and anything
  /// near a screen or viewport edge is cut. A two-column grid of batched
  /// lenses shows it as a left column pushed right and a right column that
  /// looks perfectly fine.
  ///
  /// The clips come from the layer tree ([_ancestorClipInSurface]), which
  /// is what the engine sees — not from render objects' estimates of what
  /// they might clip.
  Rect _composedPassRect(Matrix4 transform, Rect rawInSurface,
      RenderObject? surface, Size? surfaceSize) {
    Rect cut =
        rawInSurface.intersect(Offset.zero & (surfaceSize ?? _screenSize));
    final Rect? ancestors = _ancestorClipInSurface(transform, surface);
    if (ancestors != null) cut = cut.intersect(ancestors);
    // Clipped away entirely: none of this lens is on screen this frame, and
    // an empty rect would hand the shader a zero resolution to divide by.
    return cut.isEmpty ? rawInSurface : cut;
  }

  /// What the clip layers above this lens cut from its pass, in [surface]'s
  /// coordinates ([transform] being the lens→surface map) — null when none
  /// of them clips.
  ///
  /// Read off the layer tree at compositing time, so it is what the engine
  /// gets THIS frame: a viewport that reports a clip but pushed none does not
  /// count, and a page mid-slide is where its layers say it is. A render
  /// object's `describeApproximatePaintClip` gets both wrong — a short list
  /// under a route transition put the glass ahead of its page by exactly the
  /// phantom edge.
  ///
  /// The layers' frame and [transform]'s differ by the paint offsets on the
  /// way down, so the lens's own clip — the one rect known in both — lines
  /// them up: same linear part on both sides, only a translation to settle.
  Rect? _ancestorClipInSurface(Matrix4 transform, RenderObject? surface) {
    final Layer? own = _shaderLayerHandle.layer?.parent;
    final Rect? pushed = _pushedShaderClip;
    if (own == null || pushed == null) return null;
    final Rect? ownInLayer = liquidGlassLayerClipBounds(own);
    if (ownInLayer == null) return null;
    // ignore: invalid_use_of_protected_member
    final Layer? until = surface?.layer;
    final LiquidGlassLayerClip above =
        liquidGlassAncestorLayerClip(own, until: until);
    final Rect? clip = above.clip;
    if (clip == null) return null;
    final Offset inTop =
        MatrixUtils.transformRect(above.toTop, ownInLayer).topLeft;
    final Offset inSurface = MatrixUtils.transformRect(transform, pushed).topLeft;
    return clip.shift(inSurface - inTop);
  }

  /// Which way the frame is shifted against the engine's rounding. `1`
  /// assumes the engine reports fragments from the fractional corner while
  /// placing the pass at the rounded one; `-1` the reverse. Settled on the
  /// device, not on paper: if the tracked mode DOUBLES the wobble, flip it.
  static const double _trackDirection = 1;

  /// How far the engine's rounded coverage of the outline-clipped pass sits
  /// from the fractional one, in logical px, signed by [_trackDirection].
  ///
  /// The pass's coverage is the lens box in surface space, cut by whatever
  /// clips sit above it (as [_composedPassRect] cuts the batched rect), and
  /// the engine rounds that out to whole physical pixels. Only the corner
  /// matters: the size rounds too, but the shader never divides by it here —
  /// the sampling window stays the full surface.
  Offset _passRounding(
      Matrix4 transform, RenderObject? surface, Size? surfaceSize) {
    final Rect raw = _composedPassRect(
        transform,
        MatrixUtils.transformRect(transform, Offset.zero & size),
        surface,
        surfaceSize);
    final double dpr = _devicePixelRatio;
    final Offset rounded = Offset(
      (raw.left * dpr).floorToDouble() / dpr,
      (raw.top * dpr).floorToDouble() / dpr,
    );
    return (raw.topLeft - rounded) * _trackDirection;
  }

  /// How far the shader pass's rectangular clip extends past the lens box,
  /// in logical px. Covers the outer half of the shader's centered edge-AA
  /// ramp (and any rim feather), so the visible outline never meets the clip.
  static const double _shaderClipPad = 2.0;

  void _paintImpeller(PaintingContext context, Offset offset) {
    // Order matters: blur first (below), shader second (on top) — stacked
    // BackdropFilters chain, so the shader refracts the already-blurred
    // backdrop and draws its sharp border last. The blur keeps the exact
    // outline clip: unlike the shader, blur FILLS its clip, so a looser
    // one would halo blurred backdrop outside the glass.
    if (_useBlur) {
      void paintBlur(PaintingContext context, Offset offset) {
        final blurLayer = _blurLayerHandle.layer ??= BackdropFilterLayer();
        blurLayer.filter = ui.ImageFilter.blur(
          sigmaX: _appearance.blur.sigmaX,
          sigmaY: _appearance.blur.sigmaY,
        );
        context.pushLayer(
            blurLayer, (PaintingContext context, Offset offset) {}, offset);
      }

      if (_exactClip) {
        _clipLayerHandle.layer = null;
        _clipPathLayerHandle.layer = context.pushClipPath(
          needsCompositing,
          offset,
          Offset.zero & size,
          _outlinePath(Offset.zero & size),
          paintBlur,
          oldLayer: _clipPathLayerHandle.layer,
        );
      } else {
        _clipPathLayerHandle.layer = null;
        _clipLayerHandle.layer = context.pushClipRRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          _outlineRRect(Offset.zero & size),
          paintBlur,
          oldLayer: _clipLayerHandle.layer,
        );
      }
    } else {
      _blurLayerHandle.layer = null;
      _clipLayerHandle.layer = null;
      _clipPathLayerHandle.layer = null;
    }

    // What clips the shader pass — see [LiquidGlassShaderClip]. The shader
    // draws the outline itself (centered edge AA in computeShapeMask), so
    // the clip is either the outline, which trims the ramp's outer half, or
    // a snapped bound around it, which keeps it. Fractional coverage is what
    // re-frames the engine's intermediate in flight; the outline modes take
    // that fraction into the frame instead ([_passRounding]), the snapped
    // one never has it.
    _batchClip = null;
    switch (_shaderClip) {
      case LiquidGlassShaderClip.snapped:
        _shaderClipRRectLayerHandle.layer = null;
        _shaderClipPathLayerHandle.layer = null;
        _pushShaderPass(context, offset,
            _snappedShaderClip(_shaderClipPad, _shaderClipPad));
      case LiquidGlassShaderClip.outline:
      case LiquidGlassShaderClip.outlineTracked:
        _shaderClipRectLayerHandle.layer = null;
        _pushedShaderClip = Offset.zero & size;
        if (_exactClip) {
          _shaderClipRRectLayerHandle.layer = null;
          _shaderClipPathLayerHandle.layer = context.pushClipPath(
            needsCompositing,
            offset,
            Offset.zero & size,
            _outlinePath(Offset.zero & size),
            _pushShaderLayer,
            oldLayer: _shaderClipPathLayerHandle.layer,
          );
        } else {
          _shaderClipPathLayerHandle.layer = null;
          _shaderClipRRectLayerHandle.layer = context.pushClipRRect(
            needsCompositing,
            offset,
            Offset.zero & size,
            _outlineRRect(Offset.zero & size),
            _pushShaderLayer,
            oldLayer: _shaderClipRRectLayerHandle.layer,
          );
        }
    }

    // Child on top of the glass.
    super.paint(context, offset);
  }

  /// Batched Impeller pass: **one** backdrop for this lens, tagged with the
  /// batch's shared key, so the engine reads the backdrop once for the whole
  /// batch instead of once (twice, with blur) per member.
  ///
  /// The blur cannot stay a pass of its own here. Stacked backdrops chain —
  /// the shader reads what the blur below it wrote — but members of a batch
  /// all read the SAME copy, taken before any of them painted, so a shader
  /// sharing the batch's key would never see its own blur. It goes inside the
  /// single pass instead, as `compose(outer: shader, inner: blur)`: the engine
  /// blurs the shared copy and hands the result to the shader, which is the
  /// same chain in one read.
  ///
  /// That costs a coordinate frame. Composing bounds the shader's input to
  /// this pass's clip, so `FlutterFragCoord()` starts at the clip's top-left
  /// rather than the screen's, and [_packImpellerMainUniforms] packs the
  /// geometry clip-local whenever [_batchClip] is set. The clip is widened to
  /// match: a Gaussian reads `3 * sigma` past every pixel it writes, and past
  /// the clip there is nothing to read but the edge, repeated.
  void _paintImpellerBatched(PaintingContext context, Offset offset) {
    _blurLayerHandle.layer = null;
    _clipLayerHandle.layer = null;
    _clipPathLayerHandle.layer = null;
    _shaderClipRRectLayerHandle.layer = null;
    _shaderClipPathLayerHandle.layer = null;

    if (!_useBlur) {
      // No blur, no compose: the plain shader filter samples the full-screen
      // backdrop, so the frame stays screen-space and the clip stays tight.
      _batchClip = null;
      _pushShaderPass(
          context, offset, _snappedShaderClip(_shaderClipPad, _shaderClipPad));
      super.paint(context, offset);
      return;
    }

    // Room for everything that reaches past the lens box: the Gaussian tail,
    // the refraction band the shader samples across, and the rim.
    final double reach = _refraction.effectiveDistortionWidth +
        _fullBorderWidth +
        _shaderClipPad;
    final Rect clip = _snappedShaderClip(
      3.0 * _appearance.blur.sigmaX + reach,
      3.0 * _appearance.blur.sigmaY + reach,
    );
    _batchClip = clip;
    _pushShaderPass(context, offset, clip);

    // Child on top of the glass.
    super.paint(context, offset);
  }

  /// The shader pass's clip: the lens box padded by [padX] / [padY], snapped
  /// outward to whole physical pixels.
  ///
  /// Fractional clip bounds are what re-frame the engine's backdrop
  /// intermediates every frame while the lens moves or squashes — the
  /// in-flight content wobble. On the pixel grid the bounds only ever step by
  /// exact texels, which the sharp pass survives, while the shader's
  /// fractional geometry keeps the visible outline sub-pixel smooth.
  Rect _snappedShaderClip(double padX, double padY) {
    final Rect clip = Rect.fromLTRB(
      -padX,
      -padY,
      size.width + padX,
      size.height + padY,
    );
    final s = getTransformTo(null).storage;
    // Snapping is only meaningful when screen space is a pure translation
    // of lens space; under ancestor scale/rotation the padded rect still
    // bounds the (lens-local) shader geometry and is left as-is.
    final bool translationOnly = (s[0] - 1).abs() < 1e-4 &&
        s[4].abs() < 1e-4 &&
        s[1].abs() < 1e-4 &&
        (s[5] - 1).abs() < 1e-4;
    if (!translationOnly) return clip;
    final double dpr = _devicePixelRatio;
    final double ox = s[12], oy = s[13];
    return Rect.fromLTRB(
      ((ox + clip.left) * dpr).floorToDouble() / dpr - ox,
      ((oy + clip.top) * dpr).floorToDouble() / dpr - oy,
      ((ox + clip.right) * dpr).ceilToDouble() / dpr - ox,
      ((oy + clip.bottom) * dpr).ceilToDouble() / dpr - oy,
    );
  }

  /// Pushes the backdrop pass inside [clip].
  ///
  /// The shader draws the outline itself (centered edge AA in
  /// computeShapeMask), so the clip is only a BOUND, not the silhouette.
  /// Outside the outline the shader emits zero coverage, so the padding shows
  /// the untouched backdrop and stays invisible.
  void _pushShaderPass(PaintingContext context, Offset offset, Rect clip) {
    _pushedShaderClip = clip;
    _shaderClipRectLayerHandle.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clip,
      _pushShaderLayer,
      oldLayer: _shaderClipRectLayerHandle.layer,
    );
  }

  /// The backdrop pass itself, inside whichever clip the caller pushed.
  /// No uniforms packed here: the layer does that itself at compositing
  /// time, when the frame's transform is final.
  void _pushShaderLayer(PaintingContext context, Offset offset) {
    final shaderLayer =
        _shaderLayerHandle.layer ??= _ImpellerShaderBackdropLayer();
    shaderLayer.renderObject = this;
    context.pushLayer(
        shaderLayer, (PaintingContext context, Offset offset) {}, offset);
  }

  /// What the backdrop pass filters through.
  ///
  /// Plain shader outside a batch (the blur is its own pass below); inside
  /// one, the blur rides along as the composed inner filter so the whole lens
  /// is a single read.
  ui.ImageFilter get _impellerFilter {
    final ui.ImageFilter shaderFilter = ui.ImageFilter.shader(_mainShader);
    if (_batchClip == null) return shaderFilter;
    return ui.ImageFilter.compose(
      outer: shaderFilter,
      // Sigma is LOGICAL px here, like every other blur the package hands the
      // engine — scaling it by dpr would over-blur by that factor.
      inner: ui.ImageFilter.blur(
        sigmaX: _appearance.blur.sigmaX,
        sigmaY: _appearance.blur.sigmaY,
      ),
    );
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
    final Matrix4 toView = getTransformTo(viewBox);
    // Column-major storage: [0]=a, [4]=b, [1]=c, [5]=d.
    final s = toView.storage;
    final Offset lensPosInView =
        MatrixUtils.transformPoint(toView, Offset.zero);
    final Size viewSize = viewBox.size;
    final bool useBlur = _useBlur;

    // Ancestor scale/rotation? Then no canvas translation can put the
    // draw's local space onto the view's — the lens is turned inside it,
    // and a shader reading its fragments as view pixels samples the
    // capture somewhere else entirely. So the geometry stays LENS-local
    // (the space the canvas draws in anyway) and the shader maps the
    // refracted sample forward through this lens→view map. Translation
    // only keeps the legacy view-space uniforms bit-identical.
    final bool linearXform = (s[0] - 1).abs() > 1e-4 ||
        s[4].abs() > 1e-4 ||
        s[1].abs() > 1e-4 ||
        (s[5] - 1).abs() > 1e-4;
    // Where the shape sits in the space the shader evaluates: at the
    // lens's own origin when transformed, at its view position otherwise.
    final Offset shaderOrigin = linearXform ? Offset.zero : lensPosInView;

    _packUniforms(
      _mainShader,
      resolution: viewSize,
      lensPosition: shaderOrigin,
      scale: 1.0,
      // Blur path: suppress the main-pass border; a sharp border pass
      // is drawn on top of the blur below (mirrors the legacy painter).
      borderWidth: useBlur ? 0.0 : _fullBorderWidth,
      includeLensColor: true,
      honorBackdropAlpha: _honorBackdropAlpha,
      xformA: linearXform ? s[0] : 1,
      xformB: linearXform ? s[4] : 0,
      xformC: linearXform ? s[1] : 0,
      xformD: linearXform ? s[5] : 1,
      xformOffset: linearXform ? lensPosInView : Offset.zero,
    );
    _mainShader.setImageSampler(0, image);

    final Rect shaderRect = shaderOrigin & size;
    final RRect shaderRRect = _outlineRRect(shaderRect);
    final Path? shaderPath = _exactClip ? _outlinePath(shaderRect) : null;

    final ui.Canvas canvas = context.canvas;
    canvas
      ..save()
      ..translate(offset.dx - shaderOrigin.dx, offset.dy - shaderOrigin.dy);
    if (shaderPath != null) {
      canvas
        ..clipPath(shaderPath)
        ..drawPath(shaderPath, Paint()..shader = _mainShader);
    } else {
      canvas
        ..clipRRect(shaderRRect)
        ..drawRRect(shaderRRect, Paint()..shader = _mainShader);
    }
    canvas.restore();

    if (useBlur && liquidGlassUsesRoundedClip(_shape)) {
      // Backdrop blur above the refraction, clipped to the lens shape.
      void paintBlur(PaintingContext context, Offset offset) {
        final blurLayer = _blurLayerHandle.layer ??= BackdropFilterLayer();
        blurLayer.filter = ui.ImageFilter.blur(
          sigmaX: _appearance.blur.sigmaX,
          sigmaY: _appearance.blur.sigmaY,
        );
        context.pushLayer(
            blurLayer, (PaintingContext context, Offset offset) {}, offset);
      }

      if (_exactClip) {
        _skiaBlurClipLayerHandle.layer = null;
        _skiaBlurClipPathLayerHandle.layer = context.pushClipPath(
          needsCompositing,
          offset,
          Offset.zero & size,
          _outlinePath(Offset.zero & size),
          paintBlur,
          oldLayer: _skiaBlurClipPathLayerHandle.layer,
        );
      } else {
        _skiaBlurClipPathLayerHandle.layer = null;
        _skiaBlurClipLayerHandle.layer = context.pushClipRRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          _outlineRRect(Offset.zero & size),
          paintBlur,
          oldLayer: _skiaBlurClipLayerHandle.layer,
        );
      }

      // Sharp border pass on top of the blur.
      final ui.FragmentShader? borderShader = _borderShader;
      if (borderShader != null) {
        _packUniforms(
          borderShader,
          resolution: viewSize,
          lensPosition: shaderOrigin,
          scale: 1.0,
          borderWidth: _fullBorderWidth,
          includeLensColor: false,
          honorBackdropAlpha: _honorBackdropAlpha,
          // Same space as the main pass, so the rim hugs the same outline
          // and reads the backdrop from the same place.
          xformA: linearXform ? s[0] : 1,
          xformB: linearXform ? s[4] : 0,
          xformC: linearXform ? s[1] : 0,
          xformD: linearXform ? s[5] : 1,
          xformOffset: linearXform ? lensPosInView : Offset.zero,
        );
        borderShader.setImageSampler(0, image);
        final ui.Canvas borderCanvas = context.canvas;
        borderCanvas
          ..save()
          ..translate(offset.dx - shaderOrigin.dx, offset.dy - shaderOrigin.dy)
          ..drawPath(shaderPath ?? (Path()..addRRect(shaderRRect)),
              Paint()..shader = borderShader)
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
