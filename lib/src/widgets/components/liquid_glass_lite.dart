import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/liquid_glass_light.dart';
import '../utils/liquid_glass_shape.dart';

/// Glass **without the shader**: a frosted surface with the lens' own rim
/// light, drawn from plain canvas geometry.
///
/// A [LiquidGlassLens] gets its look from the glass shader: every pixel
/// measures its own distance to the shape's SDF, reads the background under
/// it, bends it, and lights itself. That is what makes the rim feel like an
/// optical consequence of the glass — and it is also why it costs a
/// `FragmentProgram`, a program warm-up, and (on Impeller) a slot in the lens
/// budget.
///
/// This is the light version of that. It gives up refraction, which is the
/// half that needs a shader, and keeps the half that does not: the frost,
/// the tint, and the rim.
///
/// The rim is a lens' specular, evaluated on the Dart side: the outline is
/// sampled into a ring of points, each point's outward normal is run through
/// the shader's own formulas — the same ramp across the edge, the same pair
/// of arcs on the light's axis — and the result is a few `drawVertices` calls
/// per light. [blur] is the glass itself; the rim is its edge. No shader
/// asset, no `FragmentProgram`, nothing to warm up.
///
/// ```dart
/// LiquidGlassLite(
///   shape: const LiquidGlassShape(
///     cornerRadius: 22,
///   ),
///   specular: const LiquidGlassLight.specular(angle: 90),
///   child: const Text('on the glass'),
/// )
/// ```
///
/// It takes the ordinary [LiquidGlassShape] and the lens' two lights: the
/// [specular], and the [glow] under it, each drawing the same band here as
/// it does on a lens. Neither light reads the backdrop, so a glow costs
/// nothing but its own mesh. The silhouette comes from the same
/// outline a lens clips to, so all three corner styles — circular, squircle,
/// and the continuous capsule corner — are reproduced exactly.
///
/// ## A painted rim
///
/// The rim is painted **last**, over the frost, the [color] and the [child],
/// and reads nothing back. Each light is blended into the finished surface
/// with `overlay`, so it brightens whatever it lies over and keeps that
/// colour: red where the surface is red, blue where it is blue. A plain white
/// floor is screened over the blend so the rim still shows over black, where
/// `overlay` has nothing to lift. A light's own `color` is multiplied in after
/// that, so a grey light is a grey rim.
///
/// Because it reads nothing, the rim holds up wherever a backdrop read does
/// not: through page transitions, under the overscroll stretch, inside any
/// layer that moves.
///
/// There is no refraction — no edge bend. [magnification] is the flat-slab
/// half only; the rim itself does not shift with the content behind it the
/// way glass does.
///
/// ## It is an inner border
///
/// The rim is clipped to the outline, like a lens clips its shader, so it is
/// drawn strictly INSIDE the box — brightest against the edge and falling away
/// inward, never hanging past it. Give the widget the size of the surface the
/// border belongs to, not a box around it.
///
/// ## When to reach for it
///
/// For a surface that is *not* a lens — a card, a list row, a sheet, a focus
/// ring — and for the many-of-them cases where real lenses would be too
/// expensive: long lists, low-end devices, the web.
///
/// The frost is its only backdrop read. `blur: 0` at a [magnification] of `1`
/// drops that read too, and the surface reads nothing at all.
class LiquidGlassLite extends StatelessWidget {
  /// Creates a shader-free sheet of glass behind [child].
  const LiquidGlassLite({
    super.key,
    this.shape = const LiquidGlassShape(),
    this.specular,
    this.glow,
    this.borderAlpha = 1.0,
    this.blur = 3.0,
    this.magnification = 1.0,
    this.color,
    this.shapeScale = const Offset(1.0, 1.0),
    this.child,
  });

  /// The outline to draw, read exactly as a lens reads it.
  final LiquidGlassShape shape;

  /// The rim's highlight; `null` is `LiquidGlassLight.specular()`. It is read
  /// as a lens reads its specular: thickness, sharpness, angle, spread,
  /// intensity and colour.
  final LiquidGlassLight? specular;

  /// The rim's soft side light, drawn under the [specular] and read as a
  /// lens reads its glow: thickness, angle, spread, intensity and colour.
  /// `null` draws none.
  final LiquidGlassLight? glow;

