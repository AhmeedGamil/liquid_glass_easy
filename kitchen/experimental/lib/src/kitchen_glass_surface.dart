import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'kitchen_glass_params.dart';

/// Asset key of the experimental shader, as bundled from this package.
const String kKitchenGlassShaderAsset =
    'packages/kitchen_glass_lab/shaders/kitchen_liquid_glass.frag';

/// Loads the experimental glass shader once and hands out its instance.
Future<ui.FragmentShader> loadKitchenGlassShader() async {
  final ui.FragmentProgram program =
      await ui.FragmentProgram.fromAsset(kKitchenGlassShaderAsset);
  return program.fragmentShader();
}

/// True when the engine can run a fragment shader as an image filter, which is
/// what feeds the live backdrop to the glass. False on Skia and on the web.
bool get kitchenGlassSupported => ui.ImageFilter.isShaderFilterSupported;

/// One lobe of the merged glass surface.
@immutable
class KitchenGlassLobe {
  const KitchenGlassLobe(this.rect);

  /// Position and size in the surface's own coordinate space, logical px.
  final Rect rect;

  @override
  bool operator ==(Object other) =>
      other is KitchenGlassLobe && other.rect == rect;

  @override
  int get hashCode => rect.hashCode;
}

/// Paints up to four fused glass lobes over whatever is already on screen.
///
/// The pass is a `BackdropFilter` carrying `ImageFilter.shader`, so the shader
/// reads the live backdrop directly — nothing is captured, and nothing needs a
/// background widget. That path exists on Impeller only; check
/// [kitchenGlassSupported] before mounting this.
class KitchenGlassSurface extends SingleChildRenderObjectWidget {
  const KitchenGlassSurface({
    super.key,
    required this.shader,
    required this.lobes,
    required this.params,
    super.child,
  });

  final ui.FragmentShader shader;

  /// Up to four lobes. Extra entries are ignored: the shader carries exactly
  /// four rect uniforms because Flutter's runtime effects have no arrays.
  final List<KitchenGlassLobe> lobes;

  final KitchenGlassParams params;

  /// Hard cap on fused lobes, set by the shader's uniform count.
  static const int maxLobes = 4;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final ui.FlutterView view = View.of(context);
    return RenderKitchenGlass(
      shader: shader,
      lobes: lobes,
      params: params,
      devicePixelRatio: view.devicePixelRatio,
      screenSize: view.physicalSize,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderKitchenGlass renderObject) {
    final ui.FlutterView view = View.of(context);
    renderObject
      ..shader = shader
      ..lobes = lobes
      ..params = params
      ..devicePixelRatio = view.devicePixelRatio
      ..screenSize = view.physicalSize;
  }
}

/// Render object behind [KitchenGlassSurface].
///
/// Uniforms are packed at paint time in **screen physical pixels**, because
/// `FlutterFragCoord()` under `ImageFilter.shader` is exactly that. The lobes
/// are dragged, so paint runs on every change and there is no stale-transform
/// problem to solve here.
class RenderKitchenGlass extends RenderProxyBox {
  RenderKitchenGlass({
    required ui.FragmentShader shader,
    required List<KitchenGlassLobe> lobes,
    required KitchenGlassParams params,
    required double devicePixelRatio,
    required Size screenSize,
  })  : _shader = shader,
        _lobes = lobes,
        _params = params,
        _devicePixelRatio = devicePixelRatio,
        _screenSize = screenSize;

  ui.FragmentShader _shader;
  set shader(ui.FragmentShader value) {
    if (identical(_shader, value)) return;
    _shader = value;
    markNeedsPaint();
  }

  List<KitchenGlassLobe> _lobes;
  set lobes(List<KitchenGlassLobe> value) {
    if (listEquals(_lobes, value)) return;
    _lobes = value;
    markNeedsPaint();
  }

