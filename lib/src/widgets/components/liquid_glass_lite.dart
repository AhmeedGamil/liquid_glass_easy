import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/liquid_glass_light.dart';
import '../utils/liquid_glass_shape.dart';

/// Where a painted rim gets its colour — and what that costs.
///
/// The shader's rim reads the refracted background under **each pixel** and
/// tints itself with it, which is why a real lens' border changes colour along
/// its own length as it crosses a photograph. These are the three ways to
/// answer that without a fragment shader, cheapest first.
enum LiquidGlassLitePickup {
  /// The rim carries its own light: one tone, whatever it is over. One
  /// `drawVertices` and nothing else — nothing is read, nothing is layered.
  /// The cheap one.
  none,

  /// The rim's light is **blended** into what is under it instead of covering
  /// it, so the colour underneath comes through the highlight — and then the
  /// rim's own colour is multiplied in over that, so the specular's `color`
  /// shows: a grey light is a grey rim over white. The cheap way to look read.
  ///
  /// Nothing is read back: it is [surface]'s overlay and floor, plus one more
  /// pass over the same mesh in `multiply`. The pass is skipped when the rim's
  /// colour is plain white, where it would change nothing.
  blend,

  /// The rim is cut out of a brightened, saturated copy of the background, so
  /// its colour varies **along** the rim the way the shader's does: red where
  /// it crosses red, blue where it crosses blue, within the one rim. The
  /// default.
  ///
  /// This is the close one, and the expensive one — it reads the backdrop, the
  /// same cost a lens pays, plus two layers. Drop to [blend] or [none] when a
  /// screen has many of them. The lift is the shader's: the same lightness
  /// added to the background, by the rim's strength at each point. One thing
  /// parts company with it: the colour transform is a matrix, so it scales
  /// the background's saturation where the shader adds to it, and a neutral
  /// background is not warmed. [LiquidGlassLite.ambientColor] is not read —
  /// the background is the ambient. The specular's `color` replaces the
  /// picked-up colour by its alpha, as on a lens.
  ///
  /// It reads the **background** — the frosted, magnified backdrop and nothing
  /// else, as the shader samples its rim colour before the tint goes on. The
  /// rim sits over [LiquidGlassLite.color] and under [LiquidGlassLite.child],
  /// so neither one bleeds into it; the child paints over the rim, as it does
  /// over a lens.
  backdrop,