  /// The outline with its lights, as the painters read it.
  LiquidGlassLitShape get _lit =>
      LiquidGlassLitShape.of(shape, specular: specular, glow: glow);

  /// How much the surface frosts what is behind it, inside its own outline.
  ///
  /// This is the glass itself rather than its edge: a backdrop blur clipped to
  /// the shape, painted under [child], the same thing a lens' own blur
  /// does. A Gaussian sigma; `3` by default, and `0` is a bare rim over
  /// whatever is already there.
  ///
  /// It costs one backdrop read, the surface's only one, so a screen with
  /// many of them wants `0` here.
  final double blur;

  /// How much the surface magnifies what is behind it: the backdrop scaled
  /// about the shape's centre, evenly, across the whole surface. This is the
  /// flat-slab half of a lens' refraction — the content inside the outline
  /// stops lining up with the content outside it. It rides in the [blur]'s
  /// own filter, so it is free when blur is on. `1.0` is flat.
  final double magnification;

  /// The glass's own tint, `LiquidGlassStyle.color`'s counterpart: a
  /// flat fill of the shape between the frost and [child].
  ///
  /// The rim is painted over it and blends into it. `null`, or fully
  /// transparent, paints nothing.
  final Color? color;

  /// A global multiplier on the rim's opacity, for fading it in and out. The
  /// lens uses the same knob for its own show/hide animation.
  final double borderAlpha;

  /// The deformation applied to the outline, matching a lens' shape scale: the
  /// shape is built at rest size and stretched, so a squeezed circle becomes an
  /// ellipse instead of keeping a fixed corner radius.
  final Offset shapeScale;

  /// The content the rim is drawn over: the rim is painted on top of it.
  /// When null the widget expands to its constraints and draws the rim alone.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double zoom = magnification;
    final bool frosted = blur > 0.0 || (zoom != 1.0 && zoom > 0.0);
    final Color? tint = (color?.a ?? 0.0) > 0.0 ? color : null;
    // A light that draws nothing has nothing to read.
    final bool rim = borderAlpha > 0.0 && _rimPeakOf(_lit) > 0.0;

    if (!_kRimFromBackdrop) {
      // The surface rim: the tint is a plain fill, and the rim is painted
      // last, over the content, blended into frost, tint and child alike.
      final Widget content = child ?? const SizedBox.expand();
      return Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          if (frosted) Positioned.fill(child: IgnorePointer(child: _frost())),
          if (tint != null)
            Positioned.fill(child: IgnorePointer(child: _fill(tint))),
          if (rim)
            CustomPaint(
              foregroundPainter: _SurfaceRimPainter(
                shape: _lit,
                borderAlpha: borderAlpha,
                shapeScale: shapeScale,
              ),
              child: content,
            )
          else
            content,
        ],
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        // The glass, under everything.
        if (frosted) Positioned.fill(child: IgnorePointer(child: _frost())),
        // The rim goes on over the frost and under all else, and carries the
        // tint beneath itself so the tint is never in its read. Above the
        // frost, so it reads the frosted surface and its colour runs smooth
        // along the edge instead of picking up every speck behind it.
        if (rim)
          Positioned.fill(child: IgnorePointer(child: _rimPickup(tint)))
        else if (tint != null)
          Positioned.fill(child: IgnorePointer(child: _fill(tint))),
        child ?? const SizedBox.expand(),
      ],
    );
  }

  /// A flat fill of [tint], cut to the outline like the frost is.
  Widget _fill(Color tint) => liquidGlassClip(
        shape: _lit,
        shapeScale: shapeScale,
        child: ColoredBox(color: tint),
      );

  /// The glass itself: the backdrop, magnified and blurred, cut to the
  /// outline. Both go through one filter, so they share one read.
  Widget _frost() => liquidGlassClip(
        shape: _lit,
        shapeScale: shapeScale,
        child: _GlassBackdrop(
          blur: blur,
          magnification: magnification,
          child: const SizedBox.expand(),
        ),
      );

  /// The backdrop read, masked to the rim. [under] is laid beneath the rim in
  /// the same layer, so it lands over the frost without entering the read.
  Widget _rimPickup(Color? under) => ClipRect(
        child: BackdropFilter(
          filter: _highlightFilter(_rimPeakOf(_lit), under),
          child: CustomPaint(
            painter: _RimMaskPainter(
              shape: _lit,
              borderAlpha: borderAlpha,
              shapeScale: shapeScale,
              under: under,
            ),
          ),
        ),
      );
}