  KitchenGlassParams _params;
  set params(KitchenGlassParams value) {
    if (_params == value) return;
    _params = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  Size _screenSize;
  set screenSize(Size value) {
    if (_screenSize == value) return;
    _screenSize = value;
    markNeedsPaint();
  }

  final LayerHandle<BackdropFilterLayer> _glassLayer =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void dispose() {
    _glassLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }

  /// Active lobes, clipped to what the shader can hold.
  List<Rect> get _activeLobes {
    final List<Rect> out = <Rect>[];
    for (final KitchenGlassLobe lobe in _lobes) {
      if (lobe.rect.width <= 0 || lobe.rect.height <= 0) continue;
      out.add(lobe.rect);
      if (out.length == KitchenGlassSurface.maxLobes) break;
    }
    return out;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final List<Rect> lobes = _activeLobes;
    if (lobes.isEmpty) {
      _glassLayer.layer = null;
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }

    // Lobe geometry has to be global: the shader sees screen-space fragments.
    final Offset origin =
        MatrixUtils.transformPoint(getTransformTo(null), Offset.zero);

    Rect union = lobes.first;
    for (final Rect r in lobes.skip(1)) {
      union = union.expandToInclude(r);
    }

    _packUniforms(lobes, origin, union.center + origin);

    // The smooth union bows the surface outward between lobes, so the pass has
    // to reach past the plain bounding box before the silhouette is cut.
    final double pad = _params.mergeSmoothness + _params.blur + 4;
    final Rect clip = union.inflate(pad).intersect(Offset.zero & size);
    if (clip.isEmpty) {
      _glassLayer.layer = null;
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }

    final BackdropFilterLayer layer =
        _glassLayer.layer ??= BackdropFilterLayer();
    layer.filter = ui.ImageFilter.shader(_shader);

    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clip,
      (PaintingContext inner, Offset innerOffset) {
        inner.pushLayer(
          layer,
          (PaintingContext _, Offset __) {},
          innerOffset,
        );
      },
      oldLayer: _clipLayer.layer,
    );

    super.paint(context, offset);
  }

  /// Writes the 13 vec4 uniform slots in declaration order.
  void _packUniforms(List<Rect> lobes, Offset origin, Offset blobCentre) {
    final double dpr = _devicePixelRatio;
    final ui.FragmentShader s = _shader;
    int i = 0;
    void put(double v) => s.setFloat(i++, v);

    // uFrame: backdrop size px, blob centre px.
    put(_screenSize.width);
    put(_screenSize.height);
    put(blobCentre.dx * dpr);
    put(blobCentre.dy * dpr);

    // uRect0..3: global top-left and size, physical px. Unused slots are zero
    // sized, which the count uniform already excludes from the union.
    for (int slot = 0; slot < KitchenGlassSurface.maxLobes; slot++) {
      if (slot < lobes.length) {
        final Rect r = lobes[slot].shift(origin);
        put(r.left * dpr);
        put(r.top * dpr);
        put(r.width * dpr);
        put(r.height * dpr);
      } else {
        put(0);
        put(0);
        put(0);
        put(0);
      }
    }

    // uShapeA
    put(lobes.length.toDouble());
    put(_params.cornerRadius * dpr);
    put(_params.cornerExponent);
    put(_params.mergeSmoothness * dpr);

    // uTint
    put(_params.tint.r);
    put(_params.tint.g);
    put(_params.tint.b);
    put(_params.tint.a);

    // uGlassA
    put(_params.thickness);
    put(_params.refractiveIndex);
    put(_params.dispersion);
    put(_params.magnification);

    // uFresnel
    put(_params.fresnelRange);
    put(_params.fresnelIntensity);
    put(_params.fresnelSharpness);
    put(_params.edgeGain);

    // uGlareA
    put(_params.glareRange);
    put(_params.glareConvergence);
    put(_params.glareOppositeBias);
    put(_params.glareIntensity);

    // uGlareB
    put(_params.glareSharpness);
    put(_params.glareAngleOffset);
    put(_params.blur * dpr);
    put(dpr);

    // uImage: the backdrop snapshot is the whole frame under a plain shader
    // filter, so the sampling window starts at the origin.
    put(0);
    put(0);
    put(_screenSize.width);
    put(_screenSize.height);

    // uMisc
    put(dpr);
    put(_params.debugMode);
    put(0);
    put(0);
  }
}