  /// [blend]'s rim, painted over the finished **surface** instead: the
  /// frost, then [LiquidGlassLite.color], then [LiquidGlassLite.child], and
  /// the rim blends into all three. A tinted glass tints its rim, and a label
  /// that runs under the edge shows along it. The rim is the topmost thing
  /// in the box, over the child. Same passes, same cost, no read.
  surface,
}

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
/// half that needs a shader, and keeps the half that does not: the frost, the
/// rim, and the colour the rim takes off the background.
///
/// The rim is a lens' specular, evaluated on the Dart side: the outline is
/// sampled into a ring of points, each point's outward normal is run through
/// the shader's own formulas — the same ramp across the edge, the same pair
/// of arcs on the light's axis, the same lift of the colour under it — and
/// the result is one `drawVertices` call. [blur] is the glass itself; the
/// rim is its edge. No shader asset, no `FragmentProgram`, nothing to warm
/// up.
///
/// ```dart
/// LiquidGlassLite(
///   shape: const LiquidGlassShape(
///     cornerRadius: 22,
///   ),
///   specular: const LiquidGlassLight.specular(thickness: 1.5, angle: 90),
///   child: const Text('on the glass'),
/// )
/// ```
///
/// It takes the ordinary [LiquidGlassShape] and one light, the [specular],
/// which draws the same rim here as it does on a lens. A glow and a second
/// specular are not drawn. The silhouette comes from the same
/// outline a lens clips to, so all three corner styles — circular, squircle,
/// and the continuous capsule corner — are reproduced exactly.
///
/// ## Taking colour from the background
///
/// The shader's rim samples the **refracted background under each pixel** and
/// tints the highlight with it, so over a photograph the real rim picks the
/// colours up pixel by pixel. There are three answers to that here, and
/// [pickup] chooses between them — see [LiquidGlassLitePickup]:
///
///  * [LiquidGlassLitePickup.none] takes nothing. White light, which is what
///    the shader produces over a neutral background.
///  * [LiquidGlassLitePickup.blend] adds the rim to what is under it instead of
///    covering it, then multiplies its own colour in, so the hue comes
///    through and the light colour shows — blend modes, no read.
///  * [LiquidGlassLitePickup.surface] is the same rim painted over the tint and
///    the child instead of under them, so the tint colours it.
///  * [LiquidGlassLitePickup.backdrop] (the default) cuts the rim out of a
///    brightened copy of the background, so its colour varies **along** the
///    rim the way the shader's does. It reads the backdrop, so it costs what
///    a lens costs.
///
/// [ambientColor] is the fourth way, and it is orthogonal: hand it one colour
/// — a sampled backdrop, or whatever surface the border sits on — and it goes
/// through the shader's own highlight math, tinting the whole rim at once
/// instead of each pixel. Free, but one tone for the whole outline.
///
/// There is no refraction in any mode — no edge bend. [magnification] is the
/// flat-slab half only; the rim itself does not shift with the content behind
/// it the way glass does.
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
/// Out of the box it frosts and picks its rim colour off the background, which
/// reads closest to the real thing and costs two backdrop reads. Both are
/// switchable, and turning both off leaves one `drawVertices` — put a fill of
/// your own behind it and it is nearly free:
///
/// ```dart
/// LiquidGlassLite(
///   blur: 0,
///   pickup: LiquidGlassLitePickup.surface,
///   shape: shape,
///   child: child,
/// )
/// ```
class LiquidGlassLite extends StatelessWidget {
  /// Creates a shader-free sheet of glass behind [child].
  const LiquidGlassLite({
    super.key,
    this.shape = const LiquidGlassShape(),
    this.specular,
    this.borderAlpha = 1.0,
    this.blur = 3.0,
    this.magnification = 1.0,
    this.pickup = LiquidGlassLitePickup.backdrop,
    this.color,
    this.blendFloor = 0.35,
    this.ambientColor,
    this.shapeScale = const Offset(1.0, 1.0),
    this.child,
  });

  /// The outline to draw, read exactly as a lens reads it.
  final LiquidGlassShape shape;

  /// The rim's one light; `null` is `LiquidGlassLight.specular()`. It is read
  /// as a lens reads its specular: thickness, sharpness, angle, spread,
  /// intensity and colour.
  final LiquidGlassLight? specular;

  /// The outline with its light, as the painters read it.
  LiquidGlassLitShape get _lit =>
      LiquidGlassLitShape.of(shape, specular: specular);

  /// How much the surface frosts what is behind it, inside its own outline.
  ///
  /// This is the glass itself rather than its edge: a backdrop blur clipped to
  /// the shape, painted under [child], the same thing a lens' appearance blur
  /// does. A Gaussian sigma; it defaults to a light `3` — pass `0` for a
  /// bare rim over whatever is already there.
  ///
  /// It costs a backdrop read, and with [LiquidGlassLitePickup.backdrop] the
  /// rim's own read comes on top of it: two reads for a surface that carries
  /// both. That is what a blurred lens costs too, so a screen with many of
  /// them wants `0` here, or [LiquidGlassLitePickup.surface]
  /// there, or both.
  final double blur;

  /// How much the surface magnifies what is behind it: the backdrop scaled
  /// about the shape's centre, evenly, across the whole surface. This is the
  /// flat-slab half of a lens' refraction — the content inside the outline
  /// stops lining up with the content outside it. It rides in the [blur]'s
  /// own filter, so it is free when blur is on. `1.0` is flat.
  final double magnification;

  /// Whether — and how — the rim takes its colour from what is behind it.
  /// See [LiquidGlassLitePickup].
  final LiquidGlassLitePickup pickup;