/// The backdrop, magnified and blurred in one filter.
///
/// This is a render object rather than a plain [BackdropFilter] for one
/// reason: a backdrop matrix runs in the **enclosing layer's** coordinates,
/// not the filtered box's own. Scaling about `(0, 0)` would slide the whole
/// background across the screen instead of magnifying it in place, so the
/// transform has to be built around this box's centre as it lands at paint
/// time — which only the render object knows.
class _GlassBackdrop extends SingleChildRenderObjectWidget {
  const _GlassBackdrop({
    required this.blur,
    required this.magnification,
    required Widget super.child,
  });

  final double blur;
  final double magnification;

  @override
  _RenderGlassBackdrop createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(
        blur: blur,
        magnification: magnification,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassBackdrop renderObject,
  ) {
    renderObject
      ..blur = blur
      ..magnification = magnification;
  }
}

class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop({
    required double blur,
    required double magnification,
  })  : _blur = blur,
        _magnification = magnification;

  double _blur;
  set blur(double value) {
    if (_blur == value) return;
    _blur = value;
    markNeedsPaint();
  }

  double _magnification;
  set magnification(double value) {
    if (_magnification == value) return;
    _magnification = value;
    markNeedsPaint();
  }

  final LayerHandle<BackdropFilterLayer> _handle =
      LayerHandle<BackdropFilterLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final ui.ImageFilter? filter = _filterAt(offset);
    if (filter == null) {
      _handle.layer = null;
      super.paint(context, offset);
      return;
    }
    final BackdropFilterLayer layer = _handle.layer ??= BackdropFilterLayer();
    layer.filter = filter;
    context.pushLayer(layer, super.paint, offset);
  }

  ui.ImageFilter? _filterAt(Offset offset) {
    final bool blurs = _blur > 0.0;
    final double z = _magnification;
    final bool bends = z != 1.0 && z > 0.0;
    if (!blurs && !bends) return null;

    final ui.ImageFilter? blur =
        blurs ? ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur) : null;
    if (!bends) return blur;

    // Scale about this box's centre, written straight into the matrix rather
    // than composed from translate/scale calls, so it stays on the API every
    // supported SDK has.
    final double cx = offset.dx + size.width / 2;
    final double cy = offset.dy + size.height / 2;
    final ui.ImageFilter zoom = ui.ImageFilter.matrix(
      Matrix4(
        z, 0, 0, 0, //
        0, z, 0, 0, //
        0, 0, 1, 0, //
        (1 - z) * cx, (1 - z) * cy, 0, 1, //
      ).storage,
      filterQuality: FilterQuality.low,
    );
    return blur == null
        ? zoom
        : ui.ImageFilter.compose(outer: blur, inner: zoom);
  }

  @override
  void dispose() {
    _handle.layer = null;
    super.dispose();
  }
}

/// The rim's lift as a colour matrix, at the rim's [peak] strength: the
/// background mixed with the rim's share of [tint], its chroma stretched and
/// the peak's lightness added. The mask's alpha scales that down to each
/// pixel's own strength.
ColorFilter _highlightFilter(double peak, Color? tint) {
  final double lift = _kRimLift * peak;
  // A matrix scales chroma where the shader adds to it; the two agree on a
  // colour of middling saturation.
  final double s = 1.0 + _kRimChroma * peak / 0.25;
  final double d = 1.0 - s;
  final double share = (tint?.a ?? 0.0).clamp(0.0, 1.0) * _kRimTintShare;
  final double keep = 1.0 - share;
  final double tintLuma = tint == null
      ? 0.0
      : tint.r * _kLumaR + tint.g * _kLumaG + tint.b * _kLumaB;
  double cell(double luma, {required bool own}) =>
      keep * (luma * d + (own ? s : 0.0));
  double offset(double channel) =>
      255.0 * (share * (tintLuma * d + channel * s) + lift);
  return ColorFilter.matrix(<double>[
    cell(_kLumaR, own: true), cell(_kLumaG, own: false),
    cell(_kLumaB, own: false), 0, offset(tint?.r ?? 0.0), //
    cell(_kLumaR, own: false), cell(_kLumaG, own: true),
    cell(_kLumaB, own: false), 0, offset(tint?.g ?? 0.0), //
    cell(_kLumaR, own: false), cell(_kLumaG, own: false),
    cell(_kLumaB, own: true), 0, offset(tint?.b ?? 0.0), //
    0, 0, 0, 1, 0, //
  ]);
}

