import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens_scope.dart';
import '../utils/liquid_glass_adaptivity.dart';
import '../utils/liquid_glass_adaptivity_driver.dart';
import 'liquid_glass_adaptive_area.dart';

/// Which screen edge a [LiquidGlassScrollEdge] hugs. The fade is fully
/// opaque at that edge and dissolves to transparent toward the content.
enum LiquidGlassEdge { top, bottom }

/// How a [LiquidGlassScrollEdge] layers its backdrop blur. Both styles
/// paint the same tint ramp; only the blur differs.
enum LiquidGlassScrollEdgeStyle {
  /// The blur is strongest at the edge and fades to nothing by the
  /// inner boundary, so content eases toward sharp instead of falling
  /// off a wall. Seamless on every backend. The default.
  ///
  /// ONE backdrop pass, feathered from the inside by a `dstIn` ramp: the
  /// blur's alpha follows [LiquidGlassScrollEdge.blurCurve], and because
  /// a backdrop layer composites over the untouched page, whatever alpha
  /// the ramp gives up comes back as sharp content. No clip boundary, so
  /// no seam — for the price of the single pass [hard] costs.
  soft,

  /// The same single pass, UNFEATHERED: one uniform sigma across the
  /// whole band. The blur then stops dead where the band does, leaving a
  /// visible seam against unblurred content. Costs exactly what [soft]
  /// costs; the only difference is the ramp.
  hard,
}

/// iOS-style scroll edge treatment: a **fading dim band** pinned over a
/// scrollable's edge so floating glass elements (nav pills, app bars)
/// stay legible over whatever scrolls beneath — the "subtle dimming"
/// variant of Apple's scroll edge effect, without any blur of its own.
///
/// Place it inside a `LiquidGlassView`'s `child`, pinned to an edge,
/// *under* your floating glass elements:
///
/// ```dart
/// Positioned(
///   left: 0, right: 0, bottom: 0, height: 140,
///   child: LiquidGlassScrollEdge(
///     edge: LiquidGlassEdge.bottom,
///     adaptivity: LiquidGlassAdaptivity(...),
///   ),
/// )
/// ```
///
/// **Adaptivity (optional).** With [adaptivity] set and an ancestor
/// `LiquidGlassView`, the band registers with the view's shared
/// luminance sampler (same one `LiquidGlassLens` uses — no extra
/// captures) and animates between two tints: `glassColorOnDark` while
/// the background under the band is dark, `glassColorOnLight` while it
/// is light. A [child] placed in the band gets the matching
/// `contentColorOn*` through `IconTheme`/`DefaultTextStyle`, exactly
/// like the lens. Without a view, the verdict falls back to
/// `adaptivity.permanentBrightness`, then platform brightness. With
/// [adaptivity] left `null` the band is a static fade of [color] — no
/// sampling, no animation, no cost beyond one gradient.
///
/// **Blur.** [blur] blurs the backdrop under the band as exactly **one
/// `BackdropFilter`** — one backdrop read, one blur pass, at any sigma
/// and on every backend. It defaults to `5`; pass `0` to switch it off,
/// and then no filter exists in the tree at all.
///
/// [style] decides only whether that pass is feathered:
/// [LiquidGlassScrollEdgeStyle.soft] — the default — fades the blur out
/// across the band with a `dstIn` ramp so it meets sharp content without
/// a seam, while [LiquidGlassScrollEdgeStyle.hard] leaves it uniform and
/// ends on a line. Neither costs more than the other.
///
/// [curve] shapes the tint's falloff; [blurCurve] shapes the blur's, and
/// by default keeps nearly all of it across the first half of the band
/// so chrome stays legible over what passes under it.
///
/// The fade itself never blocks touches: scrolls and taps pass through
/// to the content beneath. Only [child] is hit-testable.
class LiquidGlassScrollEdge extends StatefulWidget {
  /// The screen edge the fade hugs (full strength there, transparent
  /// toward the content).
  final LiquidGlassEdge edge;

  /// Band height. When `null` the band fills its parent's constraints
  /// (e.g. a `Positioned` with `height:`).
  final double? height;

