import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../lens/liquid_glass_blender.dart';
import '../../lens/liquid_glass_lens.dart';
import '../../liquid_glass_engine.dart';
import '../../liquid_glass_config.dart';
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_adaptivity.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_refraction_type.dart';
import '../../utils/liquid_glass_shape.dart';
import '../../utils/liquid_glass_spring.dart';
import 'liquid_glass_morph_motion.dart';

/// One scalar chasing a target through the package's spring integrator.
class _Spring {
  _Spring(double v)
      : value = v,
        target = v;

  double value;
  double target;
  double vel = 0;

  void step(double dt, double stiffness, double damping) {
    final (double v, double a) = liquidGlassSpringStep(
      x: value,
      vel: vel,
      target: target,
      dt: dt,
      stiffness: stiffness,
      damping: damping,
    );
    value = v;
    vel = a;
  }

  double get remaining => (target - value).abs();
  bool get moving => remaining > 0.05 || vel.abs() > 0.5;

  void snap() {
    value = target;
    vel = 0;
  }

  void copyFrom(_Spring o) {
    value = o.value;
    target = o.target;
    vel = o.vel;
  }
}

/// One blob of the morph: an ANCHOR point on two springs and a size on two
/// more, plus how each pair is timed against the plain spring.
///
/// The rect is derived — the anchor is the point of the rect that [anchor]
/// names, so a blob grows around that point the way Apple's matched
/// geometry does around its `anchor:`. Anchor and size are separate pairs on
/// purpose: the whole liquid look is the two NOT agreeing about where the
/// blob is.
class _Blob {
  final _Spring ax = _Spring(0);
  final _Spring ay = _Spring(0);
  final _Spring w = _Spring(0);
  final _Spring h = _Spring(0);

  Alignment anchor = Alignment.center;

  /// Seconds before that pair starts moving. A delay is how a blob lingers.
  double anchorDelay = 0;
  double sizeDelay = 0;

  /// Stiffness multipliers. Above 1 that pair leads the plain spring.
  double anchorMul = 1;
  double sizeMul = 1;

  /// Damping ratio override for that pair; null takes the motion's.
  double? anchorZeta;
  double? sizeZeta;

  /// The corner curve and radius this blob is drawn with. Null is a capsule.
  LiquidGlassShape? shape;

  double get _w => math.max(0, w.value);
  double get _h => math.max(0, h.value);

  Rect get rect => Rect.fromLTWH(
        ax.value - (anchor.x + 1) / 2 * _w,
        ay.value - (anchor.y + 1) / 2 * _h,
        _w,
        _h,
      );

  void aim(Rect r) {
    final Offset p = anchor.withinRect(r);
    ax.target = p.dx;
    ay.target = p.dy;
    w.target = r.width;
    h.target = r.height;
  }

  void snapTo(Rect r) {
    aim(r);
    for (final _Spring s in <_Spring>[ax, ay, w, h]) {
      s.snap();
    }
    anchorDelay = sizeDelay = 0;
  }

  /// Change which point is the anchor WITHOUT moving the rect.
  void rebase(Alignment a) {
    if (a == anchor) return;
    final Rect now = rect;
    final Rect tgt = Rect.fromLTWH(
      ax.target - (anchor.x + 1) / 2 * w.target,
      ay.target - (anchor.y + 1) / 2 * h.target,
      w.target,
      h.target,
    );
    anchor = a;
    final Offset p = a.withinRect(now);
    final Offset pt = a.withinRect(tgt);
    ax.value = p.dx;
    ay.value = p.dy;
    ax.target = pt.dx;
    ay.target = pt.dy;
  }

  void copyFrom(_Blob o) {
    ax.copyFrom(o.ax);
    ay.copyFrom(o.ay);
    w.copyFrom(o.w);
    h.copyFrom(o.h);
    anchor = o.anchor;
    shape = o.shape;
  }

  /// Plain timing: one spring, no lead, no lag.
  void plain() {
    anchorDelay = sizeDelay = 0;
    anchorMul = sizeMul = 1;
    anchorZeta = sizeZeta = null;
  }

  bool get moving =>
      anchorDelay > 0 ||
      sizeDelay > 0 ||
      ax.moving ||
      ay.moving ||
      w.moving ||
      h.moving;

  void step(double dt, double stiffness, double damping) {
    if (anchorDelay > 0) {
      anchorDelay -= dt;
    } else {
      final double k = stiffness * anchorMul;
      final double d = anchorZeta != null
          ? 2 * anchorZeta! * math.sqrt(k)
          : damping * math.sqrt(anchorMul);
      ax.step(dt, k, d);
      ay.step(dt, k, d);
    }
    if (sizeDelay > 0) {
      sizeDelay -= dt;
    } else {
      final double k = stiffness * sizeMul;
      final double d = sizeZeta != null
          ? 2 * sizeZeta! * math.sqrt(k)
          : damping * math.sqrt(sizeMul);
      w.step(dt, k, d);
      h.step(dt, k, d);
    }
  }
}