/// Cuts everything but the rim out of the layer it paints into.
///
/// Drawn inside a backdrop filter, whose layer starts out holding the filtered
/// background: an inner layer composited with `modulate` keeps that background
/// exactly where the rim mesh has alpha, scaled by the mesh's colour, and
/// clears it everywhere else.
class _RimMaskPainter extends CustomPainter {
  const _RimMaskPainter({
    required this.shape,
    required this.borderAlpha,
    required this.shapeScale,
    this.under,
  });

  final LiquidGlassLitShape shape;
  final double borderAlpha;
  final Offset shapeScale;

  /// A fill of the shape laid UNDER the rim once it is cut — `dstOver` into
  /// the layer the rim was just left alone in — so the glass's tint ends up
  /// below the rim yet was never part of what the rim read.
  final Color? under;

  @override
  void paint(Canvas canvas, Size size) {
    // The layer has to span everything the filter painted, or whatever falls
    // outside these bounds keeps the background unmasked. `modulate` keeps
    // the lifted background where the mesh has alpha, at the mesh's alpha.
    canvas.saveLayer(
        Offset.zero & size, Paint()..blendMode = BlendMode.modulate);
    final _RimOutline? outline = _outlineFor(shape, size, shapeScale);
    // Both lights share the one read, lifted to the brighter one's peak.
    final double peak = _rimPeakOf(shape);
    final List<_RimLayer> layers = _rimLayers(shape);
    if (outline != null) {
      canvas.clipPath(outline.path);
      // The glow first, the specular over it, as the shader stacks them.
      for (final _RimLayer layer in layers) {
        final ui.Vertices? mesh = _buildRimMesh(
          outline: outline,
          layer: layer,
          peak: peak,
          size: size,
          borderAlpha: borderAlpha,
          role: _RimRole.pickup,
        );
        if (mesh != null) {
          canvas.drawVertices(mesh, BlendMode.modulate, _rimPaint);
        }
      }
    }
    canvas.restore();
    if (outline == null) return;

    canvas.save();
    canvas.clipPath(outline.path);
    // A light's own colour replaces the lifted one, by its alpha.
    for (final _RimLayer layer in layers) {
      final ui.Vertices? light = _buildRimMesh(
        outline: outline,
        layer: layer,
        peak: peak,
        size: size,
        borderAlpha: borderAlpha,
        role: _RimRole.light,
      );
      if (light != null) {
        canvas.drawVertices(light, BlendMode.modulate, _rimPaint);
      }
    }
    final Color? fill = under;
    if (fill != null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = fill
          ..blendMode = BlendMode.dstOver,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RimMaskPainter oldDelegate) =>
      oldDelegate.borderAlpha != borderAlpha ||
      oldDelegate.shapeScale != shapeScale ||
      oldDelegate.under != under ||
      !_sameBorderLook(oldDelegate.shape, shape);
}

final Paint _rimPaint = Paint()..color = const Color(0xFFFFFFFF);

/// Whether the rim is cut out of a backdrop read (`true`) or painted over the
/// finished surface (`false`, the surface rim, which reads nothing).
const bool _kRimFromBackdrop = false;

/// How much plain white rim the surface rim screens over its blend, so it does
/// not vanish over black, where `overlay` has nothing to multiply.
const double _kSurfaceRimFloor = 0.8;

/// Paints the surface rim over everything already in the canvas: the light
/// blended in with `overlay`, a plain white floor screened over that, then the
/// light's own colour multiplied in. Nothing is read back.
class _SurfaceRimPainter extends CustomPainter {
  const _SurfaceRimPainter({
    required this.shape,
    required this.borderAlpha,
    required this.shapeScale,
  });

