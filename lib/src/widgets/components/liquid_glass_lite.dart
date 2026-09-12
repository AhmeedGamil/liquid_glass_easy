import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_light_mode.dart';
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
  /// rim's own colour is multiplied in over that, so the shape's `lightColor`
  /// and `borderColor` show the way they do on a lens: a grey light is a grey
  /// rim over white, a tint is a tinted rim. The cheap way to look read.
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
  /// screen has many of them. Two things still part company
  /// with the shader: the colour transform is a matrix, so it cannot
  /// renormalise a *dark* background the way the shader's divide-by-luma does
  /// (over near black the rim reads grey where the shader reads white), and
  /// [LiquidGlassLite.ambientColor] is not read — the background is the
  /// ambient. `lightColor` scales the rim as it does in the shader, so a grey
  /// light is a grey rim over white; `borderColor` scales it too, rather than
  /// replacing it. `borderSaturation` rides in the colour matrix for free.
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
/// The rim is the same lighting model, evaluated on the Dart side: the outline
/// is sampled into a ring of points, each point's outward normal is run
/// through the shader's own formulas, and the result is one `drawVertices`
/// call — a triangle mesh whose vertex colors carry the light around the
/// perimeter and whose alpha carries the falloff across its width. [blur] is
/// the glass itself; the rim is its edge. No shader asset, no
/// `FragmentProgram`, nothing to warm up.
///
/// ```dart
/// LiquidGlassLite(
///   shape: const LiquidGlassShape(
///     cornerRadius: 22,
///     borderWidth: 1.5,
///     lightDirection: 90,
///   ),
///   child: const Text('on the glass'),
/// )
/// ```
///
/// It takes the ordinary [LiquidGlassShape], so [LiquidGlassShape.borderWidth],
/// [LiquidGlassShape.lightColor], [LiquidGlassShape.lightDirection],
/// [LiquidGlassShape.lightIntensity], [LiquidGlassShape.lightMode] and the
/// [OpticalBorder] / [ClassicBorder] parameters mean exactly what they mean on
/// a real lens, at the same numbers. The silhouette comes from the same
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
///   blur: const LiquidGlassBlur(),
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
    this.borderAlpha = 1.0,
    this.blur = const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    this.magnification = 1.0,
    this.pickup = LiquidGlassLitePickup.backdrop,
    this.color,
    this.blendFloor = 0.35,
    this.ambientColor,
    this.shapeScale = const Offset(1.0, 1.0),
    this.child,
  });

  /// The geometry and lighting to draw, read exactly as a lens reads it.
  final LiquidGlassShape shape;

  /// How much the surface frosts what is behind it, inside its own outline.
  ///
  /// This is the glass itself rather than its edge: a backdrop blur clipped to
  /// the shape, painted under [child], the same thing a lens' appearance blur
  /// does. It defaults to a light `3` — pass `const LiquidGlassBlur()` for a
  /// bare rim over whatever is already there.
  ///
  /// It costs a backdrop read, and with [LiquidGlassLitePickup.backdrop] the
  /// rim's own read comes on top of it: two reads for a surface that carries
  /// both. That is what a blurred lens costs too, so a screen with many of
  /// them wants `LiquidGlassBlur()` here, or [LiquidGlassLitePickup.surface]
  /// there, or both.
  final LiquidGlassBlur blur;

  /// How much the surface magnifies what is behind it: the backdrop scaled
  /// about the shape's centre, evenly, across the whole surface. This is the
  /// flat-slab half of a lens' refraction — the content inside the outline
  /// stops lining up with the content outside it. It rides in the [blur]'s
  /// own filter, so it is free when blur is on. `1.0` is flat.
  final double magnification;

  /// Whether — and how — the rim takes its colour from what is behind it.
  /// See [LiquidGlassLitePickup].
  final LiquidGlassLitePickup pickup;

  /// The glass's own tint, `LiquidGlassAppearance.color`'s counterpart: a
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
  /// a white highlight scaled by [LiquidGlassShape.lightColor].
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
    final bool frosted =
        blur.sigmaX > 0.0 || blur.sigmaY > 0.0 || (zoom != 1.0 && zoom > 0.0);
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
        shape: shape,
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
                        shape: shape,
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
        shape: shape,
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
        shape: shape,
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
          filter: _highlightFilter(shape.borderSaturation),
          child: CustomPaint(
            painter: _RimMaskPainter(
              shape: shape,
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

  final LiquidGlassBlur blur;
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
    required LiquidGlassBlur blur,
    required double magnification,
  })  : _blur = blur,
        _magnification = magnification;

  LiquidGlassBlur _blur;
  set blur(LiquidGlassBlur value) {
    if (_blur.sigmaX == value.sigmaX && _blur.sigmaY == value.sigmaY) return;
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
    final bool blurs = _blur.sigmaX > 0.0 || _blur.sigmaY > 0.0;
    final double z = _magnification;
    final bool bends = z != 1.0 && z > 0.0;
    if (!blurs && !bends) return null;

    final ui.ImageFilter? blur = blurs
        ? ui.ImageFilter.blur(sigmaX: _blur.sigmaX, sigmaY: _blur.sigmaY)
        : null;
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

/// Saturates the background, lifts it hard toward white, and keeps a floor
/// under it so the rim does not vanish over black. It stands in for the
/// shader's `getHighlightColor`, which divides by luma — a colour matrix
/// cannot divide, and that is the one place this parts company with it.
///
/// [saturation] is the shape's `borderSaturation`, riding on top of the boost
/// the mode carries anyway, so `1.0` is the look this mode has always had.
/// Saturating here costs nothing: it is the same matrix, with different
/// numbers in it.
ColorFilter _highlightFilter(double saturation) {
  const double gain = 2.0;
  const double floor = 96.0;
  const double base = 1.5;
  final double s = base * saturation.clamp(0.0, 4.0);
  final double d = 1.0 - s;
  double cell(double luma, {required bool own}) =>
      gain * (luma * d + (own ? s : 0.0));
  return ColorFilter.matrix(<double>[
    cell(_kLumaR, own: true), cell(_kLumaG, own: false),
    cell(_kLumaB, own: false), 0, floor, //
    cell(_kLumaR, own: false), cell(_kLumaG, own: true),
    cell(_kLumaB, own: false), 0, floor, //
    cell(_kLumaR, own: false), cell(_kLumaG, own: false),
    cell(_kLumaB, own: true), 0, floor, //
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

  final LiquidGlassShape shape;
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

  final LiquidGlassShape shape;
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
    // the highlight where the mesh has alpha AND multiplies the mesh's
    // colour into it — the shape's `lightColor` — after the layer clamped
    // the highlight to white, which is the order the shader does it in.
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
      );
      if (mesh != null) {
        canvas.clipPath(outline.path);
        canvas.drawVertices(mesh, BlendMode.modulate, _rimPaint);
      }
    }
    canvas.restore();

    final Color? fill = under;
    if (fill != null && outline != null) {
      canvas.save();
      canvas.clipPath(outline.path);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = fill
          ..blendMode = BlendMode.dstOver,
      );
      canvas.restore();
    }
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
  final LiquidGlassShape shape;

  /// How the rim lands on what is already painted. `BlendMode.overlay` is what
  /// [LiquidGlassLitePickup.blend] and [LiquidGlassLitePickup.surface] use: the rim's
  /// light is blended into the background instead of covering it.
  final BlendMode blendMode;

  /// After a blending [blendMode], multiply the rim's own colour in — the
  /// shape's `lightColor`, `borderColor` and saturation — so they show over
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
/// in would change nothing. Only an optical rim has one colour; a classic
/// sweep always carries a shadow tone somewhere along it.
bool _rimIsWhite(LiquidGlassShape shape, Color? ambientColor) =>
    shape.isOpticalBorder && _opticalRimRgb(shape, ambientColor) == 0x00ffffff;

/// Whether two shapes would draw the same rim.
bool _sameBorderLook(LiquidGlassShape a, LiquidGlassShape b) {
  if (identical(a, b)) return true;
  return a.cornerStyle == b.cornerStyle &&
      a.cornerRadius == b.cornerRadius &&
      a.borderWidth == b.borderWidth &&
      a.borderColor == b.borderColor &&
      a.lightIntensity == b.lightIntensity &&
      a.lightColor == b.lightColor &&
      a.lightDirection == b.lightDirection &&
      a.lightMode == b.lightMode &&
      a.isOpticalBorder == b.isOpticalBorder &&
      a.borderSoftness == b.borderSoftness &&
      a.shadowColor == b.shadowColor &&
      a.oneSideLightIntensity == b.oneSideLightIntensity &&
      a.doubleSideLightIntensity == b.doubleSideLightIntensity &&
      a.ambientIntensity == b.ambientIntensity &&
      a.borderSaturation == b.borderSaturation &&
      a.borderSolidity == b.borderSolidity &&
      a.lightSpread == b.lightSpread;
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
/// Around a ring the vertex color carries the angular light response; across
/// the rings its alpha carries the rim's radial profile. Both come from the
/// shader's own formulas. The outermost and innermost rings are pinned to
/// alpha zero, so the mesh fades out into its own boundary rather than needing
/// anti-aliased triangle edges, which `drawVertices` does not have.
ui.Vertices? _buildRimMesh({
  required _RimOutline outline,
  required LiquidGlassShape shape,
  required Size size,
  required double borderAlpha,
  required Color? ambientColor,
}) {
  if (borderAlpha <= 0.0) return null;
  if (!size.width.isFinite || !size.height.isFinite) return null;
  if (size.width <= 0.0 || size.height <= 0.0) return null;
  if (shape.borderWidth <= 0.0) return null;

  final bool optical = shape.isOpticalBorder;
  // The renderers hand the shader `borderWidth * 2`, plus a 2px bump in
  // optical mode, both in logical px. Matching it keeps a given borderWidth
  // reading as the same thickness here as it does on a lens.
  final double width = shape.borderWidth * 2.0 + (optical ? 2.0 : 0.0);
  final double softness = math.max(shape.borderSoftness, 0.0);

  // Under 2px of width the optical rim is scaled away entirely.
  final double thicknessFactor =
      optical ? ((width - 2.0) * 0.5).clamp(0.0, 1.0) : 1.0;
  if (thicknessFactor <= 0.0) return null;

  // Offsetting inward past the shape's inradius would fold the inner rings
  // through each other, so the rim's reach is capped short of it.
  final double maxInward = 0.45 * math.min(size.width, size.height);
  final List<double> rings = optical
      ? _opticalRings(width, softness, maxInward)
      : _classicRings(width, softness, maxInward);
  final int ringCount = rings.length;

  final List<double> profile = <double>[
    for (final double sd in rings)
      optical
          ? _opticalProfile(sd, width, softness)
          : _classicProfile(sd, width, softness),
  ];
  profile[0] = 0.0;
  profile[ringCount - 1] = 0.0;

  final double lightRad = shape.lightDirection * math.pi / 180.0;
  final double lx = math.cos(lightRad);
  final double ly = math.sin(lightRad);
  final bool radial = shape.lightMode == LiquidGlassLightMode.radial;
  final double cx = size.width / 2.0;
  final double cy = size.height / 2.0;

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

  // The optical rim is one tone for the whole shape — only its strength turns
  // with the normal — so the color is resolved once, up front.
  final int opticalRgb = optical ? _opticalRimRgb(shape, ambientColor) : 0;
  final _ClassicSweep? sweep =
      optical ? null : _ClassicSweep(shape, lightRad, lx, ly);

  final Float64List sampleAlpha = Float64List(_kMaxSamples);
  final Int32List sampleRgb = Int32List(_kMaxSamples);

  int vi = 0;
  int ii = 0;
  int vBase = 0;

  for (final _RimContour contour in outline.contours) {
    final int m = contour.count;

    // Per-sample tone — the part of the rim that depends on the normal alone.
    for (int i = 0; i < m; i++) {
      double nx = contour.nx[i];
      double ny = contour.ny[i];
      if (radial) {
        double rx = contour.px[i] - cx;
        double ry = contour.py[i] - cy;
        final double rl = math.sqrt(rx * rx + ry * ry);
        if (rl > 1e-6) {
          nx = rx / rl;
          ny = ry / rl;
        }
      }
      if (optical) {
        sampleAlpha[i] = borderAlpha *
            thicknessFactor *
            _opticalLight(shape, nx, ny, lx, ly);
        sampleRgb[i] = opticalRgb;
      } else {
        final int tone = sweep!.toneAt(nx, ny);
        sampleRgb[i] = tone & 0x00ffffff;
        sampleAlpha[i] = borderAlpha * ((tone >> 24) & 0xff) / 255.0;
      }
    }

    for (int k = 0; k < ringCount; k++) {
      final double sd = rings[k];
      final double p = profile[k];
      for (int i = 0; i < m; i++) {
        positions[vi * 2] = contour.px[i] + contour.nx[i] * sd;
        positions[vi * 2 + 1] = contour.py[i] + contour.ny[i] * sd;
        final double a = (sampleAlpha[i] * p).clamp(0.0, 1.0);
        colors[vi] = ((a * 255.0).round() << 24) | sampleRgb[i];
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
//  Radial profile — where the rim sits across the edge
// ─────────────────────────────────────────────────────────────

/// Signed distances (positive = outside the shape) of the optical mode's
/// rings, placed where the profile bends: it is brightest at the edge and
/// collapses within the first fifth of its depth.
List<double> _opticalRings(double width, double softness, double maxInward) {
  final double outer = math.max(softness, 1.0);
  final double depth = math.min(width, maxInward);
  return <double>[
    outer,
    0.0,
    -0.05 * depth,
    -0.12 * depth,
    -0.22 * depth,
    -0.38 * depth,
    -0.62 * depth,
    -depth,
  ];
}

/// Signed distances of the classic mode's rings: a band centered on the edge,
/// solid out to half the width and feathered inward by the softness.
List<double> _classicRings(double width, double softness, double maxInward) {
  final double half = math.min(width * 0.5, maxInward);
  final double soft = math.min(math.max(softness, 1e-3), maxInward - half);
  return <double>[
    // The shader cuts the outer side hard; half a pixel of ramp is all that
    // stands in for the anti-aliasing a mesh cannot do.
    half + 0.5,
    half,
    0.0,
    -half,
    -half - soft * 0.3,
    -half - soft * 0.65,
    -half - soft,
  ];
}

/// The optical rim's spatial mask at signed distance [sd] — the shader's
/// rational falloff, its inner and outer fades, and the lens height profile.
double _opticalProfile(double sd, double width, double softness) {
  final double rimWidth = math.max(width, 1.0);
  final double x = sd / rimWidth;
  double f = 1.0 / (1.0 + 0.89 * x * x);
  f *= 1.0 - _smoothstep(width * 1.5, width * 3.0, math.max(-sd, 0.0));
  f *= 1.0 - _smoothstep(0.0, math.max(softness, 1.0), math.max(sd, 0.0));
  if (f <= 0.0) return 0.0;

  // Circular cross-section: height 0 at the edge, full at depth `width`.
  double height;
  if (sd >= 0.0) {
    height = 0.0;
  } else if (sd < -width) {
    height = width;
  } else {
    final double t = width + sd;
    height = math.sqrt(math.max(0.0, width * width - t * t));
  }
  final double normalized = width > 0.0 ? height / width : 0.0;
  return f * ((1.0 - normalized) * 1.111).clamp(0.0, 1.0);
}

/// The classic rim's mask at signed distance [sd] — solid across the width,
/// feathered by the softness, and cut off outside.
double _classicProfile(double sd, double width, double softness) {
  final double half = width * 0.5;
  if (sd > half) return 0.0;
  return 1.0 - _smoothstep(half, half + math.max(softness, 1e-3), sd.abs());
}

double _smoothstep(double edge0, double edge1, double x) {
  if (edge1 <= edge0) return x < edge0 ? 0.0 : 1.0;
  final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// ─────────────────────────────────────────────────────────────
//  Angular response — how bright the rim is at a given normal
// ─────────────────────────────────────────────────────────────

/// The optical rim's light strength for the normal (nx, ny): two lobes, one
/// facing the light and one facing away, widened or tightened by the spread,
/// with the ambient term on top.
double _opticalLight(
  LiquidGlassShape shape,
  double nx,
  double ny,
  double lx,
  double ly,
) {
  final double spread = shape.lightSpread.clamp(0.0, 1.0);
  final double spreadExp = 2.5 + (0.5 - 2.5) * spread;
  // Below the midpoint the exponent alone cannot shrink the bright core, so
  // each lobe's angular window narrows too.
  final double lobeCut = (0.5 - math.min(spread, 0.5)) * 1.7;
  final double span = 1.0 - lobeCut;

  final double ndl = nx * lx + ny * ly;
  final double front = ((math.max(ndl, 0.0) - lobeCut) / span).clamp(0.0, 1.0);
  final double back = ((math.max(-ndl, 0.0) - lobeCut) / span).clamp(0.0, 1.0);

  final double directional =
      math.pow(front + back, spreadExp).toDouble() * shape.lightIntensity * 3.0;
  final double strength = directional + shape.ambientIntensity * 0.1;

  // The cap is what decouples thickness from intensity: without it a bright
  // light would drag the rim's soft tail up to opaque and visually fatten it.
  // Solidity lifts the cap back off.
  final double capped = strength.clamp(0.0, 1.0);
  return capped + (strength - capped) * shape.borderSolidity.clamp(0.0, 1.0);
}

/// The optical rim's color, packed as 0x00RRGGBB. It is the same for every
/// pixel of the rim, so it is resolved once per paint.
int _opticalRimRgb(LiquidGlassShape shape, Color? ambientColor) {
  double r = 1.0;
  double g = 1.0;
  double b = 1.0;

  final Color? ambient = ambientColor;
  if (ambient != null) {
    final double ar = ambient.r;
    final double ag = ambient.g;
    final double ab = ambient.b;
    if (ar * ar + ag * ag + ab * ab > 1e-5) {
      // The shader's highlight: pull the background toward its own hue, then
      // blend that into white by how colorful it is.
      final double luminance = ar * _kLumaR + ag * _kLumaG + ab * _kLumaB;
      final double inv = 1.0 / math.max(luminance, 0.001);
      double sr = ar + (ar * inv - ar) * 0.8;
      double sg = ag + (ag * inv - ag) * 0.8;
      double sb = ab + (ab * inv - ab) * 0.8;
      final double dr = ar - luminance;
      final double dg = ag - luminance;
      final double db = ab - luminance;
      final double colorfulness = math.sqrt(dr * dr + dg * dg + db * db);
      final double mix = (colorfulness + 0.5).clamp(0.5, 1.0);
      r = (1.0 + (sr - 1.0) * mix).clamp(0.0, 1.0);
      g = (1.0 + (sg - 1.0) * mix).clamp(0.0, 1.0);
      b = (1.0 + (sb - 1.0) * mix).clamp(0.0, 1.0);
    }
  }

  final Color light = shape.lightColor;
  r *= light.r;
  g *= light.g;
  b *= light.b;

  final Color? tint = shape.borderColor;
  if (tint != null && tint.a > 0.0) {
    final double t = tint.a.clamp(0.0, 1.0);
    r += (tint.r - r) * t;
    g += (tint.g - g) * t;
    b += (tint.b - b) * t;
  }

  final double saturation = shape.borderSaturation;
  if (saturation != 1.0) {
    final double luma = r * _kLumaR + g * _kLumaG + b * _kLumaB;
    r = luma + (r - luma) * saturation;
    g = luma + (g - luma) * saturation;
    b = luma + (b - luma) * saturation;
  }

  return (_channel(r) << 16) | (_channel(g) << 8) | _channel(b);
}

/// The classic mode's sweep: two colors traded four times around the shape,
/// plus the specular lobes, resolved per normal.
class _ClassicSweep {
  _ClassicSweep(this.shape, this.lightRad, this.lx, this.ly)
      : lightR = shape.lightColor.r,
        lightG = shape.lightColor.g,
        lightB = shape.lightColor.b {
    final Color? tint = shape.borderColor;
    final bool tinted = tint != null && tint.a > 0.0;
    final Color c0 = tinted ? tint : shape.lightColor;
    final Color c1 = tinted ? tint : shape.shadowColor;
    r0 = c0.r;
    g0 = c0.g;
    b0 = c0.b;
    a0 = c0.a;
    r1 = c1.r;
    g1 = c1.g;
    b1 = c1.b;
    a1 = c1.a;
  }

  final LiquidGlassShape shape;
  final double lightRad;
  final double lx;
  final double ly;
  final double lightR;
  final double lightG;
  final double lightB;
  late final double r0, g0, b0, a0;
  late final double r1, g1, b1, a1;

  /// The unpremultiplied ARGB tone at the normal (nx, ny).
  int toneAt(double nx, double ny) {
    // Where this normal falls in the sweep, measured from the light.
    double angle = math.atan2(ny, nx) - lightRad;
    angle %= 2.0 * math.pi;
    final double t = angle / (2.0 * math.pi);

    final double u;
    final bool forward;
    if (t <= 0.25) {
      u = t / 0.25;
      forward = true;
    } else if (t <= 0.5) {
      u = (t - 0.25) / 0.25;
      forward = false;
    } else if (t <= 0.75) {
      u = (t - 0.5) / 0.25;
      forward = true;
    } else {
      u = (t - 0.75) / 0.25;
      forward = false;
    }

    double r = forward ? r0 + (r1 - r0) * u : r1 + (r0 - r1) * u;
    double g = forward ? g0 + (g1 - g0) * u : g1 + (g0 - g1) * u;
    double b = forward ? b0 + (b1 - b0) * u : b1 + (b0 - b1) * u;
    final double a = forward ? a0 + (a1 - a0) * u : a1 + (a0 - a1) * u;

    final double intensity = shape.lightIntensity;
    final double oneSide = shape.oneSideLightIntensity;
    if (oneSide > 0.0) {
      final double spec =
          math.pow(math.max(nx * lx + ny * ly, 0.0), 8.0).toDouble();
      final double k = spec * intensity * 0.8 * oneSide;
      r += lightR * k;
      g += lightG * k;
      b += lightB * k;
    }
    final double bothSides = shape.doubleSideLightIntensity;
    if (bothSides > 0.0) {
      final double ndl = nx * lx + ny * ly;
      final double front = math.pow(math.max(ndl, 0.0), 8.0).toDouble();
      final double back = math.pow(math.max(-ndl, 0.0), 8.0).toDouble();
      final double k = (front + back) * intensity * 0.8 * bothSides;
      r += lightR * k;
      g += lightG * k;
      b += lightB * k;
    }

    r *= intensity;
    g *= intensity;
    b *= intensity;

    return (_channel(a) << 24) |
        (_channel(r) << 16) |
        (_channel(g) << 8) |
        _channel(b);
  }
}

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

_RimOutline? _outlineFor(LiquidGlassShape shape, Size size, Offset scale) {
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
_RimOutline? _sampleOutline(LiquidGlassShape shape, Size size, Offset scale) {
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