  /// Fade tint when [adaptivity] is `null` (static mode). The alpha is
  /// the peak opacity at the very edge.
  final Color color;

  /// Optional adaptive palettes. `glassColorOnDark`/`glassColorOnLight`
  /// become the fade tint; `contentColorOn*` tint [child]. `null`
  /// (default) = static fade, feature fully off.
  final LiquidGlassAdaptivity? adaptivity;

  /// Backdrop blur sigma applied under the fade, in logical pixels.
  ///
  /// Defaults to `5`: a scroll edge exists to keep chrome legible over
  /// whatever passes under it, and a dim alone rarely does that over a
  /// busy photograph. Pass `0` to switch the blur off entirely — then no
  /// `BackdropFilter` exists in the tree at all and the band is a pure
  /// tint ramp.
  final double blur;

  /// Shape of the TINT falloff from the edge (0 = at the edge) to the
  /// inner boundary (1 = fully transparent). The blur has its own —
  /// see [blurCurve].
  final Curve curve;

  /// The blur's default falloff: `Curves.easeInQuart`, which **keeps
  /// nearly all of the blur across the first half of the band and spends
  /// the release over the second.**
  ///
  /// A scroll edge exists so chrome stays legible over what scrolls
  /// under it, and the chrome occupies the stretch nearest the edge — so
  /// the blur has to be near full strength there, not already on its way
  /// down. Quartic easing gives that for free: `t^4` has barely moved by
  /// mid-band (94% of the sigma is still there at `0.5`, 76% at `0.7`),
  /// then falls away over the rest.
  ///
  /// It trades a softer hold for a firmer landing than a held [Interval]
  /// would: about a third of the sigma is still present at `0.9` and the
  /// curve is at its steepest as it reaches the boundary. Over a busy
  /// feed that reads as depth; over flat content it can read as an edge,
  /// which is what [blurCurve] is there to retune.
  static const Curve defaultBlurCurve = Curves.easeInQuart;

  /// Shape of the BLUR falloff — see [defaultBlurCurve].
  ///
  /// Read it as "how much blur is left at this depth": the value is
  /// inverted, so a curve that rises late holds the blur late. Pass
  /// [curve] here to put the blur back on the tint's profile, a wider
  /// [Interval] to hold it even longer, or `Curves.easeInOut` for the
  /// falloff to start immediately.
  ///
  /// Separate from [curve] because the dim and the blur want different
  /// profiles — a tint that lingers reads as murk, a blur that lingers
  /// reads as depth.
  final Curve blurCurve;

  /// How the band meets the content — see [LiquidGlassScrollEdgeStyle].
  /// Defaults to [LiquidGlassScrollEdgeStyle.soft].
  final LiquidGlassScrollEdgeStyle style;

  /// Optional content pinned inside the band (title, actions). Adapts
  /// automatically when [adaptivity] is set; hit-testable, unlike the
  /// fade itself.
  final Widget? child;

  const LiquidGlassScrollEdge({
    super.key,
    this.edge = LiquidGlassEdge.bottom,
    this.height,
    this.color = const Color(0x8A000000),
    this.adaptivity,
    this.blur = 5,
    this.curve = Curves.easeInOut,
    this.blurCurve = defaultBlurCurve,
    this.style = LiquidGlassScrollEdgeStyle.soft,
    this.child,
  });

  @override
  State<LiquidGlassScrollEdge> createState() => _LiquidGlassScrollEdgeState();
}