  final LiquidGlassLitShape shape;
  final double borderAlpha;
  final Offset shapeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final _RimOutline? outline = _outlineFor(shape, size, shapeScale);
    if (outline == null) return;
    final double peak = _rimPeakOf(shape);
    canvas.save();
    canvas.clipPath(outline.path);
    // The glow first, the specular over it, as the shader stacks them.
    for (final _RimLayer layer in _rimLayers(shape)) {
      final ui.Vertices? mesh = _buildRimMesh(
        outline: outline,
        layer: layer,
        peak: peak,
        size: size,
        borderAlpha: borderAlpha,
        role: _RimRole.surface,
      );
      if (mesh == null) continue;
      canvas.drawVertices(
        mesh,
        BlendMode.modulate,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..blendMode = BlendMode.overlay,
      );
      canvas.drawVertices(
        mesh,
        BlendMode.modulate,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, _kSurfaceRimFloor)
          ..blendMode = BlendMode.screen,
      );
      final Color? own = layer.light.color;
      if (own != null && own.toARGB32() | 0xFF000000 != 0xFFFFFFFF) {
        canvas.drawVertices(
          mesh,
          BlendMode.modulate,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..blendMode = BlendMode.multiply,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SurfaceRimPainter oldDelegate) =>
      oldDelegate.borderAlpha != borderAlpha ||
      oldDelegate.shapeScale != shapeScale ||
      !_sameBorderLook(oldDelegate.shape, shape);
}

/// Whether two shapes would draw the same rim: the specular and the glow
/// are the lights drawn here.
bool _sameBorderLook(LiquidGlassLitShape a, LiquidGlassLitShape b) {
  if (identical(a, b)) return true;
  return a.cornerStyle == b.cornerStyle &&
      a.cornerRadius == b.cornerRadius &&
      a.specular == b.specular &&
      a.glow == b.glow;
}

// ─────────────────────────────────────────────────────────────
//  The mesh
// ─────────────────────────────────────────────────────────────

/// Arc-length spacing between outline samples, in logical px.
const double _kSampleStepPx = 1.5;

/// Sample bounds per contour: enough that a small corner still reads as round,
/// few enough that a full-screen sheet is still a small mesh.
const int _kMinSamples = 32;
const int _kMaxSamples = 1024;

/// How many sampled outlines to keep. Sampling walks the path metrics, so an
/// animating — or merely repainting — rim should hit this every frame.
const int _kOutlineCacheSize = 8;

/// Rec. 709 luma, as the shader's border uses it.
const double _kLumaR = 0.2126;
const double _kLumaG = 0.7152;
const double _kLumaB = 0.0722;

/// Builds the rim as one indexed triangle mesh, or null when there is nothing
/// to draw.
///
/// The mesh is a set of concentric rings, offset along the outline's normals.
/// Around a ring the vertex alpha carries the light's arc; across the rings
/// it carries the rim's ramp. Both come from the shader's own formulas. The
/// innermost ring is where the ramp reaches zero, and the outermost sits past
/// the outline, where the caller's clip cuts it — so the mesh never shows an
/// edge of its own, which `drawVertices` could not anti-alias.
ui.Vertices? _buildRimMesh({
  required _RimOutline outline,
  required _RimLayer layer,
  required double peak,
  required Size size,
  required double borderAlpha,
  required _RimRole role,
}) {
  if (borderAlpha <= 0.0 || peak <= 0.0) return null;
  if (!size.width.isFinite || !size.height.isFinite) return null;
  if (size.width <= 0.0 || size.height <= 0.0) return null;
  final LiquidGlassLight light = layer.light;
  if (light.thickness <= 0.0 || light.intensity <= 0.0) return null;

  // How much of the rim is the light's own colour instead of a lifted one.
  final Color? lightColor = light.color;
  final double own = lightColor == null ? 0.0 : lightColor.a.clamp(0.0, 1.0);
  if (role == _RimRole.pickup && own >= 1.0) return null;
  if (role == _RimRole.light && own <= 0.0) return null;

  // The ramp's depth follows the thickness; the layer's shift slides it.
  final double depth = light.thickness;
  final double shift = layer.shift;

  // Offsetting inward past the shape's inradius would fold the inner rings
  // through each other, so the rim's reach is capped short of it.
  final double maxInward = 0.45 * math.min(size.width, size.height);
  final List<double> rings = _rimRings(depth, shift);
  final int ringCount = rings.length;
  final List<double> ramp = <double>[
    for (final double sd in rings) _rimRamp(sd, depth, shift),
  ];

  final double lightRad = light.angle * math.pi / 180.0;
  final double lx = math.cos(lightRad);
  final double ly = math.sin(lightRad);
  final double arcGain = 1.2 * light.intensity * _kRimIntensityScale;
  final double arcPower = _rimArcPower(light.spread);
  final double alphaScale = borderAlpha.clamp(0.0, 1.0);

  final int rgb = switch (role) {
    _RimRole.pickup => 0x00ffffff,
    _RimRole.light => _packRgb(lightColor!.r, lightColor.g, lightColor.b),
    _RimRole.surface => lightColor == null
        ? 0x00ffffff
        : _packRgb(lightColor.r, lightColor.g, lightColor.b),
  };

  int vertexCount = 0;
  int indexCount = 0;
  for (final _RimContour contour in outline.contours) {
    vertexCount += contour.count * ringCount;
    indexCount += contour.count * (ringCount - 1) * 6;
  }
  if (vertexCount == 0) return null;

  final Float32List positions = Float32List(vertexCount * 2);
  final Int32List colors = Int32List(vertexCount);
  final Uint16List indices = Uint16List(indexCount);

  final Float64List sampleArc = Float64List(_kMaxSamples);

  int vi = 0;
  int ii = 0;
  int vBase = 0;

  for (final _RimContour contour in outline.contours) {
    final int m = contour.count;

    // Per-sample arc — the part of the rim that depends on the normal alone:
    // two opposing arcs on the light's axis, dark at 90 degrees to it.
    for (int i = 0; i < m; i++) {
      final double ndl = contour.nx[i] * lx + contour.ny[i] * ly;
      final double back = ndl < 0.0 ? light.oppositeIntensity : 1.0;
      sampleArc[i] = math
          .pow(math.max(ndl * ndl * back * arcGain, 1e-6), arcPower)
          .toDouble()
          .clamp(0.0, 1.0);
    }

    for (int k = 0; k < ringCount; k++) {
      final double sd = math.max(rings[k], -maxInward);
      final double p = ramp[k];
      for (int i = 0; i < m; i++) {
        positions[vi * 2] = contour.px[i] + contour.nx[i] * sd;
        positions[vi * 2 + 1] = contour.py[i] + contour.ny[i] * sd;
        final double strength = sampleArc[i] * p;
        final double weight =
            (strength * layer.weightGain).clamp(0.0, 1.0) * alphaScale;
        final double a = switch (role) {
          _RimRole.light => weight * own,
          // The read is lifted by the peak, so the strength's share of it
          // is the lift; the light's pass over it takes the rest.
          _RimRole.pickup =>
            (1.0 - own) * weight * (strength / peak) / (1.0 - weight * own),
          // The shader's profile: its weight, times the lift its strength
          // gives (1.5 x strength, full white at most).
          _RimRole.surface =>
            weight * (_kRimLift * strength).clamp(0.0, 1.0),
        };
        colors[vi] = ((a.clamp(0.0, 1.0) * 255.0).round() << 24) | rgb;
        vi++;
      }
    }

    // Two triangles per sample between each pair of rings, wrapping closed.
    for (int k = 0; k < ringCount - 1; k++) {
      final int inner = vBase + k * m;
      final int outer = inner + m;
      for (int i = 0; i < m; i++) {
        final int j = i + 1 == m ? 0 : i + 1;
        indices[ii++] = inner + i;
        indices[ii++] = inner + j;
        indices[ii++] = outer + i;
        indices[ii++] = inner + j;
        indices[ii++] = outer + j;
        indices[ii++] = outer + i;
      }
    }
    vBase += m * ringCount;
  }

  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    colors: colors,
    indices: indices,
  );
}

// ─────────────────────────────────────────────────────────────
//  The rim — the shader's specular layer, evaluated per vertex
// ─────────────────────────────────────────────────────────────

/// What a rim mesh is drawn as, which sets what its vertices carry.
enum _RimRole {
  /// The mask a backdrop read is cut by: white, at the lift's share.
  pickup,