/// A sheet of liquid glass that MORPHS to fit whatever you put in it.
///
/// Swap the [child] and the glass measures the new one and flows to its size.
/// You do not tell it how big to be:
///
/// ```dart
/// LiquidGlassMorph(
///   alignment: Alignment.bottomRight,
///   motion: LiquidGlassMorphMotion.fluid,
///   child: open
///       ? const Menu(key: ValueKey('menu'))
///       : const Icon(Icons.more_horiz, key: ValueKey('dots')),
/// )
/// ```
///
/// That is the whole API. Add a row to `Menu` and the glass grows to match,
/// because there is only one truth about how big the menu is and the glass
/// reads it rather than being told it a second time.
///
/// [width] and [height] are OVERRIDES for the cases where you genuinely own a
/// dimension — a sheet with detents, a fixed-width menu whose height varies.
/// Set one and that axis is pinned while the other is still measured; set both
/// and nothing is measured at all.
///
/// ## How it moves
///
/// The morph is **two blobs of one liquid**, rendered as a single surface by
/// a [LiquidGlassBlender]. The new shape is born inside the old one and grows
/// around its anchor while that anchor travels to where it will finally sit;
/// the old shape lingers, then drains into it. The two are joined by the
/// blender's smooth union while they overlap, so mid-morph the outline has a
/// waist — which is what a resize can never have and what the eye reads as
/// liquid. At rest the blobs coincide and the union is switched off, so the
/// resting shape is exact.
///
/// Which of those you get is the [motion]: pick one of its presets. One of
/// them, [LiquidGlassMorphMotion.plain], is not two blobs at all but a
/// **single lens** whose outline springs from the old shape to the new: no
/// neck, no drain, one backdrop pass. Any preset becomes that kind with
/// `copyWith(blended: false)`.
///
/// Each blob keeps its own corner curve and radius. Nothing is interpolated
/// or swapped: the old shape is drawn as the old shape until it is gone, and
/// the new one as its own from the moment it appears.
///
/// Content is not stretched with the glass. The old child blurs, fades and
/// scales out; the new one blurs, fades and scales in around the anchor as
/// the glass arrives, pinned where it will finally sit. Both run on the
/// morph's own clock — its duration is the spring's period — at the
/// fractions [LiquidGlassMorphAdvanced] names: the old child is gone by
/// `contentOutEnd`, the new one starts at `contentInStart` and has landed
/// by `contentInEnd`. A swap that reverses mid-flight carries each child on
/// from wherever it had got to, so a child that had not yet appeared never
/// does. And the material thickens as the glass grows — more blur, deeper
/// refraction — the way Apple's does when a menu opens from a button.
///
/// ## Layout, and why [alignment] matters
///
/// This widget **fills the box it is given** and places the glass inside that
/// box according to [alignment]. It has to: a size on its own does not say
/// which way a surface should grow, and that is the difference between a morph
/// that works anywhere and one that only works in the middle.
///
/// Centred, both edges move and every direction looks correct — which is
/// exactly why getting this wrong stays invisible until you move the thing.
/// At [Alignment.centerLeft] the left edge holds and it opens rightward; at
/// [Alignment.bottomRight] that corner holds and it opens up and to the left.
/// Grow symmetrically at an edge and the surface walks across the screen or
/// straight off it.
///
/// [Alignment] is continuous, so this is not a nine-position menu: an axis at
/// `x` sends `(1 + x) / 2` of any size change out one side and the rest out
/// the other. `Alignment(-0.37, 0.12)` is as valid as [Alignment.centerLeft].
/// If the surface is placed by something that is not an alignment — a
/// `Positioned`, a list, a drag — use [alignmentFor] to recover the alignment
/// its own rect implies.
///
/// Under unbounded constraints there is no box to anchor inside, so the widget
/// shrinks to the glass and [alignment] stops mattering.
class LiquidGlassMorph extends StatefulWidget {
  const LiquidGlassMorph({
    super.key,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.motion = LiquidGlassMorphMotion.fluid,
    this.style = const LiquidGlassStyle(),
    this.smoothness = 40,
    this.onEnd,
    this.debugClipBounds = false,
    this.child,
  })  : assert(width == null || width >= 0),
        assert(height == null || height >= 0),
        assert(smoothness >= 0),
        assert(
            child != null || (width != null && height != null),
            'With no child there is nothing to measure, so both width and '
            'height have to be given.');

  /// Pins the width instead of measuring it. `null` — the default — takes the
  /// width from [child].
  final double? width;

  /// Pins the height instead of measuring it. `null` — the default — takes the
  /// height from [child].
  final double? height;

  /// Which edge or corner HOLDS while the surface changes size. See the class
  /// docs — this is the parameter people leave at centre and later regret.
  final Alignment alignment;

  /// The physics. Pick a preset: [LiquidGlassMorphMotion.fluid],
  /// [LiquidGlassMorphMotion.anchoredPop], [LiquidGlassMorphMotion.droplet]
  /// or [LiquidGlassMorphMotion.calm].
  final LiquidGlassMorphMotion motion;

  /// The glass material.
  ///
  /// Its `shape` is the shape of the DESTINATION: the corner curve and radius
  /// the glass takes once it arrives, and the one the new blob is drawn with
  /// from the moment it appears. Border, light, tint, blur and refraction are
  /// passed through, with blur and refraction thickened as the glass grows.
  /// With no shape at all the surface is a capsule: the radius resolves to
  /// half the short side.
  final LiquidGlassStyle style;