  /// The glass's own tint, `LiquidGlassStyle.color`'s counterpart: a
  /// flat fill of the shape between the frost and [child].
  ///
  /// Under [LiquidGlassLitePickup.backdrop] and [LiquidGlassLitePickup.blend] the rim
  /// sits over it and never takes colour from it, as on a lens: laid beneath
  /// the rim inside the read's own layer, or painted around the rim, cut by
  /// the rim's alpha. Under [LiquidGlassLitePickup.surface] and
  /// [LiquidGlassLitePickup.none] it is a plain fill under the child, and the rim
  /// is painted over it. `null`, or fully transparent, paints nothing.
  final Color? color;

  /// How much plain white rim survives underneath
  /// [LiquidGlassLitePickup.blend] and [LiquidGlassLitePickup.surface].
  ///
  /// The blend there is `overlay`, and overlay multiplies: over black there is
  /// nothing to multiply, so the rim would disappear exactly where it shows
  /// most. This is the plain rim screened over the blend afterwards, showing
  /// through wherever the blend came out empty.
  ///
  /// It is a straight trade — every bit of floor buys visibility on black with
  /// tint on colour. Measured on a red field and a black one, as how far the
  /// rim's red runs ahead of its blue, and how bright it is over black:
  ///
  /// ```text
  ///   floor   tint on red   light on black
  ///    0.0        147             0     ← invisible where it is needed
  ///    0.1        137            19
  ///    0.2        125            37
  ///    0.35       110            65     ← the default
  ///    0.5         94            93
  ///   (a plain rim, for scale: 46 and 186)
  /// ```
  ///
  /// The default now holds MORE colour than
  /// [LiquidGlassLitePickup.backdrop] does (104 at 70) — and that one reads
  /// the backdrop to get there.
  ///
  /// Ignored by the other pickup modes.
  final double blendFloor;

  /// A global multiplier on the rim's opacity, for fading it in and out. The
  /// lens uses the same knob for its own show/hide animation.
  final double borderAlpha;

  /// The background color the highlight is tinted with.
  ///
  /// The shader samples this per pixel from the refracted backdrop; here it is
  /// one color for the whole rim. Null keeps the shader's untinted behavior —
  /// a white highlight scaled by the specular's colour.
  final Color? ambientColor;

  /// The deformation applied to the outline, matching a lens' shape scale: the
  /// shape is built at rest size and stretched, so a squeezed circle becomes an
  /// ellipse instead of keeping a fixed corner radius.
  final Offset shapeScale;

  /// The content the rim is drawn over. When null the widget expands to its
  /// constraints and draws the rim alone.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final double zoom = magnification;
    final bool frosted = blur > 0.0 || (zoom != 1.0 && zoom > 0.0);
    final bool fromBackdrop = pickup == LiquidGlassLitePickup.backdrop;
    final bool picksUp = fromBackdrop;
    final bool overSurface = pickup == LiquidGlassLitePickup.surface;
    final Color? tint = (color?.a ?? 0.0) > 0.0 ? color : null;

    // Nothing to read: the rim is one painter, as cheap as the widget gets.
    if (!frosted && !picksUp) {
      final Widget painted = overSurface
          ? CustomPaint(
              foregroundPainter: _painter(),
              child: tint == null ? child : _tinted(tint, child),
            )
          : _painted(tint, child);
      return child == null ? SizedBox.expand(child: painted) : painted;
    }

