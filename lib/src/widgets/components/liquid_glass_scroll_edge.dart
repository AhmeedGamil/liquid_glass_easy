import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  /// Built from overlapping backdrop passes feathered from the inside by
  /// a `dstIn` ramp, compounding in quadrature — the falloff sampled at
  /// a few discrete levels. The same on every backend by design.
  /// [LiquidGlassScrollEdge.useShaderBlur] swaps in a fragment shader
  /// with a continuously varying radius where the engine has one.
  soft,

  /// ONE uniform pass across the whole band. Cheaper, but the blur
  /// stops dead where the band does, leaving a visible seam against
  /// unblurred content. Identical on every backend — a flat blur needs
  /// no shader.
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
/// **Blur (optional).** [blur] > 0 blurs the backdrop under the band.
/// [style] decides how it is layered:
/// [LiquidGlassScrollEdgeStyle.hard] uses one uniform pass (one
/// backdrop read, blur ends on a line), [LiquidGlassScrollEdgeStyle
/// .soft] — the default — fades the blur out across the band so it
/// meets sharp content without a seam. At the default `0` no filter
/// exists in the tree at all.
///
/// [curve] shapes the tint's falloff; [blurCurve] shapes the blur's,
/// and holds it at full strength across the first half of the band by
/// default so chrome stays legible over what passes under it.
///
/// The soft fade is a ladder of overlapping `dstIn`-feathered backdrop
/// passes — the falloff at three discrete levels, three reads, the same
/// on every backend. [useShaderBlur] opts into a **fragment shader**
/// with a continuously varying radius instead, where the engine can
/// read the live backdrop (Impeller only, one read).
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

  /// Backdrop blur sigma applied under the fade. `0` (default) = no
  /// `BackdropFilter` at all.
  final double blur;

  /// Shape of the TINT falloff from the edge (0 = at the edge) to the
  /// inner boundary (1 = fully transparent). The blur has its own —
  /// see [blurCurve].
  final Curve curve;

  /// The blur's default falloff: **full strength across the first HALF
  /// of the band, then an `easeInOut` release over the rest.**
  ///
  /// A scroll edge exists so chrome stays legible over what scrolls
  /// under it, and the chrome occupies the stretch nearest the edge —
  /// so the blur has to be at full strength there, not already on its
  /// way down. A plain `easeInOut` is at half its sigma by mid-band,
  /// which reads as the blur giving up before the band ends.
  ///
  /// Holding it later than this costs a steeper landing: the release
  /// has less band left to happen in, and past roughly `0.6` the drop
  /// starts reading as the edge the fade exists to avoid.
  static const Curve defaultBlurCurve =
      Interval(0.5, 1.0, curve: Curves.easeInOut);

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

  /// Opts [LiquidGlassScrollEdgeStyle.soft] into the progressive-blur
  /// fragment shader. **Off by default: every backend runs the same
  /// feathered ladder**, so a band looks the same everywhere it renders.
  ///
  /// `true` asks for the shader, which needs `ImageFilter.shader` and so
  /// only ever arrives on Impeller — on Skia and the web the band takes
  /// the ladder regardless, and asking is never an error. What it buys
  /// is a radius that varies per pixel instead of at three levels, in
  /// one backdrop read instead of three.
  ///
  /// Ignored by [LiquidGlassScrollEdgeStyle.hard]: a flat blur is
  /// exactly what `ImageFilter.blur` already does, faster.
  final bool useShaderBlur;

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
    this.blur = 0,
    this.curve = Curves.easeInOut,
    this.blurCurve = defaultBlurCurve,
    this.style = LiquidGlassScrollEdgeStyle.soft,
    this.useShaderBlur = false,
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

  /// This band's own instance of the progressive-blur program. Null
  /// until the program has compiled (or forever, off Impeller).
  ui.FragmentShader? _blurShader;
  bool _blurShaderPending = false;

  @override
  void dispose() {
    _unregister?.call(this);
    _unregister = null;
    _registeredWith = null;
    _blurShader?.dispose();
    _blurShader = null;
    _driver.dispose();
    super.dispose();
  }

  /// The progressive-blur shader, or null when this band should not use
  /// it — wrong style, not opted in, engine without `ImageFilter.shader`,
  /// or the program still compiling. Null is never a failure: the ladder
  /// covers every one of those cases, so the band is blurred on its
  /// first frame either way.
  ui.FragmentShader? _resolveBlurShader() {
    if (widget.style != LiquidGlassScrollEdgeStyle.soft) return null;
    if (!widget.useShaderBlur) return null;
    if (!ui.ImageFilter.isShaderFilterSupported) return null;
    if (_blurShader != null) return _blurShader;
    final ui.FragmentProgram? ready = _ScrollEdgeBlurProgram.program;
    if (ready != null) return _blurShader = ready.fragmentShader();
    if (!_blurShaderPending) {
      _blurShaderPending = true;
      _ScrollEdgeBlurProgram.ensureLoaded().then((ui.FragmentProgram program) {
        _blurShaderPending = false;
        if (!mounted) return;
        setState(() => _blurShader = program.fragmentShader());
      }, onError: (Object _) => _blurShaderPending = false);
    }
    return null;
  }

  /// The falloff the BLUR follows.
  Curve get _blurCurve => widget.blurCurve;

  /// [_blurCurve] flattened into the 16 stops the shader interpolates
  /// between — GLSL has no Dart [Curve].
  List<double> _rampStops() => List<double>.generate(
        _kRampStops,
        (int i) => _blurCurve
            .transform(i / (_kRampStops - 1))
            .clamp(0.0, 1.0)
            .toDouble(),
        growable: false,
      );

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
      platformBrightness:
          MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
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

    // One pass, radius varying continuously with depth into the band.
    final ui.FragmentShader? shader = _resolveBlurShader();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (shader != null)
          // A `BackdropFilter` is unbounded without a clip: the shader
          // would run over the whole window instead of the band.
          ClipRect(
            child: _ScrollEdgeShaderBlur(
              shader: shader,
              sigma: widget.blur,
              top: top,
              ramp: _rampStops(),
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          )
        else
          ..._maskedPasses(top),
        tint,
      ],
    );
  }

  /// A gradient in [color] whose alpha follows [falloff] inverted: full
  /// at the hugged edge, gone at the far end of whatever box it paints.
  /// Shapes the tint (with [curve]) and every blur mask (with
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

  /// The finest rung's share of [blur] — the floor of the ladder.
  /// Deliberately small: that rung is the only one dissolving against
  /// the SHARP page, and a fine blur leaves no crisp detail to show
  /// through the dissolve.
  static const double _kLevelFloor = 0.34;

  /// How many blur levels the ladder has. Each is one backdrop read and
  /// one more rung between full blur and sharp. Three is where the rungs
  /// stop reading as rungs on a normal band; raising it buys diminishing
  /// smoothness at a full backdrop read each, and the backends that need
  /// this ladder are the ones that can least afford one.
  static const int _kLevels = 3;

  /// Under this the ladder is pointless — the finest rung would be a
  /// sub-pixel blur still costing a whole backdrop read.
  static const double _kMinSplitBlur = 1.5;

  /// The depth at which the blur ramp has fallen to [level] of full.
  /// A rung is spent there: everything below it already supplies that
  /// much blur, so it hands over and stops.
  double _depthWhereBlurFalls(double level) {
    final Curve falloff = _blurCurve;
    final double target = 1.0 - level.clamp(0.0, 1.0);
    double lo = 0.0;
    double hi = 1.0;
    for (int i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      if (falloff.transform(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// The blur as backdrop passes feathered from the INSIDE — the route
  /// taken wherever the progressive-blur shader cannot run (Skia, web,
  /// [useShaderBlur] `false`) and always for
  /// [LiquidGlassScrollEdgeStyle.hard].
  ///
  /// The feather is a `dstIn` gradient painted as the `BackdropFilter`'s
  /// own child. The child draws INTO the layer the filtered backdrop
  /// already occupies, so `dstIn` multiplies that blur's alpha by the
  /// ramp — and because a backdrop layer composites OVER the untouched
  /// page beneath it, whatever alpha the ramp takes away comes back as
  /// sharp content. No clip boundary, so no seam to hide.
  ///
  /// This is the one masking route that does not break the filter.
  /// `ShaderMask`, `Opacity` and `ColorFiltered` all push a saveLayer
  /// AROUND the `BackdropFilter`, which then reads that empty layer as
  /// its backdrop and blurs nothing at all. Painting inside the layer
  /// instead of wrapping it is the whole difference.
  ///
  /// [LiquidGlassScrollEdgeStyle.hard] takes none of this: one uniform
  /// unmasked pass, blur ending on the line where the clip does.
  ///
  /// [LiquidGlassScrollEdgeStyle.soft] builds a LADDER of [_kLevels]
  /// passes. They all OVERLAP — each reads the ones below it, so their
  /// sigmas compound in quadrature and the rungs telescope to exactly
  /// [blur] at the edge. Cumulative blur climbs geometrically from
  /// [_kLevelFloor] to full, so the rungs are evenly spaced on the log
  /// scale the eye actually reads blur on.
  ///
  /// Each rung reaches only as far as the depth where the ramp falls to
  /// the rung beneath it, then feathers out. So every cross-fade is
  /// between ADJACENT blur levels rather than against the sharp page,
  /// which is what keeps a crisp ghost from surviving the mix.
  ///
  /// This is the shader's job done in steps: Skia has no way to vary a
  /// radius per pixel, so it approximates the same curve at [_kLevels]
  /// discrete levels and cross-fades between them. Below
  /// [_kMinSplitBlur] the ladder collapses to a single ramped pass.
  List<Widget> _maskedPasses(bool top) {
    /// One backdrop read over [reach] of the band, feathered to nothing
    /// at its inner end. `reach` 1.0 covers the whole band.
    Widget pass(double sigma, double reach, {bool feather = true}) => Align(
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1.0,
            heightFactor: reach,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: feather
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          // Only the ramp's ALPHA matters to `dstIn`;
                          // the colour never reaches the screen.
                          gradient: _rampGradient(
                              const Color(0xFF000000), top, _blurCurve),
                          backgroundBlendMode: BlendMode.dstIn,
                        ),
                        child: const SizedBox.expand(),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        );

    if (widget.style == LiquidGlassScrollEdgeStyle.hard) {
      return <Widget>[pass(widget.blur, 1.0, feather: false)];
    }
    if (widget.blur < _kMinSplitBlur) {
      return <Widget>[pass(widget.blur, 1.0)];
    }

    // Geometric ladder of CUMULATIVE blur, floor to full.
    final double ratio =
        math.pow(_kLevelFloor, 1.0 / (_kLevels - 1)).toDouble();
    final List<Widget> rungs = <Widget>[];
    double below = 0.0;
    for (int i = 0; i < _kLevels; i++) {
      final double cumulative =
          widget.blur * math.pow(ratio, _kLevels - 1 - i).toDouble();
      // Quadrature, because that is how stacked Gaussians add: this rung
      // is whatever, laid over everything below it, reaches `cumulative`.
      final double sigma =
          math.sqrt(cumulative * cumulative - below * below);
      final double reach =
          i == 0 ? 1.0 : _depthWhereBlurFalls(below / widget.blur);
      if (reach > 0.01) rungs.add(pass(sigma, reach));
      below = cumulative;
    }
    return rungs;
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

/// How many stops [LiquidGlassScrollEdge.curve] is flattened into for
/// the shader. Sixteen is finer than any falloff the eye resolves
/// across a band of a few hundred pixels.
const int _kRampStops = 16;

/// App-wide cache for the compiled progressive-blur program.
///
/// A `FragmentProgram` is expensive to compile and identical for every
/// band, so it is loaded once and shared; each band owns its own
/// `FragmentShader` instance for its uniforms. There is no per-backend
/// variant because there is no Skia variant to have: `ImageFilter
/// .shader` is Impeller-only, and off Impeller no band ever asks.
class _ScrollEdgeBlurProgram {
  _ScrollEdgeBlurProgram._();

  static const String _asset = 'lib/assets/shaders/scroll_edge_blur.frag';

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _loading;

  /// The compiled program, or null while it is still loading.
  static ui.FragmentProgram? get program => _program;

  static Future<ui.FragmentProgram> ensureLoaded() {
    final ui.FragmentProgram? ready = _program;
    if (ready != null) return Future<ui.FragmentProgram>.value(ready);
    return _loading ??= _load();
  }

  static Future<ui.FragmentProgram> _load() async {
    try {
      return _program = await _fromAsset();
    } finally {
      // Reset so a failed load (asset missing in a broken build) can be
      // retried instead of caching the failure forever.
      _loading = null;
    }
  }

  static Future<ui.FragmentProgram> _fromAsset() async {
    try {
      // Normal case: this package is a dependency of the running app,
      // so its assets live under the packages/ prefix.
      return await ui.FragmentProgram.fromAsset(
          'packages/liquid_glass_easy/$_asset');
    } catch (_) {
      // Running inside the package itself (its own widget tests), where
      // the same asset resolves without the prefix.
      return await ui.FragmentProgram.fromAsset(_asset);
    }
  }
}

/// One backdrop layer whose filter IS the progressive-blur shader.
///
/// Paints nothing itself — the band's tint is a sibling above it. Must
/// be clipped by an ancestor: a `BackdropFilter` is unbounded, so
/// without a clip the shader runs over the entire window.
class _ScrollEdgeShaderBlur extends LeafRenderObjectWidget {
  /// This band's shader instance. Its uniforms are packed at paint
  /// time, so no two bands may share one.
  final ui.FragmentShader shader;

  /// Blur sigma at the hugged edge, in logical pixels.
  final double sigma;

  /// Whether the band hugs the top edge (blur strongest at its top).
  final bool top;

  /// [LiquidGlassScrollEdge.curve] as [_kRampStops] stops.
  final List<double> ramp;

  final double devicePixelRatio;

  const _ScrollEdgeShaderBlur({
    required this.shader,
    required this.sigma,
    required this.top,
    required this.ramp,
    required this.devicePixelRatio,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScrollEdgeShaderBlur(
        shader: shader,
        sigma: sigma,
        top: top,
        ramp: ramp,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(
      BuildContext context, _RenderScrollEdgeShaderBlur renderObject) {
    renderObject
      ..shader = shader
      ..sigma = sigma
      ..top = top
      ..ramp = ramp
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderScrollEdgeShaderBlur extends RenderBox {
  _RenderScrollEdgeShaderBlur({
    required ui.FragmentShader shader,
    required double sigma,
    required bool top,
    required List<double> ramp,
    required double devicePixelRatio,
  })  : _shader = shader,
        _sigma = sigma,
        _top = top,
        _ramp = ramp,
        _devicePixelRatio = devicePixelRatio;

  ui.FragmentShader _shader;
  set shader(ui.FragmentShader value) {
    if (identical(_shader, value)) return;
    _shader = value;
    markNeedsPaint();
  }

  double _sigma;
  set sigma(double value) {
    if (_sigma == value) return;
    _sigma = value;
    markNeedsPaint();
  }

  bool _top;
  set top(bool value) {
    if (_top == value) return;
    _top = value;
    markNeedsPaint();
  }

  List<double> _ramp;
  set ramp(List<double> value) {
    if (listEquals(_ramp, value)) return;
    _ramp = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  final LayerHandle<BackdropFilterLayer> _layerHandle =
      LayerHandle<BackdropFilterLayer>();

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool get alwaysNeedsCompositing => true;

  /// The fade never eats touches — same contract as the tint above it.
  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void dispose() {
    _layerHandle.layer = null;
    super.dispose();
  }

  /// Uniforms are packed HERE, in paint, because this is the one place
  /// the band's size and its position on the screen are both final —
  /// and `ImageFilter.shader` reads `FlutterFragCoord()` in screen
  /// physical pixels, so the band rect has to be in that same space.
  void _packUniforms() {
    final double dpr = _devicePixelRatio;
    final Offset origin = localToGlobal(Offset.zero);
    int i = 0;
    // u_resolution. The engine overwrites this with the bound texture's
    // real size; the window is the honest guess if it ever stops.
    final ui.Size window =
        ui.PlatformDispatcher.instance.implicitView?.physicalSize ??
            (size * dpr);
    _shader.setFloat(i++, window.width);
    _shader.setFloat(i++, window.height);
    // u_band
    _shader.setFloat(i++, origin.dx * dpr);
    _shader.setFloat(i++, origin.dy * dpr);
    _shader.setFloat(i++, size.width * dpr);
    _shader.setFloat(i++, size.height * dpr);
    // u_config
    _shader.setFloat(i++, _sigma * dpr);
    _shader.setFloat(i++, _top ? 1.0 : 0.0);
    // u_ramp0..u_ramp3
    for (int stop = 0; stop < _kRampStops; stop++) {
      _shader.setFloat(i++, stop < _ramp.length ? _ramp[stop] : 1.0);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty || !ui.ImageFilter.isShaderFilterSupported) {
      _layerHandle.layer = null;
      return;
    }
    _packUniforms();
    final BackdropFilterLayer layer =
        _layerHandle.layer ??= BackdropFilterLayer();
    layer.filter = ui.ImageFilter.shader(_shader);
    context.pushLayer(
        layer, (PaintingContext context, Offset offset) {}, offset);
  }
}