  /// Peak radius, in logical pixels, of the neck between the two blobs — the
  /// same quantity as [LiquidGlassBlender.smoothness]. It is nothing while
  /// the blobs coincide and full once they have parted, so the resting shape
  /// is never inflated by it.
  final double smoothness;

  /// Called once the springs settle, the way `AnimatedContainer.onEnd` is.
  final VoidCallback? onEnd;

  /// Debug: outline the blender's backdrop clip region in magenta.
  ///
  /// Forwarded verbatim to [LiquidGlassBlender.debugClipBounds], so it shows
  /// the union of the two blobs inflated by the rim/blur/refraction/bridge
  /// margin — the region the costly backdrop pass actually runs over. The
  /// morph is the widget that moves that region every frame, so this is the
  /// way to see it grow and shrink through a swap.
  ///
  /// **Diagnostic only — it costs performance.** Leave it `false` in
  /// production.
  final bool debugClipBounds;

  /// The content, and — unless [width] and [height] say otherwise — the thing
  /// that decides how big the glass is.
  ///
  /// **Give your children keys**: a child that keeps its type is not seen as
  /// new — it will neither cross-fade nor be re-measured as a swap.
  ///
  /// It must be able to size itself: whatever it reports under a loose
  /// constraint is what the glass becomes. A `Column` of rows works; a bare
  /// `Column` with `crossAxisAlignment: stretch` will report the full width it
  /// is offered, which is probably not what you meant.
  final Widget? child;

  /// The alignment that would place [rect] inside [field] — the exact inverse
  /// of [Alignment.inscribe].
  ///
  /// For surfaces positioned by something other than an alignment. A rect
  /// inside a field implies the alignment that would have put it there, so
  /// anything with a position can be handed the anchor that position wants:
  ///
  /// ```dart
  /// alignment: LiquidGlassMorph.alignmentFor(cardRect, pageRect),
  /// ```
  ///
  /// Returns `0` on an axis where the box fills the field, since every
  /// alignment then places it identically.
  static Alignment alignmentFor(Rect rect, Rect field) {
    final double slackX = field.width - rect.width;
    final double slackY = field.height - rect.height;
    return Alignment(
      slackX.abs() < 0.01 ? 0 : ((rect.left - field.left) / slackX) * 2 - 1,
      slackY.abs() < 0.01 ? 0 : ((rect.top - field.top) / slackY) * 2 - 1,
    );
  }

  @override
  State<LiquidGlassMorph> createState() => _LiquidGlassMorphState();
}