    final Widget content = child ?? const SizedBox.expand();
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        // The glass, under everything.
        if (frosted) Positioned.fill(child: IgnorePointer(child: _frost())),
        // Reading the background: the rim goes on now, over the frost and
        // under all else, and carries the tint beneath itself so the tint
        // is never in its read. Above the frost, so it reads the frosted
        // surface and its colour runs smooth along the edge instead of
        // picking up every speck behind it.
        if (fromBackdrop)
          Positioned.fill(child: IgnorePointer(child: _rimPickup(tint))),
        // Over the surface: the tint is a plain fill, and the rim is painted
        // last, over the content, blending into tint and child alike.
        if (overSurface && tint != null)
          Positioned.fill(child: IgnorePointer(child: _fill(tint))),
        // The content: over the read rim, over the painted one, or under the
        // surface rim.
        if (picksUp)
          content
        else if (overSurface)
          CustomPaint(foregroundPainter: _painter(), child: content)
        else
          _painted(tint, content),
      ],
    );
  }

  /// A flat fill of [tint], cut to the outline like the frost is.
  Widget _fill(Color tint) => liquidGlassClip(
        shape: _lit,
        shapeScale: shapeScale,
        child: ColoredBox(color: tint),
      );

  /// [child] over a flat fill of [tint], filling the box.
  Widget _tinted(Color tint, Widget? child) => Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(child: IgnorePointer(child: _fill(tint))),
          child ?? const SizedBox.expand(),
        ],
      );

  /// The painted rim, composed the way a lens is: the rim over whatever is
  /// behind the glass, the tint over the rim, [child] over both.
  ///
  /// The tint is painted AROUND the rim — cut by the rim's own alpha — so a
  /// blending rim blends against the background, not against the tint, and
  /// the tint never lays over the rim's core. Free of any read; the cut is
  /// one layer, and only when there is a tint.
  Widget _painted(Color? tint, Widget? child) {
    final Widget content = child ?? const SizedBox.expand();
    return CustomPaint(
      painter: _painter(),
      child: tint == null
          ? content
          : Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TintAroundRimPainter(
                        shape: _lit,
                        borderAlpha: borderAlpha,
                        shapeScale: shapeScale,
                        tint: tint,
                      ),
                    ),
                  ),
                ),
                content,
              ],
            ),
    );
  }

  LiquidGlassLitePainter _painter() => LiquidGlassLitePainter(
        shape: _lit,
        borderAlpha: borderAlpha,
        ambientColor: ambientColor,
        shapeScale: shapeScale,
        blendMode: pickup == LiquidGlassLitePickup.blend ||
                pickup == LiquidGlassLitePickup.surface
            ? BlendMode.overlay
            : BlendMode.srcOver,
        blendFloor: blendFloor,
        lightPass: pickup == LiquidGlassLitePickup.blend ||
            pickup == LiquidGlassLitePickup.surface,
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
          filter: _highlightFilter(_lit.specular, under),
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

/// The rim's lift as a colour matrix, at [light]'s peak strength: the
/// background mixed with the rim's share of [tint], its chroma stretched and
/// the peak's lightness added. The mask's alpha scales that down to each
/// pixel's own strength.
ColorFilter _highlightFilter(LiquidGlassLight light, Color? tint) {
  final double peak = _rimPeak(light);
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

/// A fill of the shape with the rim cut out of it: [tint] everywhere inside
/// the outline, at `(1 - rim alpha)` of itself where the rim is.
///
/// Painted between a painted rim and the child, so the tint lands OVER the
/// rim's tail without laying over its core, and the rim — blended before
/// this goes on — took its colour from the background, not from the tint.
class _TintAroundRimPainter extends CustomPainter {
  const _TintAroundRimPainter({
    required this.shape,
    required this.borderAlpha,
    required this.shapeScale,
    required this.tint,
  });

  final LiquidGlassLitShape shape;
  final double borderAlpha;
  final Offset shapeScale;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final _RimOutline? outline = _outlineFor(shape, size, shapeScale);
    if (outline == null) return;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.clipPath(outline.path);
    canvas.drawRect(Offset.zero & size, Paint()..color = tint);
    final ui.Vertices? mesh = _buildRimMesh(
      outline: outline,
      shape: shape,
      size: size,
      borderAlpha: borderAlpha,
      ambientColor: null,
    );
    if (mesh != null) {
      // `dstOut`: the fill keeps `1 - alpha` of itself where the mesh is.
      canvas.drawVertices(
        mesh,
        BlendMode.modulate,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..blendMode = BlendMode.dstOut,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TintAroundRimPainter oldDelegate) =>
      oldDelegate.tint != tint ||
      oldDelegate.borderAlpha != borderAlpha ||
      oldDelegate.shapeScale != shapeScale ||
      !_sameBorderLook(oldDelegate.shape, shape);
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
    if (outline != null) {
      final ui.Vertices? mesh = _buildRimMesh(
        outline: outline,
        shape: shape,
        size: size,
        borderAlpha: borderAlpha,
        ambientColor: null,
        role: _RimRole.pickup,
      );
      if (mesh != null) {
        canvas.clipPath(outline.path);
        canvas.drawVertices(mesh, BlendMode.modulate, _rimPaint);
      }
    }
    canvas.restore();
    if (outline == null) return;

    canvas.save();
    canvas.clipPath(outline.path);
    // The light's own colour replaces the lifted one, by its alpha.
    final ui.Vertices? light = _buildRimMesh(
      outline: outline,
      shape: shape,
      size: size,
      borderAlpha: borderAlpha,
      ambientColor: null,
      role: _RimRole.light,
    );
    if (light != null) {
      canvas.drawVertices(light, BlendMode.modulate, _rimPaint);
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

/// Paints [LiquidGlassLite]'s rim — and only its rim — into any canvas.
///
/// Useful on its own inside another `CustomPaint`, a `Decoration`, or a render
/// object that already has a canvas — the widget is a thin wrapper over this.
class LiquidGlassLitePainter extends CustomPainter {
  /// Creates a painter for [shape]'s rim.
  const LiquidGlassLitePainter({
    required this.shape,
    this.borderAlpha = 1.0,
    this.ambientColor,
    this.shapeScale = const Offset(1.0, 1.0),
    this.blendMode = BlendMode.srcOver,
    this.blendFloor = 0.35,
    this.lightPass = false,
  });

  /// The geometry and lighting to draw. See [LiquidGlassLite.shape].
  final LiquidGlassLitShape shape;

  /// How the rim lands on what is already painted. `BlendMode.overlay` is what
  /// [LiquidGlassLitePickup.blend] and [LiquidGlassLitePickup.surface] use: the rim's
  /// light is blended into the background instead of covering it.
  final BlendMode blendMode;

  /// After a blending [blendMode], multiply the rim's own colour in — the
  /// specular's colour — so it shows over
  /// white, which overlay alone leaves untouched. What [LiquidGlassLitePickup.blend]
  /// and [LiquidGlassLitePickup.surface] do. Skipped when that colour is plain
  /// white. Ignored under `BlendMode.srcOver`, whose rim carries it already.
  final bool lightPass;

  /// The plain white rim kept underneath a multiplying [blendMode], so it does
  /// not vanish over black. See [LiquidGlassLite.blendFloor]. Unused when
  /// [blendMode] is `BlendMode.srcOver`.
  final double blendFloor;

  /// A global multiplier on the rim's opacity.
  final double borderAlpha;

  /// The background color the highlight is tinted with, or null for none.
  final Color? ambientColor;

  /// The outline deformation. See [LiquidGlassLite.shapeScale].
  final Offset shapeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final _RimOutline? outline = _outlineFor(shape, size, shapeScale);
    if (outline == null) return;
    final ui.Vertices? mesh = _buildRimMesh(
      outline: outline,
      shape: shape,
      size: size,
      borderAlpha: borderAlpha,
      ambientColor: ambientColor,
    );
    if (mesh == null) return;

    // A lens clips its shader to this same outline, so its rim lives strictly
    // INSIDE the shape. Without the clip the mesh's outer ramp hangs a pixel
    // past the edge and the border reads as drawn around the box, not in it.
    canvas.save();
    canvas.clipPath(outline.path);

    // The mesh carries the color; modulating it with opaque white leaves the
    // vertex colors untouched, and the fill lands with the paint's blend mode.
    if (blendMode == BlendMode.srcOver) {
      canvas.drawVertices(mesh, BlendMode.modulate, _rimPaint);
      canvas.restore();
      return;
    }

    // The blend first, on the untouched background, so it has the full colour
    // to work with.
    canvas.drawVertices(
      mesh,
      BlendMode.modulate,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..blendMode = blendMode,
    );

    // Then the floor, screened OVER the result. A multiplying blend leaves
    // nothing behind over black, and this is the plain rim showing through
    // where that happened. Screening it in first instead would hand the blend
    // a washed-out background and cost roughly half the tint.
    final double floor = blendFloor.clamp(0.0, 1.0);
    if (floor > 0.0) {
      canvas.drawVertices(
        mesh,
        BlendMode.modulate,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, floor)
          ..blendMode = BlendMode.screen,
      );
    }

    // Then the rim's own colour, multiplied in where the mesh has alpha.
    // `multiply` (not `modulate`) so the coverage lerps the pixel toward the
    // product and leaves its alpha alone — inside a layer, `modulate` would
    // punch the rim's alpha through it.
    if (lightPass && !_rimIsWhite(shape, ambientColor)) {
      canvas.drawVertices(
        mesh,
        BlendMode.modulate,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..blendMode = BlendMode.multiply,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiquidGlassLitePainter oldDelegate) =>
      oldDelegate.borderAlpha != borderAlpha ||
      oldDelegate.ambientColor != ambientColor ||
      oldDelegate.shapeScale != shapeScale ||
      oldDelegate.blendMode != blendMode ||
      oldDelegate.blendFloor != blendFloor ||
      oldDelegate.lightPass != lightPass ||
      !_sameBorderLook(oldDelegate.shape, shape);

  @override
  bool shouldRebuildSemantics(covariant LiquidGlassLitePainter oldDelegate) =>
      false;
}

final Paint _rimPaint = Paint()..color = const Color(0xFFFFFFFF);

/// Whether the rim mesh's colour is plain white everywhere, so multiplying it
/// in would change nothing.
bool _rimIsWhite(LiquidGlassLitShape shape, Color? ambientColor) {
  if (ambientColor != null) return false;
  final Color? light = shape.specular.color;
  return light == null ||
      light.a <= 0.0 ||
      (light.r >= 1.0 && light.g >= 1.0 && light.b >= 1.0);
}

/// Whether two shapes would draw the same rim: the specular is the only
/// light drawn here.
bool _sameBorderLook(LiquidGlassLitShape a, LiquidGlassLitShape b) {
  if (identical(a, b)) return true;
  return a.cornerStyle == b.cornerStyle &&
      a.cornerRadius == b.cornerRadius &&
      a.specular == b.specular;
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
  required LiquidGlassLitShape shape,
  required Size size,
  required double borderAlpha,
  required Color? ambientColor,
  _RimRole role = _RimRole.painted,
}) {
  if (borderAlpha <= 0.0) return null;
  if (!size.width.isFinite || !size.height.isFinite) return null;
  if (size.width <= 0.0 || size.height <= 0.0) return null;
  final LiquidGlassLight light = shape.specular;
  if (light.thickness <= 0.0 || light.intensity <= 0.0) return null;

  // How much of the rim is the light's own colour instead of a lifted one.
  final Color? lightColor = light.color;
  final double own = lightColor == null ? 0.0 : lightColor.a.clamp(0.0, 1.0);
  if (role == _RimRole.pickup && own >= 1.0) return null;
  if (role == _RimRole.light && own <= 0.0) return null;

  // The ramp's depth follows the thickness; sharpness slides the ramp.
  final double depth = light.thickness * _kRimDepthPerThickness;
  final double shift = _kRimShiftAtZero + light.sharpness.clamp(0.0, 1.0);

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
  final double peak = _rimPeak(light);
  final double alphaScale = borderAlpha.clamp(0.0, 1.0);

  // The lifted colour turns with the strength only over a colour to lift;
  // over white, or under a light that replaces it whole, it is one tone.
  final bool lifts =
      role == _RimRole.painted && ambientColor != null && own < 1.0;
  final int flatRgb = switch (role) {
    _RimRole.pickup => 0x00ffffff,
    _RimRole.light => _packRgb(lightColor!.r, lightColor.g, lightColor.b),
    _RimRole.painted => _rimRgb(1.0, 1.0, 1.0, 0.0, lightColor, own),
  };
  final double baseR = ambientColor?.r ?? 1.0;
  final double baseG = ambientColor?.g ?? 1.0;
  final double baseB = ambientColor?.b ?? 1.0;

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
      sampleArc[i] = math
          .pow(math.max(ndl * ndl * arcGain, 1e-6), arcPower)
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
            (strength * _kRimWeightGain).clamp(0.0, 1.0) * alphaScale;
        final double a = switch (role) {
          _RimRole.painted => weight,
          _RimRole.light => weight * own,
          // The read is lifted by the peak, so the strength's share of it
          // is the lift; the light's pass over it takes the rest.
          _RimRole.pickup =>
            (1.0 - own) * weight * (strength / peak) / (1.0 - weight * own),
        };
        final int rgb = lifts
            ? _rimRgb(baseR, baseG, baseB, strength, lightColor, own)
            : flatRgb;
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
  /// The whole rim: its colour, at its weight.
  painted,

  /// The mask a backdrop read is cut by: white, at the lift's share.
  pickup,

  /// The light's own colour, laid over a [pickup] rim.
  light,
}

// How a light's values read inside the rim: thickness 1, intensity 1 and
// sharpness 0.5 give the rest look. The shader's own constants.
const double _kRimDepthPerThickness = 5.4; // ramp depth per unit of thickness
const double _kRimIntensityScale = 0.1; // intensity 1 -> 0.1
const double _kRimShiftAtZero = -0.6; // sharpness 0..1 -> shift -0.6..0.4
const double _kRimWeightGain = 6.0; // strength -> coverage

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

/// The most strength [light]'s rim reaches anywhere: on its axis, at the
/// outline. Zero for a light that draws nothing.
double _rimPeak(LiquidGlassLight light) {
  if (light.thickness <= 0.0 || light.intensity <= 0.0) return 0.0;
  final double arc = math
      .pow(math.max(1.2 * light.intensity * _kRimIntensityScale, 1e-6),
          _rimArcPower(light.spread))
      .toDouble()
      .clamp(0.0, 1.0);
  return arc *
      _rimRamp(
        1.0,
        light.thickness * _kRimDepthPerThickness,
        _kRimShiftAtZero + light.sharpness.clamp(0.0, 1.0),
      );
}

/// The rim's colour at [strength] over the colour (r, g, b), packed as
/// 0x00RRGGBB: lightness added straight to luma, the colour offset
/// lengthened so hue holds, then [light] mixed in by [own].
int _rimRgb(
  double r,
  double g,
  double b,
  double strength,
  Color? light,
  double own,
) {
  final double luma = r * _kLumaR + g * _kLumaG + b * _kLumaB;
  double or = r - luma;
  double og = g - luma;
  double ob = b - luma;
  final double chroma = _kRimChroma * strength;
  final double length = math.sqrt(or * or + og * og + ob * ob);
  if (length > 1e-3) {
    final double k = (length + chroma) / length;
    or *= k;
    og *= k;
    ob *= k;
  } else {
    // A neutral has no hue to keep: it goes warm, not pink.
    or = chroma * 0.359;
    og = chroma * -0.028;
    ob = chroma * -0.829;
  }
  final double lifted = math.min(luma + _kRimLift * strength, 1.2);
  double outR = (lifted + or).clamp(0.0, 1.0);
  double outG = (lifted + og).clamp(0.0, 1.0);
  double outB = (lifted + ob).clamp(0.0, 1.0);
  if (light != null && own > 0.0) {
    outR += (light.r - outR) * own;
    outG += (light.g - outG) * own;
    outB += (light.b - outB) * own;
  }
  return _packRgb(outR, outG, outB);
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