  /// The light's own colour, laid over a [pickup] rim.
  light,

  /// The painted surface rim: the light's colour (white when it has none),
  /// shaped across the band as the shader's rim is.
  surface,
}

// How a light's values read inside the rim (thickness is the band depth in
// px as given): intensity 1 and sharpness 0.5 give the rest look. The shader's own constants.
const double _kRimIntensityScale = 0.1; // intensity 1 -> 0.1
const double _kRimShiftAtZero = -0.6; // sharpness 0..1 -> shift -0.6..0.4
const double _kRimWeightGain = 6.0; // strength -> coverage
const double _kRimGlowShift = 0.0; // the glow's ramp is not slid

/// How far inside the outline the rim is measured from, in logical px.
const double _kRimOutlineInset = 0.167;

/// Lightness and chroma the rim adds per unit of strength, in sRGB.
const double _kRimLift = 1.5;
const double _kRimChroma = 30.0 * 0.00724;

/// Share of the tint's alpha the rim's colour takes; the body takes it all,
/// so the rim stays lighter than the body.
const double _kRimTintShare = 0.625;

/// Where the rings sit along the ramp, as fractions of its top. The ramp is
/// a fifth power, so most of them crowd the outline.
const List<double> _kRimRingSteps = <double>[
  0.94,
  0.87,
  0.79,
  0.70,
  0.58,
  0.42,
  0.0,
];

/// Signed distances (positive = outside the shape) of the rim's rings. The
/// first is past the outline, for the clip to cut; the last is where the
/// ramp reaches zero.
List<double> _rimRings(double depth, double shift) {
  double sdAt(double t) => (t - 1.0 - shift) * depth - _kRimOutlineInset;
  final double top = math.min(1.0 + shift + _kRimOutlineInset / depth, 1.0);
  return <double>[
    1.0,
    0.0,
    // Where a sharp ramp stops being full.
    if (sdAt(1.0) < 0.0) sdAt(1.0),
    for (final double f in _kRimRingSteps) sdAt(top * f),
  ];
}

/// The rim's ramp at signed distance [sd]: 1 on the outline, 0 at [depth]
/// inside, slid by [shift]. A fifth power: a hard core with a long, soft
/// inward tail.
double _rimRamp(double sd, double depth, double shift) {
  final double t =
      math.max(1.0 + shift + (sd + _kRimOutlineInset) / depth, 0.0);
  final double t2 = t * t;
  return (t2 * t2 * t).clamp(0.0, 1.0);
}

/// A light's arc power: spread 0 focuses the arcs on the light's axis; 1
/// flattens the power so they wrap the perimeter.
double _rimArcPower(double spread) =>
    0.1 + (1.0 - spread.clamp(0.0, 1.0)) * 2.0;

/// One light of the rim as the mesh draws it: the light, the shift on its
/// ramp, and how its strength turns into coverage.
class _RimLayer {
  const _RimLayer(this.light, this.shift, this.weightGain);