class _LiquidGlassMorphState extends State<LiquidGlassMorph>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// The blob that carries the OLD content and the old shape. It lingers,
  /// then drains into [_dst]. At rest it sits exactly on top of it.
  final _Blob _src = _Blob();

  /// The blob that carries the NEW content and the destination shape.
  final _Blob _dst = _Blob();

  /// Seconds since the current swap began — the content's clock, read as a
  /// fraction of the motion's duration by [_t]. Starts past the end so a
  /// mounted widget's content is simply there.
  double _elapsed = 1e9;

  /// Where each child's visibility WAS when the current swap began, 0–1.
  /// The old child fades out from [_srcFrom] to nothing; the new one fades
  /// in from [_dstFrom] to full. A swap that reverses mid-flight hands the
  /// levels across, so a child that never got to appear leaves at zero —
  /// unseen — and one that was on its way out comes back from where it is.
  double _srcFrom = 0;
  double _dstFrom = 1;

  /// The old child, kept only while the swap is playing.
  Widget? _srcChild;

  /// What the current child reported. Null until the first measurement lands,
  /// which is one frame after mount.
  Size? _natural;

  /// The child the measurement belongs to, so a stale report from a child
  /// that has since been swapped out cannot aim the glass at its size.
  Key? _measuredKey;

  /// False until the springs have been given a real target. Until then the
  /// glass is not painted — there is nothing meaningful to paint yet, and
  /// springing up from zero would be an opening animation nobody asked for.
  bool _seeded = false;

  /// The box the glass is anchored inside, as of the last build.
  Size _field = Size.zero;

  /// Where the glass is going, and where it came from, this morph.
  Rect _target = Rect.zero;
  Rect _origin = Rect.zero;

  /// The rect the old child is pinned to: the one it was drawn in when the
  /// swap came, set right then. [_origin] is the glass's and is only known
  /// once the new child has been measured, a frame later — read for the
  /// content on that frame it is the PREVIOUS morph's origin, and the old
  /// child was drawn one frame inside the outline it is about to leave for.
  Rect _srcPin = Rect.zero;

  /// The smallest and largest area the glass has had: the material thickens
  /// from one to the other, so a shape's thickness is the same every time it
  /// is visited.
  double _smallArea = 1;
  double _bigArea = 1;

  /// How far past the field the blender reaches on every side.
  ///
  /// A bouncy spring overshoots by a few percent of its travel, the neck can
  /// swell by [LiquidGlassMorph.smoothness], and the rim and blur reach past
  /// the outline — all of which the blender would otherwise cut at the
  /// field's edge. Set per morph off the larger of its two rects.
  double _overflow = 24;

  /// The motion this morph runs. Under lite glass — the engine switch or
  /// this style's own flag — it is always [LiquidGlassMorphMotion.plain]:
  /// the blender cannot merge two lite blobs into one surface, so a blended
  /// preset would show two separate frosted outlines pulling apart. One lens
  /// on one spring is the only kind that reads.
  LiquidGlassMorphMotion get _m =>
      LiquidGlassEngine.liteGlass || widget.style.liteGlass != null
          ? LiquidGlassMorphMotion.plain
          : widget.motion;
  LiquidGlassMorphAdvanced get _a => _m.advanced;

  /// The point the new shape grows around: the motion's, or the corner that
  /// holds.
  Alignment get _anchor => _m.anchor ?? widget.alignment;

  /// The content's progress through the swap, 0–1: [_elapsed] as a fraction
  /// of the motion's duration, which is the spring's period.
  double get _t => (_elapsed / _m.duration).clamp(0.0, 1.0);

  /// The old child's visibility at [t]: from [_srcFrom] down to nothing by
  /// `contentOutEnd`.
  double _srcLevel(double t) {
    final double u = (t / math.max(_a.contentOutEnd, 0.01)).clamp(0.0, 1.0);
    return _srcFrom * (1 - Curves.easeIn.transform(u));
  }

  /// The new child's visibility at [t]: from [_dstFrom] up to full between
  /// `contentInStart` and `contentInEnd`.
  double _dstLevel(double t) {
    final double span = math.max(_a.contentInEnd - _a.contentInStart, 0.01);
    final double u = ((t - _a.contentInStart) / span).clamp(0.0, 1.0);
    return _dstFrom + (1 - _dstFrom) * Curves.easeOut.transform(u);
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Key _keyOf(Widget? c) => c?.key ?? ValueKey<Type>(c.runtimeType);

  /// [LiquidGlassShape] has no value equality, and the caller usually builds
  /// a fresh one per build — so compare what is drawn, not the instance, or
  /// every rebuild would start a morph.
  static bool _sameShape(LiquidGlassShape? a, LiquidGlassShape? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.cornerStyle == b.cornerStyle &&
        a.cornerRadius == b.cornerRadius &&
        a.clipQuality == b.clipQuality &&
        a.borderWidth == b.borderWidth &&
        a.borderColor == b.borderColor &&
        a.lightIntensity == b.lightIntensity &&
        a.lightColor == b.lightColor &&
        a.lightDirection == b.lightDirection &&
        a.lightMode == b.lightMode;
  }

  Size? get _targetSize {
    final double? w = widget.width ?? _natural?.width;
    final double? h = widget.height ?? _natural?.height;
    return (w == null || h == null) ? null : Size(w, h);
  }

  bool get _idle => !_ticker.isActive;

  /// The constraints the child is measured under.
  ///
  /// An axis with an override is TIGHT, so the child lays out at exactly that
  /// size and only the other axis is measured — which is the common case of a
  /// fixed-width menu whose height depends on its rows. A measured axis is
  /// loose, bounded by the field so the child has something finite to work
  /// with.
  BoxConstraints _measureConstraints(BoxConstraints c) => BoxConstraints(
        minWidth: widget.width ?? 0,
        maxWidth: widget.width ?? (c.hasBoundedWidth ? c.maxWidth : 1e6),
        minHeight: widget.height ?? 0,
        maxHeight: widget.height ?? double.infinity,
      );

  Rect _place(Size s) => widget.alignment.inscribe(s, Offset.zero & _field);

  void _setOverflow(Rect a, Rect b) {
    final double biggest = math.max(
      math.max(a.width, a.height),
      math.max(b.width, b.height),
    );
    _overflow = 24 + widget.smoothness + biggest * 0.15;
  }

  /// A rect of [size] centred on [at], pushed back inside [bounds] where it
  /// fits — so a seed born off-centre still starts inside the old shape.
  static Rect _inside(Rect bounds, Offset at, Size size) {
    double l = at.dx - size.width / 2;
    double t = at.dy - size.height / 2;
    if (size.width <= bounds.width) {
      l = l.clamp(bounds.left, bounds.right - size.width);
    }
    if (size.height <= bounds.height) {
      t = t.clamp(bounds.top, bounds.bottom - size.height);
    }
    return Rect.fromLTWH(l, t, size.width, size.height);
  }

  /// Aim the blobs at whatever the current width/height resolve to.
  ///
  /// The first successful call SNAPS: mounting is not a morph. [swap] says
  /// the child itself changed, so the content cross-fades; a bare resize of
  /// the same child only moves the glass.
  void _retarget({required bool swap}) {
    final Size? size = _targetSize;
    if (size == null) return;
    final Rect to = _place(size);
    final LiquidGlassShape? shape = widget.style.shape;
    final LiquidGlassMorphAdvanced a = _a;

    if (!_seeded) {
      _seeded = true;
      _target = _origin = _srcPin = to;
      _smallArea = _bigArea = to.width * to.height;
      _setOverflow(to, to);
      _dst.shape = shape;
      _dst.snapTo(to);
      _src.copyFrom(_dst);
      _srcChild = null;
      _srcFrom = 0;
      _dstFrom = 1;
      _elapsed = 1e9;
      return;
    }

    if (to == _target && _sameShape(shape, _dst.shape) && !swap) return;

    // Where the glass IS right now becomes the source of this morph — so a
    // retarget mid-flight starts from the moving outline, not from wherever
    // the last morph was meant to end.
    final Rect from = _dst.rect;
    _setOverflow(from, to);
    _origin = from;
    _target = to;
    final double fromArea = from.width * from.height;
    final double toArea = to.width * to.height;
    _smallArea = math.min(_smallArea, math.min(fromArea, toArea));
    _bigArea = math.max(_bigArea, math.max(fromArea, toArea));
    final bool growing = toArea >= fromArea * 0.999;

    final double leadMul = 1 + 2.2 * _m.stretch;
    final double leadZeta = (_m.zeta - a.leadBounce).clamp(0.05, 4.0);
    final Alignment anchor = _anchor;

    // The old blob takes over what the glass is right now.
    _src.copyFrom(_dst);
    _src.plain();
    _dst.plain();
    _dst.shape = shape;
    // A source that follows the destination lands exactly on it, so the two
    // must agree on the shape: a union of two corner curves on one rect
    // traces whichever sticks out, and snaps when the source is dropped.
    if (a.sourceFollows) _src.shape = shape;

    if (!_m.blended) {
      // One lens: the outline itself travels, from where it is to where it
      // is going. Growing, its anchor leads and its size follows, so it
      // stretches toward the destination before it fills in; shrinking, the
      // size collapses first and the anchor slides after it. The source
      // blob is kept coincident and never drawn.
      _dst.rebase(anchor);
      _dst.aim(to);
      if (growing) {
        _dst.anchorMul = leadMul;
        _dst.anchorZeta = leadZeta;
        _dst.sizeDelay = a.followDelay;
      } else {
        _dst.sizeMul = leadMul;
        _dst.sizeZeta = leadZeta;
        _dst.anchorDelay = a.followDelay;
      }
      _src.copyFrom(_dst);
      if (swap) _elapsed = 0;
      _wake();
      return;
    }

    if (growing) {
      // The new blob is born inside the old one — at the seed size, at the
      // anchor — and grows around that anchor as it travels. Its anchor
      // leads; its size follows.
      _src.rebase(Alignment.center);
      final Rect seed = _inside(
        from,
        anchor.withinRect(from),
        Size(from.width * a.seedScale, from.height * a.seedScale),
      );
      _dst.anchor = anchor;
      _dst.snapTo(seed);
      _dst.aim(to);
      _dst.anchorMul = leadMul;
      _dst.anchorZeta = leadZeta;
      _dst.sizeDelay = a.followDelay;

      // The old blob lingers, then drains: into the new shape, or to a speck
      // pulled toward the new shape's centre so nothing is left poking out
      // of its edge. Not to zero: a blender with one member paints no glass
      // at all, so it stops at a speck and is snapped onto the destination
      // once everything is still.
      if (a.sourceFollows) {
        _src.aim(to);
      } else {
        final Offset at = Offset.lerp(from.center, to.center, a.drainInward)!;
        _src.aim(Rect.fromCenter(center: at, width: 2, height: 2));
      }
      _src.anchorDelay = _src.sizeDelay = a.linger;
      _src.anchorMul = _src.sizeMul = a.drainSpeed;
      _src.anchorZeta = _src.sizeZeta = 1;
    } else {
      // Shrinking: the old shape is the traveller. Its size leads and its
      // anchor follows, so it deflates and then drains into the destination,
      // which is already there, small and inside it.
      _src.rebase(anchor);
      _src.aim(to);
      _src.sizeMul = leadMul;
      _src.sizeZeta = leadZeta;
      _src.anchorDelay = a.followDelay;

      _dst.anchor = Alignment.center;
      _dst.snapTo(_inside(
        to,
        to.center,
        Size(to.width * a.seedScale, to.height * a.seedScale),
      ));
      _dst.aim(to);
      _dst.anchorMul = _dst.sizeMul = 3;
      _dst.anchorZeta = _dst.sizeZeta = 1;
    }

    if (swap) _elapsed = 0;
    _wake();
  }

  /// Reported by the render object, one frame after the child's natural size
  /// changes — so a child that grows a row simply grows the glass.
  void _onMeasured(Key key, Size natural) {
    if (!mounted) return;
    final bool swap = key != _measuredKey && _measuredKey != null;
    if (natural == _natural && !swap) return;
    setState(() {
      _measuredKey = key;
      _natural = natural;
      _retarget(swap: swap);
    });
  }

  @override
  void didUpdateWidget(covariant LiquidGlassMorph old) {
    super.didUpdateWidget(old);
    if (_keyOf(widget.child) != _keyOf(old.child)) {
      // Where each child is RIGHT NOW is where its next fade starts. The
      // child that was arriving is now the one leaving, from whatever it
      // had reached — nothing at all if it had not started, so it is never
      // seen. And if what comes in is the child that was on its way out, it
      // returns from where it got to instead of from zero.
      final double t = _t;
      final bool returning =
          _srcChild != null && _keyOf(widget.child) == _keyOf(_srcChild);
      final double leavingAt = _dstLevel(t);
      final double returningAt = _srcLevel(t);
      _srcFrom = leavingAt;
      _dstFrom = returning ? returningAt : 0;
      // Each child keeps the rect it is drawn in: the one leaving stays
      // pinned where it was arriving, and one coming back returns to where
      // it was leaving from. Neither waits for the measurement.
      final Rect was = _srcPin;
      _srcPin = _target;
      if (returning) _target = was;
      // The clock restarts NOW, not when the measurement lands a frame
      // later — read at rest (t = 1) it would paint the incoming child
      // fully opaque inside the OLD outline for that gap frame.
      _elapsed = 0;
      // The old child keeps showing — in the source blob — until the new
      // one has been measured and the morph is under way.
      _srcChild = old.child;
      // A new child needs measuring before there is anything to aim at; the
      // report lands next frame and retargets then.
      if (widget.width != null && widget.height != null) {
        _measuredKey = _keyOf(widget.child);
        _retarget(swap: true);
      }
      return;
    }
    final bool overridesChanged =
        widget.width != old.width || widget.height != old.height;
    if (overridesChanged || !_sameShape(widget.style.shape, _dst.shape)) {
      _retarget(swap: false);
    }
  }

  void _wake() {
    if (!_ticker.isActive) {
      // Ticker.elapsed restarts at zero, so the baseline must too — otherwise
      // the first step after a pause integrates the whole gap at once.
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    // A dropped frame or a resumed app must not launch the outline across the
    // screen in a single integration.
    if (dt > 1 / 30) dt = 1 / 30;

    _src.step(dt, _m.stiffness, _m.damping);
    _dst.step(dt, _m.stiffness, _m.damping);
    _elapsed += dt;

    // The content swap can outlast the springs on a calm motion, so the
    // ticker runs until both are done.
    if (_src.moving || _dst.moving || _elapsed < _m.duration) {
      setState(() {});
      return;
    }
    // Settled. Land exactly on the target, put the source back on top of the
    // destination so the union is the plain shape, and stop asking for
    // frames rather than waking the engine every vsync to find nothing to do.
    _dst.snapTo(_target);
    _src.copyFrom(_dst);
    _ticker.stop();
    setState(() {});
    widget.onEnd?.call();
  }

  /// The neck radius this frame, from how far APART the two blobs are:
  /// nothing while they coincide (the start of a grow, the end of a shrink,
  /// rest), full once they have parted. Keyed to geometry rather than time,
  /// so the union keeps filleting whatever is left of the source for as long
  /// as it is anywhere near an edge. Two coincident outlines under a radius
  /// `k` sit `k/4` outside the true one, which is why coincident means zero.
  double? get _smoothness {
    if (_idle || widget.smoothness <= 0) return null;
    final Rect a = _src.rect;
    final Rect b = _dst.rect;
    final double sep = (a.center - b.center).distance +
        0.5 * ((a.width - b.width).abs() + (a.height - b.height).abs());
    final double x = (sep / math.max(_a.neckRamp, 1)).clamp(0.0, 1.0);
    final double s = x * x * (3 - 2 * x);
    return s < 0.01 ? null : widget.smoothness * s;
  }

  /// 0 at the smallest the glass has been, 1 at the largest: what the
  /// material's thickness follows. A glass that has only ever been one size
  /// is thin.
  double get _thickness {
    final Rect r = _dst.rect;
    final double area = r.width * r.height;
    if (_bigArea - _smallArea < 1) return 0;
    return ((area - _smallArea) / (_bigArea - _smallArea)).clamp(0.0, 1.0);
  }

  /// The group's material this frame: the caller's, with blur and refraction
  /// thickened by how large the glass currently is.
  LiquidGlassStyle _material() {
    final LiquidGlassMorphAdvanced a = _a;
    final double f = _thickness;
    final LiquidGlassStyle s = widget.style;
    if (f <= 0 || (a.thickenBlur <= 0 && a.thickenRefraction <= 0)) return s;

    final LiquidGlassBlur blur = s.appearance.blur;
    final double bm = 1 + a.thickenBlur * f;
    LiquidGlassRefraction refraction = s.refraction;
    final LiquidGlassRefractionType? type = refraction.refractionType;
    if (type is OpticalRefraction && a.thickenRefraction > 0) {
      final double rm = 1 + a.thickenRefraction * f;
      refraction = LiquidGlassRefraction(
        distortion: refraction.distortion,
        distortionWidth: refraction.distortionWidth,
        magnification: refraction.magnification,
        chromaticAberration: refraction.chromaticAberration,
        refractionMode: refraction.refractionMode,
        diagonalFlip: refraction.diagonalFlip,
        refractionType: OpticalRefraction(
          refraction: type.refraction,
          refractionWidth: type.refractionWidth * rm,
          depth: (type.depth * rm).clamp(0.0, 1.0),
        ),
      );
    }
    return s.copyWith(
      appearance: s.appearance.copyWith(
        blur:
            LiquidGlassBlur(sigmaX: blur.sigmaX * bm, sigmaY: blur.sigmaY * bm),
      ),
      refraction: refraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // Unbounded means there is no box to anchor inside, so the widget
        // shrinks to the glass and the alignment has nothing to act on.
        final Size glassSize = _targetSize ?? Size.zero;
        final Size field = Size(
          c.hasBoundedWidth ? c.maxWidth : glassSize.width,
          c.hasBoundedHeight ? c.maxHeight : glassSize.height,
        );
        if (field != _field) {
          _field = field;
          // The box moved under us: the anchors are stale. At rest that is
          // a snap; mid-flight the springs simply re-aim.
          if (_seeded) {
            final Rect to = _place(_targetSize!);
            _target = to;
            if (_idle) {
              _dst.snapTo(to);
              _src.copyFrom(_dst);
            } else {
              _dst.aim(to);
              if (_src.w.target > 2) _src.aim(to);
            }
          }
        }

        final Rect srcRect = _src.rect;
        final Rect dstRect = _dst.rect;
        final double t = _t;
        // The blender paints only inside its own bounds, and a blob passes
        // the field's edge whenever it overshoots its anchor or the neck
        // bulges past it. So the blender is bigger than the field by a
        // margin, and the blobs are shifted into it.
        final Offset shift = Offset(_overflow, _overflow);

        if (!_m.blended) {
          // One lens at the travelling outline, both children inside it:
          // the new one pinned to where the glass is going, the old one to
          // where it came from, each clipped by the outline as it passes.
          final Widget? incoming = _dstContent(c, dstRect, t);
          final Widget? outgoing = _srcContent(c, dstRect, t);
          return SizedBox.fromSize(
            size: field,
            child: Opacity(
              opacity: _seeded ? 1 : 0,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fromRect(
                    rect: dstRect,
                    child: LiquidGlassLens(
                      style: _material().copyWith(
                        shape: _shapeFor(_dst, dstRect),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          if (incoming != null) incoming,
                          if (outgoing != null) outgoing,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox.fromSize(
          size: field,
          child: Opacity(
            // Not painted until the first measurement lands, one frame after
            // mount. `Opacity` rather than removing it, because the child has
            // to be in the tree to be measured at all.
            opacity: _seeded ? 1 : 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: -_overflow,
                  top: -_overflow,
                  right: -_overflow,
                  bottom: -_overflow,
                  child: LiquidGlassBlender(
                    style: _material(),
                    smoothness: _smoothness,
                    debugClipBounds: widget.debugClipBounds,
                    // Both blobs opt OUT of adaptivity, and that is load
                    // bearing. A lens with a verdict of its own publishes
                    // it to the blender as a member tint, which OVERRIDES
                    // the group's — so two members left adaptive would
                    // paint an enclosing `LiquidGlassAdaptiveArea`'s
                    // palette and silently discard the one the caller put
                    // in `style`. A morph is one surface: the group holds
                    // the verdict, the blobs are only its geometry.
                    // Content still adapts — the group publishes the ink
                    // as an ambient IconTheme/DefaultTextStyle.
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        // The destination blob, underneath: its content is
                        // the new child, pinned to where the glass will
                        // finally be.
                        Positioned.fromRect(
                          rect: dstRect.shift(shift),
                          child: LiquidGlassLens(
                            style: LiquidGlassStyle(
                              shape: _shapeFor(_dst, dstRect),
                              adaptivity: LiquidGlassAdaptivity.none,
                            ),
                            child: _dstContent(c, dstRect, t),
                          ),
                        ),
                        // The source blob, on top: the old child, in the
                        // blob that is carrying it away.
                        Positioned.fromRect(
                          rect: srcRect.shift(shift),
                          child: LiquidGlassLens(
                            style: LiquidGlassStyle(
                              shape: _shapeFor(_src, srcRect),
                              adaptivity: LiquidGlassAdaptivity.none,
                            ),
                            child: _srcContent(c, srcRect, t),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The blob's shape at its current size. A blob with no shape is a
  /// capsule, so its radius is half its short side this frame; a blob with
  /// one keeps the curve and radius it was given, and the blender clamps the
  /// radius to what fits.
  LiquidGlassShape _shapeFor(_Blob b, Rect r) {
    final LiquidGlassShape s = b.shape ?? const LiquidGlassShape();
    final double half = math.min(r.width, r.height) / 2;
    return LiquidGlassShape(
      cornerStyle: s.cornerStyle,
      cornerRadius: b.shape == null ? half : math.min(s.cornerRadius, half),
      clipQuality: s.clipQuality,
      borderWidth: s.borderWidth,
      borderColor: s.borderColor,
      lightIntensity: s.lightIntensity,
      lightColor: s.lightColor,
      lightDirection: s.lightDirection,
      lightMode: s.lightMode,
      borderType: s.borderType,
    );
  }

  /// Direction of travel, unit length, for the content slide.
  Offset get _travel {
    final Offset d = _target.center - _origin.center;
    return d.distance < 1 ? Offset.zero : d / d.distance;
  }

  /// The new child: measured at its natural size, pinned to the destination
  /// rect (or riding the blob), and materialised — blur, fade, scale around
  /// the anchor — between `contentInStart` and `contentInEnd` of the swap.
  Widget? _dstContent(BoxConstraints c, Rect blob, double t) {
    final Widget? child = widget.child;
    if (child == null) return null;
    final LiquidGlassMorphAdvanced a = _a;
    final double k = _dstLevel(t);
    final Offset pinned = _target.topLeft - blob.topLeft;
    final Offset riding = Offset(
      (blob.width - _target.width) / 2,
      (blob.height - _target.height) / 2,
    );
    final Offset slide = _travel * (-a.contentSlide * (1 - k));
    return _MorphMeasure(
      // Keyed on the child, so a new child gets a fresh measurer and reports
      // even when it happens to be the same size as the last one.
      key: _keyOf(child),
      measure: _measureConstraints(c),
      offset: Offset.lerp(pinned, riding, a.contentFollow)! + slide,
      onMeasured: (Size s) => _onMeasured(_keyOf(child), s),
      child: _materialise(
        child,
        opacity: k,
        scale: ui.lerpDouble(a.newScaleFrom, 1, k)!,
        blur: a.contentBlur * (1 - k),
        alignment: _anchor,
      ),
    );
  }

  /// The old child, gone by [LiquidGlassMorphAdvanced.contentOutEnd] of the
  /// swap: blurred, faded and scaled, in the blob that carries it. Not built
  /// at all once it is out — or if it never got in.
  Widget? _srcContent(BoxConstraints c, Rect blob, double t) {
    final Widget? child = _srcChild;
    final LiquidGlassMorphAdvanced a = _a;
    if (child == null) return null;
    final double level = _srcLevel(t);
    if (level <= 0.001) return null;
    final double k = 1 - level;
    final Offset pinned = _srcPin.topLeft - blob.topLeft;
    final Offset riding = Offset(
      (blob.width - _srcPin.width) / 2,
      (blob.height - _srcPin.height) / 2,
    );
    return _MorphMeasure(
      key: _keyOf(child),
      // The same constraints it was measured under as the live child, so it
      // does not reflow on its way out.
      measure: _measureConstraints(c),
      offset: Offset.lerp(pinned, riding, a.contentFollow),
      onMeasured: null,
      child: _materialise(
        child,
        opacity: 1 - k,
        scale: ui.lerpDouble(1, a.oldScaleTo, k)!,
        blur: a.contentBlur * k,
        alignment: _anchor,
      ),
    );
  }

  /// Apple's content transition in one place: opacity, a little scale, and
  /// a blur that is at its strongest exactly when the content is faintest.
  Widget _materialise(
    Widget child, {
    required double opacity,
    required double scale,
    required double blur,
    required Alignment alignment,
  }) {
    Widget w = child;
    if (blur > 0.2) {
      w = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: w,
      );
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(scale: scale, alignment: alignment, child: w),
    );
  }
}

/// Lays its child out at its NATURAL size, reports that size, and then presents
/// it at [offset] inside a box of someone else's choosing.
///
/// The split is the point. The child is measured under constraints that do not
/// move, so the target never chases the animation; the box it is shown in is
/// the animating one, and the child simply overflows it and is clipped by the
/// lens. That is what lets content be pinned rather than re-laid-out on every
/// frame of a morph.
class _MorphMeasure extends SingleChildRenderObjectWidget {
  const _MorphMeasure({
    super.key,
    required this.measure,
    required this.offset,
    required this.onMeasured,
    required Widget super.child,
  });

  /// What the child is laid out under. Independent of the box it is shown in.
  final BoxConstraints measure;

  /// Where the child's top-left sits inside the box. Null centres it.
  final Offset? offset;

  final ValueChanged<Size>? onMeasured;

  @override
  _RenderMorphMeasure createRenderObject(BuildContext context) =>
      _RenderMorphMeasure(
        measure: measure,
        offset: offset,
        onMeasured: onMeasured,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderMorphMeasure ro) {
    ro
      ..measure = measure
      ..offset = offset
      ..onMeasured = onMeasured;
  }
}

class _RenderMorphMeasure extends RenderShiftedBox {
  _RenderMorphMeasure({
    required BoxConstraints measure,
    required Offset? offset,
    required this.onMeasured,
  })  : _measure = measure,
        _offset = offset,
        super(null);

  BoxConstraints _measure;
  set measure(BoxConstraints v) {
    if (v == _measure) return;
    _measure = v;
    markNeedsLayout();
  }

  Offset? _offset;
  set offset(Offset? v) {
    if (v == _offset) return;
    _offset = v;
    markNeedsLayout();
  }

  ValueChanged<Size>? onMeasured;

  /// The last size handed to [onMeasured], so a morph — which relayouts this
  /// box every frame — reports only when the CHILD actually changed size.
  Size? _reported;

  @override
  void performLayout() {
    size = constraints.biggest.isFinite
        ? constraints.biggest
        : constraints.smallest;
    final RenderBox? c = child;
    if (c == null) return;

    // Measured under constraints that do not move. Flutter skips the child's
    // layout entirely while these are unchanged and it is not dirty, so an
    // animating morph costs one offset update per frame, not a relayout.
    c.layout(_measure, parentUsesSize: true);
    final Size natural = c.size;

    (c.parentData! as BoxParentData).offset = _offset ??
        Alignment.center.inscribe(natural, Offset.zero & size).topLeft;

    final ValueChanged<Size>? report = onMeasured;
    if (report != null && natural != _reported) {
      _reported = natural;
      // Reporting from inside layout would mean a setState during layout.
      SchedulerBinding.instance.addPostFrameCallback((_) => report(natural));
    }
  }
}