class _LiquidGlassScrollEdgeState extends State<LiquidGlassScrollEdge>
    with TickerProviderStateMixin, LiquidGlassAdaptiveClient {
  /// The shared verdict machine (see [LiquidGlassAdaptivityDriver]) —
  /// this widget only samples for it and paints from it.
  late final LiquidGlassAdaptivityDriver _driver =
      LiquidGlassAdaptivityDriver(vsync: this);

  /// Registration bookkeeping against the view's sampler. The register
  /// tear-off doubles as the identity of "who we're registered with".
  void Function(LiquidGlassAdaptiveClient)? _registeredWith;
  void Function(LiquidGlassAdaptiveClient)? _unregister;

  @override
  void dispose() {
    _unregister?.call(this);
    _unregister = null;
    _registeredWith = null;
    _driver.dispose();
    super.dispose();
  }

  /// The falloff the BLUR follows.
  Curve get _blurCurve => widget.blurCurve;

  /// Keeps registration with the view's sampler in sync with the
  /// adaptivity config. Safe to call every build.
  /// The adaptivity controller flipped: rebuild so sampling
  /// registration and the driver's verdict source follow the switch.
  void _adaptResync() {
    if (mounted) setState(() {});
  }

  void _syncRegistration({
    required void Function(LiquidGlassAdaptiveClient)? register,
    required void Function(LiquidGlassAdaptiveClient)? unregister,
  }) {
    if (!identical(register, _registeredWith)) {
      _unregister?.call(this);
      _unregister = null;
      _registeredWith = register;
      if (register != null) {
        register(this);
        _unregister = unregister;
      }
    }
  }

  @override
  Rect? adaptiveRegion(RenderBox backgroundBox) {
    if (!mounted) return null;
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    try {
      final Offset topLeft =
          ro.localToGlobal(Offset.zero, ancestor: backgroundBox);
      return topLeft & ro.size;
    } catch (_) {
      return null;
    }
  }

  @override
  void onAdaptiveSample(LiquidGlassBackdropSample sample) {
    if (!mounted) return;
    _driver.onBackdropSample(sample);
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassLensScope? scope = LiquidGlassLensScope.maybeOf(context);

    // Adaptivity precedence: own config, else the enclosing area's —
    // and `LiquidGlassAdaptivity.none` opts out of both. The verdict
    // source: manual override → explicit link → enclosing area's link →
    // own sampling → platform brightness.
    final LiquidGlassAdaptiveAreaScope? areaScope =
        LiquidGlassAdaptiveArea.maybeOf(context);
    final LiquidGlassAdaptivity? resolved =
        widget.adaptivity ?? areaScope?.adaptivity;
    final LiquidGlassAdaptivity? adaptivity =
        (resolved?.isNone ?? false) ? null : resolved;
    final LiquidGlassAdaptivityLink? follow =
        adaptivity == null ? null : (adaptivity.link ?? areaScope?.link);
    // A host's sampler redirect (e.g. the nav bar's outer view routing
    // clients to its inner pre-glass sampler) wins over the enclosing
    // view's own sampler.
    final LiquidGlassAdaptiveSamplerScope? samplerScope =
        LiquidGlassAdaptiveSamplerScope.maybeOf(context);
    final void Function(LiquidGlassAdaptiveClient)? adaptRegister =
        samplerScope?.register ?? scope?.registerAdaptiveClient;
    final void Function(LiquidGlassAdaptiveClient)? adaptUnregister =
        samplerScope?.unregister ?? scope?.unregisterAdaptiveClient;
    final bool wantSampling = _driver.samplingWanted(adaptivity,
        following: follow != null, canRegister: adaptRegister != null);

    _syncRegistration(
        register: wantSampling ? adaptRegister : null,
        unregister: adaptUnregister);
    _driver.onResync = _adaptResync;
    _driver.sync(
      adaptivity,
      follow: follow,
      canSample: adaptRegister != null,
      fallbackBrightness: liquidGlassFallbackBrightness(context, adaptivity),
    );
    if (adaptivity == null) {
      return _buildBand(context, null);
    }

    return AnimatedBuilder(
      animation: _driver.listenable!,
      builder: (context, _) => _buildBand(context, adaptivity),
    );
  }

  /// The band itself: the tint ramp, over however many blur passes the
  /// style asks for.
  ///
  /// Both styles share the tint — they differ only in how the backdrop
  /// blur is layered underneath it.
  Widget _buildStyled(BuildContext context, Color fade, bool top) {
    final Widget tint = DecoratedBox(
      decoration:
          BoxDecoration(gradient: _rampGradient(fade, top, widget.curve)),
    );

    if (widget.blur <= 0) return tint;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _blurPass(top),
        tint,
      ],
    );
  }

  /// A gradient in [color] whose alpha follows [falloff] inverted: full
  /// at the hugged edge, gone at the far end of whatever box it paints.
  /// Shapes the tint (with [curve]) and the blur's feather mask (with
  /// [blurCurve]).
  LinearGradient _rampGradient(Color color, bool top, Curve falloff) {
    const int stopsCount = 8;
    final List<double> stops = <double>[];
    final List<Color> colors = <Color>[];
    for (int i = 0; i < stopsCount; i++) {
      final double t = i / (stopsCount - 1);
      stops.add(t);
      final double k = 1.0 - falloff.transform(t);
      colors.add(color.withValues(alpha: color.a * k));
    }
    return LinearGradient(
      begin: top ? Alignment.topCenter : Alignment.bottomCenter,
      end: top ? Alignment.bottomCenter : Alignment.topCenter,
      colors: colors,
      stops: stops,
    );
  }

  /// The band's blur: **one** `BackdropFilter`, whatever the sigma and
  /// whatever the backend.
  ///
  /// [LiquidGlassScrollEdgeStyle.soft] feathers it from the INSIDE with a
  /// `dstIn` gradient painted as the filter's own child. The child draws
  /// INTO the layer the filtered backdrop already occupies, so `dstIn`
  /// multiplies that blur's alpha by the ramp — and because a backdrop
  /// layer composites OVER the untouched page beneath it, whatever alpha
  /// the ramp takes away comes back as sharp content. No clip boundary,
  /// so no seam to hide.
  ///
  /// This is the one masking route that does not break the filter.
  /// `ShaderMask`, `Opacity` and `ColorFiltered` all push a saveLayer
  /// AROUND the `BackdropFilter`, which then reads that empty layer as
  /// its backdrop and blurs nothing at all. Painting inside the layer
  /// instead of wrapping it is the whole difference.
  ///
  /// [LiquidGlassScrollEdgeStyle.hard] takes the same pass without the
  /// ramp: one uniform sigma, ending on the line where the clip does.
  ///
  /// The `ClipRect` is mandatory — a `BackdropFilter` is unbounded, so
  /// without one the blur runs over the entire window.
  Widget _blurPass(bool top) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: widget.style == LiquidGlassScrollEdgeStyle.soft
            ? _featherMask(top)
            : const SizedBox.expand(),
      ),
    );
  }

  /// Cache for [_featherMask]. The mask never varies for a given band —
  /// same edge, same curve, same black — so without this an adaptive
  /// band rebuilt an eight-stop gradient on every frame of a palette
  /// flip.
  Widget? _featherCache;
  bool? _featherCacheTop;
  Curve? _featherCacheCurve;

  /// The `dstIn` ramp the pass paints into its own layer to feather
  /// itself from the inside.
  Widget _featherMask(bool top) {
    final Curve curve = _blurCurve;
    final Widget? cached = _featherCache;
    if (cached != null && _featherCacheTop == top && _featherCacheCurve == curve) {
      return cached;
    }
    _featherCacheTop = top;
    _featherCacheCurve = curve;
    return _featherCache = DecoratedBox(
      decoration: BoxDecoration(
        // Only the ramp's ALPHA matters to `dstIn`; the colour never
        // reaches the screen.
        gradient: _rampGradient(const Color(0xFF000000), top, curve),
        backgroundBlendMode: BlendMode.dstIn,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildBand(BuildContext context, LiquidGlassAdaptivity? adaptivity) {
    Color fade = widget.color;
    Widget? child = widget.child;
    if (adaptivity != null) {
      fade = _driver.glassColor(adaptivity);
      final Color content = _driver.contentColor(adaptivity);
      if (child != null) {
        child = IconTheme(
          data: IconTheme.of(context).copyWith(color: content),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: content),
            child: child,
          ),
        );
      }
    }

    final bool top = widget.edge == LiquidGlassEdge.top;
    final Widget band = _buildStyled(context, fade, top);

    // The fade never eats touches; only the child is hit-testable.
    final Widget result = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: band),
        if (child != null) child,
      ],
    );

    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: result,
      );
    }
    return result;
  }
}