  final LiquidGlassLight light;
  final double shift;
  final double weightGain;
}

/// [shape]'s lights, bottom first: the glow, then the specular. The glow's
/// ramp is unshifted and its weight is 0.7 of the specular's, as in the
/// shader.
List<_RimLayer> _rimLayers(LiquidGlassLitShape shape) => <_RimLayer>[
      _RimLayer(shape.glow, _kRimGlowShift, 0.7 * _kRimWeightGain),
      _RimLayer(
        shape.specular,
        _kRimShiftAtZero + shape.specular.sharpness.clamp(0.0, 1.0),
        _kRimWeightGain,
      ),
    ];

/// The most strength any of [shape]'s lights reaches: the peak the shared
/// read is lifted to. Zero when neither light draws anything.
double _rimPeakOf(LiquidGlassLitShape shape) {
  double peak = 0.0;
  for (final _RimLayer layer in _rimLayers(shape)) {
    peak = math.max(peak, _rimPeak(layer));
  }
  return peak;
}

/// The most strength [layer]'s rim reaches anywhere: on its axis, at the
/// outline. Zero for a light that draws nothing.
double _rimPeak(_RimLayer layer) {
  final LiquidGlassLight light = layer.light;
  if (light.thickness <= 0.0 || light.intensity <= 0.0) return 0.0;
  final double arc = math
      .pow(
          math.max(
              1.2 *
                  light.intensity *
                  math.max(light.oppositeIntensity, 1.0) *
                  _kRimIntensityScale,
              1e-6),
          _rimArcPower(light.spread))
      .toDouble()
      .clamp(0.0, 1.0);
  return arc * _rimRamp(1.0, light.thickness, layer.shift);
}

int _packRgb(double r, double g, double b) =>
    (_channel(r) << 16) | (_channel(g) << 8) | _channel(b);

int _channel(double v) => (v.clamp(0.0, 1.0) * 255.0).round();

// ─────────────────────────────────────────────────────────────
//  Outline sampling
// ─────────────────────────────────────────────────────────────

/// One closed contour of the outline: its points and their outward normals.
class _RimContour {
  _RimContour(this.count)
      : px = Float32List(count),
        py = Float32List(count),
        nx = Float32List(count),
        ny = Float32List(count);

  final int count;
  final Float32List px;
  final Float32List py;
  final Float32List nx;
  final Float32List ny;
}

class _RimOutline {
  const _RimOutline(this.contours, this.path);

  final List<_RimContour> contours;

  /// The silhouette itself, kept so the rim can be clipped to it — the same
  /// curve, so the clip and the mesh cannot disagree at the edge.
  final Path path;
}

class _OutlineKey {
  const _OutlineKey(
    this.cornerStyle,
    this.cornerRadius,
    this.width,
    this.height,
    this.scaleX,
    this.scaleY,
  );

  final LiquidGlassCornerStyle cornerStyle;
  final double cornerRadius;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;

  @override
  bool operator ==(Object other) =>
      other is _OutlineKey &&
      other.cornerStyle == cornerStyle &&
      other.cornerRadius == cornerRadius &&
      other.width == width &&
      other.height == height &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY;

  @override
  int get hashCode =>
      Object.hash(cornerStyle, cornerRadius, width, height, scaleX, scaleY);
}

/// Insertion-ordered, so the first key is the least recently used.
final Map<_OutlineKey, _RimOutline> _outlineCache =
    <_OutlineKey, _RimOutline>{};

_RimOutline? _outlineFor(LiquidGlassLitShape shape, Size size, Offset scale) {
  final _OutlineKey key = _OutlineKey(
    shape.cornerStyle,
    shape.cornerRadius,
    size.width,
    size.height,
    scale.dx,
    scale.dy,
  );
  final _RimOutline? hit = _outlineCache.remove(key);
  if (hit != null) {
    _outlineCache[key] = hit;
    return hit;
  }
  final _RimOutline? built = _sampleOutline(shape, size, scale);
  if (built == null) return null;
  if (_outlineCache.length >= _kOutlineCacheSize) {
    _outlineCache.remove(_outlineCache.keys.first);
  }
  _outlineCache[key] = built;
  return built;
}

/// Walks [shape]'s outline at even arc-length steps and takes each point's
/// outward normal.
///
/// The normals come from a central difference of neighbouring samples, not
/// from the path's own tangent: the squircle and continuous corners are
/// polylines, so their tangents are piecewise constant and would step the
/// light around a corner instead of sweeping it.
_RimOutline? _sampleOutline(
    LiquidGlassLitShape shape, Size size, Offset scale) {
  final Path path = liquidGlassOutlinePath(shape, size, scale);
  final double cx = size.width / 2.0;
  final double cy = size.height / 2.0;
  final List<_RimContour> contours = <_RimContour>[];

  for (final ui.PathMetric metric in path.computeMetrics()) {
    final double length = metric.length;
    if (!length.isFinite || length < 4.0) continue;

    int count = (length / _kSampleStepPx).ceil();
    if (count < _kMinSamples) count = _kMinSamples;
    if (count > _kMaxSamples) count = _kMaxSamples;
    final _RimContour contour = _RimContour(count);
    final double step = length / count;

    for (int i = 0; i < count; i++) {
      final ui.Tangent? tangent = metric.getTangentForOffset(i * step);
      if (tangent == null) return null;
      contour.px[i] = tangent.position.dx;
      contour.py[i] = tangent.position.dy;
    }

    for (int i = 0; i < count; i++) {
      final int prev = i == 0 ? count - 1 : i - 1;
      final int next = i + 1 == count ? 0 : i + 1;
      double tx = contour.px[next] - contour.px[prev];
      double ty = contour.py[next] - contour.py[prev];
      final double len = math.sqrt(tx * tx + ty * ty);
      if (len < 1e-6) {
        tx = 1.0;
        ty = 0.0;
      } else {
        tx /= len;
        ty /= len;
      }
      // Rotate the tangent a quarter turn, then point it away from the centre
      // — every glass shape is convex, so that alone settles the outward side.
      double ox = ty;
      double oy = -tx;
      if (ox * (contour.px[i] - cx) + oy * (contour.py[i] - cy) < 0.0) {
        ox = -ox;
        oy = -oy;
      }
      contour.nx[i] = ox;
      contour.ny[i] = oy;
    }
    contours.add(contour);
  }

  if (contours.isEmpty) return null;
  return _RimOutline(contours, path);
}
