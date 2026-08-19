import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../src/widgets/lens/liquid_glass_lens.dart';
import '../src/widgets/liquid_glass_config.dart';
import '../src/widgets/liquid_glass_style.dart';
import '../src/widgets/utils/liquid_glass_blur.dart';
import '../src/widgets/utils/liquid_glass_shape.dart';
import '../src/widgets/utils/liquid_glass_spring.dart';

// =============================================================
// EXPERIMENTAL — component-to-component morphing.
//
// One glass body that changes what it IS: a button grows into a list, a
// capsule of icons becomes a menu panel. Not a cross-fade between two
// widgets — a single lens whose geometry, look and contents are all
// interpolated, so the glass is continuous from start to finish.
// =============================================================

/// Drives a [LiquidGlassMorph] open and closed.
///
/// The controller only holds *intent* (`isOpen`); the widget owns the
/// springs and writes the live [progress] back, so a controller can be
/// created anywhere — no `TickerProvider` needed.
class LiquidGlassMorphController extends ChangeNotifier {
  LiquidGlassMorphController({bool isOpen = false}) : _isOpen = isOpen;

  bool _isOpen;
  double _progress = 0;

  /// Whether the destination is the current target.
  bool get isOpen => _isOpen;

  /// Live morph position: `0` at the source, `1` at the destination.
  /// Springs overshoot, so this can briefly leave `[0, 1]`.
  double get progress => _progress;

  void open() => _setOpen(true);
  void close() => _setOpen(false);
  void toggle() => _setOpen(!_isOpen);

  void _setOpen(bool value) {
    if (_isOpen == value) return;
    _isOpen = value;
    notifyListeners();
  }

  /// Written by the widget each frame. Not a listener notification — a
  /// morph would rebuild every listener 60–120×/s.
  void _reportProgress(double value) => _progress = value;
}

/// Tuning for a [LiquidGlassMorph].
///
/// Width, height and radius each run their own spring: the reference
/// motion has the width settle early while the height is still growing,
/// and the corner radius arriving last. Equal stiffness on all three
/// gives a plain, mechanical lerp instead.
@immutable
class LiquidGlassMorphSpec {
  /// Spring for the box width.
  final double widthStiffness;
  final double widthDamping;

  /// Spring for the box height — the one that reads as "the panel
  /// unfolding". Softer than the width by default, so it lags and
  /// overshoots slightly.
  final double heightStiffness;
  final double heightDamping;

  /// Spring for the corner radius and the whole interpolated look
  /// (tint, blur, border). Softest of the three: the glass finishes
  /// thickening after the box has stopped moving.
  final double radiusStiffness;
  final double radiusDamping;

  /// Progress at which the outgoing content has fully faded.
  final double sourceFadeOut;

  /// Progress at which the incoming content starts to appear.
  ///
  /// This sits *below* [sourceFadeOut] by default, so the two layouts
  /// briefly overlap inside the lensing peak instead of leaving a gap
  /// where the body is empty. Nothing is ever legible in that window —
  /// [lensSurge] is bending both — but the glass never reads as vacated.
  final double destinationFadeIn;

  /// Peak blur sigma applied to the content layers in transit. This is
  /// what hides the fact that the two layouts share no geometry.
  final double contentBlur;

  /// How much each content layer is scaled toward the other end while
  /// it is dying / being born. `1.0` disables it.
  final double contentScale;

  /// How much the body thins at the peak of the bounce, as a fraction
  /// of its width. A gel stretched past its rest length gets narrow.
  ///
  /// Without it the overshoot can only leave through the one edge the
  /// alignment hasn't pinned, which reads as an edge flapping rather
  /// than a body settling. `0` disables it, and it does nothing at all
  /// once [heightDamping] reaches critical — no overshoot, nothing to
  /// absorb.
  final double volumeCoupling;

  /// Peak extra light-bending through the middle of the morph.
  ///
  /// The material is meant to hand one layout to the next by modulating
  /// its lensing, not by dissolving it — so the middle of the ride is
  /// smeared by the glass itself. `1` is the tuned amount; `0` disables
  /// it and leaves [contentBlur] doing the work alone.
  ///
  /// When a `refractionType` is set only magnification and chromatic
  /// aberration surge — that mode ignores the legacy distortion fields.
  final double lensSurge;

  const LiquidGlassMorphSpec({
    this.widthStiffness = 420,
    this.widthDamping = 30,
    this.heightStiffness = 260,
    this.heightDamping = 21,
    this.radiusStiffness = 200,
    this.radiusDamping = 24,
    this.sourceFadeOut = 0.40,
    this.destinationFadeIn = 0.38,
    this.contentBlur = 5,
    this.contentScale = 0.9,
    this.volumeCoupling = 0.07,
    this.lensSurge = 1,
  });

  /// No overshoot anywhere: every spring at or past critical damping.
  ///
  /// Bounce is meant to pay off momentum, and a tap carries none — so a
  /// tap-opened morph arguably should not have any. Spring *timing* is
  /// kept (the fast start, the long approach); only the ringing goes.
  /// [volumeCoupling] is inert here, there being no overshoot to spend.
  static const LiquidGlassMorphSpec settle = LiquidGlassMorphSpec(
    widthStiffness: 420,
    widthDamping: 41,
    heightStiffness: 260,
    heightDamping: 32.25,
    radiusStiffness: 200,
    radiusDamping: 28.3,
  );

  /// Snappier, no overshoot — for morphs that happen under the finger.
  static const LiquidGlassMorphSpec crisp = LiquidGlassMorphSpec(
    widthStiffness: 620,
    widthDamping: 40,
    heightStiffness: 480,
    heightDamping: 36,
    radiusStiffness: 420,
    radiusDamping: 34,
    contentBlur: 4,
    volumeCoupling: 0.03,
    lensSurge: 0.6,
  );
}

/// A single liquid-glass body that morphs from one component into
/// another — a button into a list, an icon row into a menu panel.
///
/// **This widget owns the glass.** [source] and [destination] are
/// *contents only* — an icon, a column of rows — with no lens of their
/// own; [sourceStyle] and [destinationStyle] describe the two ends of
/// the one lens that wraps them. That is what keeps the surface
/// continuous: at rest you are looking at the destination's glass with
/// the source's dimensions, halfway through you are looking at neither.
///
/// Both children are laid out at their natural size every frame, and
/// the box interpolates between those two sizes. Contents never reflow
/// mid-morph — they are aligned, blurred, faded and clipped by the
/// moving shape, exactly as the shape were a window onto each layout.
///
/// The box genuinely resizes in layout, so give it a parent that lets it
/// grow without shoving the page around — an `Align` or `Positioned`
/// inside a `Stack`:
///
/// ```dart
/// Stack(children: [
///   page,
///   Align(
///     alignment: Alignment.topCenter,
///     child: LiquidGlassMorph(
///       controller: controller,
///       sourceStyle: capsuleStyle,
///       destinationStyle: panelStyle,
///       source: const Icon(Icons.photo_album),
///       destination: const _AlbumList(),
///     ),
///   ),
/// ])
/// ```
class LiquidGlassMorph extends StatefulWidget {
  /// Content at rest. No glass of its own — see the class doc.
  final Widget source;

  /// Content after the morph. Laid out at its natural size from the
  /// first frame, so it must be self-sizing (wrap it in a `SizedBox` if
  /// it isn't).
  final Widget destination;

  /// The lens's look at rest.
  final LiquidGlassStyle sourceStyle;

  /// The lens's look once open. Typically much more opaque than
  /// [sourceStyle] — a thin capsule can be see-through, a panel full of
  /// text cannot.
  final LiquidGlassStyle destinationStyle;

  /// Drives the morph. Optional: without one the widget creates its own
  /// and [tapToOpen] is the only way in.
  final LiquidGlassMorphController? controller;

  /// Motion + content-handoff tuning.
  final LiquidGlassMorphSpec spec;

  /// How the two contents sit inside the moving box. The default pins
  /// them to the top edge, so the glass appears to unfold downward out
  /// of the source.
  final Alignment alignment;

  /// Tapping the source opens the morph.
  final bool tapToOpen;

  /// Tapping anywhere outside closes it. Uses [TapRegion], so it needs
  /// the `TapRegionSurface` that `WidgetsApp`/`MaterialApp` installs —
  /// no overlay entry, no barrier in the tree.
  final bool dismissOnOutsideTap;

  /// Fired when the target changes, before the motion finishes.
  final ValueChanged<bool>? onOpenChanged;

  const LiquidGlassMorph({
    super.key,
    required this.source,
    required this.destination,
    this.sourceStyle = const LiquidGlassStyle(),
    this.destinationStyle = const LiquidGlassStyle(),
    this.controller,
    this.spec = const LiquidGlassMorphSpec(),
    this.alignment = Alignment.topCenter,
    this.tapToOpen = true,
    this.dismissOnOutsideTap = true,
    this.onOpenChanged,
  });

  @override
  State<LiquidGlassMorph> createState() => _LiquidGlassMorphState();
}

class _LiquidGlassMorphState extends State<LiquidGlassMorph>
    with SingleTickerProviderStateMixin {
  // Created eagerly, not lazily: a morph that is never opened would
  // otherwise build its ticker from inside dispose(), which is an
  // inherited-widget lookup on a deactivated element.
  late final Ticker _ticker;
  LiquidGlassMorphController? _ownController;
  LiquidGlassMorphController get _controller =>
      widget.controller ?? (_ownController ??= LiquidGlassMorphController());

  // Three springs: width, height, radius/look. See [LiquidGlassMorphSpec].
  double _w = 0, _wVel = 0;
  double _h = 0, _hVel = 0;
  double _r = 0, _rVel = 0;
  double _target = 0;

  Duration _lastTick = Duration.zero;

  // Natural sizes of both ends, reported by the render object one frame
  // late. Only the radius clamp needs them, and at rest the source's own
  // style is already correct — so the lag is invisible.
  Size? _sourceSize;
  Size? _destinationSize;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _controller.addListener(_onIntentChanged);
    _target = _controller.isOpen ? 1 : 0;
    _w = _h = _r = _target;
  }

  @override
  void didUpdateWidget(LiquidGlassMorph old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_onIntentChanged);
      _controller.addListener(_onIntentChanged);
      _onIntentChanged();
    }
  }

  @override
  void dispose() {
    (widget.controller ?? _ownController)?.removeListener(_onIntentChanged);
    _ownController?.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onIntentChanged() {
    final next = _controller.isOpen ? 1.0 : 0.0;
    if (next == _target) return;
    _target = next;
    widget.onOpenChanged?.call(_controller.isOpen);
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // A dropped frame must not launch the springs; clamp the step.
    final step = dt.clamp(0.0, 1 / 30.0);
    final spec = widget.spec;

    final (w, wVel) = liquidGlassSpringStep(
      x: _w,
      vel: _wVel,
      target: _target,
      dt: step,
      stiffness: spec.widthStiffness,
      damping: spec.widthDamping,
    );
    final (h, hVel) = liquidGlassSpringStep(
      x: _h,
      vel: _hVel,
      target: _target,
      dt: step,
      stiffness: spec.heightStiffness,
      damping: spec.heightDamping,
    );
    final (r, rVel) = liquidGlassSpringStep(
      x: _r,
      vel: _rVel,
      target: _target,
      dt: step,
      stiffness: spec.radiusStiffness,
      damping: spec.radiusDamping,
    );
    _w = w;
    _wVel = wVel;
    _h = h;
    _hVel = hVel;
    _r = r;
    _rVel = rVel;

    if (_settled) {
      _w = _h = _r = _target;
      _wVel = _hVel = _rVel = 0;
      _ticker.stop();
    }
    _controller._reportProgress(_h);
    setState(() {});
  }

  bool get _settled {
    const eps = 0.001;
    return (_w - _target).abs() < eps &&
        (_h - _target).abs() < eps &&
        (_r - _target).abs() < eps &&
        _wVel.abs() < eps &&
        _hVel.abs() < eps &&
        _rVel.abs() < eps;
  }

  void _onSizes(Size source, Size destination) {
    if (!mounted) return;
    if (_sourceSize == source && _destinationSize == destination) return;
    setState(() {
      _sourceSize = source;
      _destinationSize = destination;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final t = _h;

    // Outgoing: gone by `sourceFadeOut`. Incoming: nothing before
    // `destinationFadeIn`. The window between them is the blurred middle.
    final outOpacity = 1 - (t / spec.sourceFadeOut).clamp(0.0, 1.0);
    final inOpacity =
        ((t - spec.destinationFadeIn) / (1 - spec.destinationFadeIn))
            .clamp(0.0, 1.0);

    // Blur peaks where neither layer is legible and falls to zero at
    // both ends, so a resting component is never soft.
    final transit = (t.clamp(0.0, 1.0) * (1 - t.clamp(0.0, 1.0))) * 4;
    final blur = spec.contentBlur * transit;

    final style = _surgeLens(
      _lerpStyle(
        widget.sourceStyle,
        widget.destinationStyle,
        _r,
        sourceSize: _sourceSize,
        destinationSize: _destinationSize,
      ),
      spec.lensSurge * transit,
    );

    Widget outLayer = _contentLayer(
      widget.source,
      opacity: outOpacity,
      blur: blur,
      scale: ui.lerpDouble(1, spec.contentScale, t.clamp(0.0, 1.0))!,
      interactive: t < 0.001,
    );
    if (widget.tapToOpen && t < 0.001) {
      outLayer = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _controller.open,
        child: outLayer,
      );
    }

    final inLayer = _contentLayer(
      widget.destination,
      opacity: inOpacity,
      blur: blur,
      scale: ui.lerpDouble(spec.contentScale, 1, t.clamp(0.0, 1.0))!,
      interactive: t > 0.999,
    );

    // A gel that shoots long gets narrow. Driven by how far *past* the
    // target the height is — not by its velocity, which is zero at the
    // top of an overshoot and so would leave the one frame that matters
    // untouched. Normalised by the overshoot this spring actually
    // produces, so the knob is the pinch at the peak of the bounce.
    final past = (_h - _target) * (_target > 0.5 ? 1.0 : -1.0);
    final peak = _overshootFraction(spec.heightStiffness, spec.heightDamping);
    final squash = spec.volumeCoupling <= 0 || peak <= 0
        ? 1.0
        : 1 - spec.volumeCoupling * (past / peak).clamp(0.0, 1.0);

    Widget morph = LiquidGlassLens(
      style: style,
      child: _MorphBox(
        widthProgress: _w,
        heightProgress: _h,
        widthSquash: squash,
        alignment: widget.alignment,
        onSizes: _onSizes,
        source: outLayer,
        destination: inLayer,
      ),
    );

    if (widget.dismissOnOutsideTap) {
      morph = TapRegion(
        groupId: this,
        onTapOutside: (_) {
          if (_controller.isOpen) _controller.close();
        },
        child: morph,
      );
    }
    return morph;
  }

  Widget _contentLayer(
    Widget child, {
    required double opacity,
    required double blur,
    required double scale,
    required bool interactive,
  }) {
    Widget layer = child;
    if ((scale - 1).abs() > 0.001) {
      layer = Transform.scale(scale: scale, child: layer);
    }
    if (blur > 0.05) {
      layer = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: layer,
      );
    }
    if (opacity < 0.999) {
      layer = Opacity(opacity: opacity.clamp(0.0, 1.0), child: layer);
    }
    if (!interactive) layer = IgnorePointer(child: layer);
    return layer;
  }
}

/// Peak overshoot of this spring's unit step, as a fraction of the
/// travel: `exp(-πζ / √(1-ζ²))` for `ζ = c / 2√k`.
///
/// Returns `0` at or beyond critical damping, where there is no
/// overshoot to normalise a bounce-driven effect against.
double _overshootFraction(double stiffness, double damping) {
  if (stiffness <= 0) return 0;
  final zeta = damping / (2 * math.sqrt(stiffness));
  if (zeta >= 1) return 0;
  return math.exp(-math.pi * zeta / math.sqrt(1 - zeta * zeta));
}

// ── Lensing surge ───────────────────────────────────────────

/// Peak deltas at `amount == 1`, tuned against ends that bend at
/// `0.03`–`0.09`: the middle bends roughly 3× either end, which is what
/// makes the handover read as glass rather than as a dissolve.
const double _surgeDistortion = 0.16;
const double _surgeWidthFactor = 2.2;
const double _surgeMagnification = 0.06;
const double _surgeAberration = 0.014;

/// Drives the glass's light-bending up through the middle of a morph, so
/// the two layouts are handed over by the lens rather than by opacity.
///
/// Widening the distortion band matters as much as deepening it: at rest
/// the bend lives near the rim, and only a wide band reaches far enough
/// in to take the content with it.
LiquidGlassStyle _surgeLens(LiquidGlassStyle s, double amount) {
  if (amount <= 0.001) return s;
  final r = s.refraction;
  // The legacy fields are ignored whenever a refractionType is set, so
  // only touch them when they are actually the ones driving the shader.
  final legacy = r.refractionType == null;
  return LiquidGlassStyle(
    shape: s.shape,
    appearance: s.appearance,
    refraction: LiquidGlassRefraction(
      distortion:
          legacy ? r.distortion + _surgeDistortion * amount : r.distortion,
      distortionWidth: legacy
          ? r.distortionWidth * (1 + (_surgeWidthFactor - 1) * amount)
          : r.distortionWidth,
      magnification: r.magnification + _surgeMagnification * amount,
      chromaticAberration: r.chromaticAberration + _surgeAberration * amount,
      refractionMode: r.refractionMode,
      refractionType: r.refractionType,
      diagonalFlip: r.diagonalFlip,
    ),
  );
}

// ── Style interpolation ─────────────────────────────────────

/// Blends two glass looks. Doubles and colors interpolate; enums and
/// flags cross at the halfway point (keep them equal at both ends unless
/// you want a pop mid-morph).
///
/// Corner radii are clamped against *their own end's* size before the
/// lerp — `min` is concave, so the lerp of two clamped radii can never
/// exceed half the smaller side of the lerped box. That is what keeps a
/// capsule a capsule while it inflates into a panel.
LiquidGlassStyle _lerpStyle(
  LiquidGlassStyle a,
  LiquidGlassStyle b,
  double t, {
  Size? sourceSize,
  Size? destinationSize,
}) {
  final sa = a.shape ?? const LiquidGlassShape.continuousRoundedRectangle();
  final sb = b.shape ?? const LiquidGlassShape.continuousRoundedRectangle();
  final late = t >= 0.5;

  double clampRadius(double r, Size? size) {
    if (size == null || size.isEmpty) return r;
    return r.clamp(0.0, size.shortestSide / 2);
  }

  final shape = LiquidGlassShape(
    cornerStyle: late ? sb.cornerStyle : sa.cornerStyle,
    cornerRadius: ui.lerpDouble(
      clampRadius(sa.cornerRadius, sourceSize),
      clampRadius(sb.cornerRadius, destinationSize),
      t,
    )!,
    clipQuality: late ? sb.clipQuality : sa.clipQuality,
    borderWidth: ui.lerpDouble(sa.borderWidth, sb.borderWidth, t)!,
    borderColor: Color.lerp(sa.borderColor, sb.borderColor, t),
    lightIntensity: ui.lerpDouble(sa.lightIntensity, sb.lightIntensity, t)!,
    lightColor: Color.lerp(sa.lightColor, sb.lightColor, t)!,
    lightDirection: ui.lerpDouble(sa.lightDirection, sb.lightDirection, t)!,
    lightMode: late ? sb.lightMode : sa.lightMode,
    borderType: late ? sb.borderType : sa.borderType,
  );

  final aa = a.appearance;
  final ab = b.appearance;
  final appearance = LiquidGlassAppearance(
    saturation: ui.lerpDouble(aa.saturation, ab.saturation, t)!,
    blur: LiquidGlassBlur(
      sigmaX: ui.lerpDouble(aa.blur.sigmaX, ab.blur.sigmaX, t)!,
      sigmaY: ui.lerpDouble(aa.blur.sigmaY, ab.blur.sigmaY, t)!,
    ),
    color: Color.lerp(aa.color, ab.color, t)!,
    enableInnerRadiusTransparent:
        late ? ab.enableInnerRadiusTransparent : aa.enableInnerRadiusTransparent,
    shadow: late ? ab.shadow : aa.shadow,
  );

  final ra = a.refraction;
  final rb = b.refraction;
  final refraction = LiquidGlassRefraction(
    distortion: ui.lerpDouble(ra.distortion, rb.distortion, t)!,
    distortionWidth:
        ui.lerpDouble(ra.distortionWidth, rb.distortionWidth, t)!,
    magnification: ui.lerpDouble(ra.magnification, rb.magnification, t)!,
    chromaticAberration:
        ui.lerpDouble(ra.chromaticAberration, rb.chromaticAberration, t)!,
    refractionMode: late ? rb.refractionMode : ra.refractionMode,
    refractionType: late ? rb.refractionType : ra.refractionType,
    diagonalFlip: ui.lerpDouble(ra.diagonalFlip, rb.diagonalFlip, t)!,
  );

  return LiquidGlassStyle(
    shape: shape,
    appearance: appearance,
    refraction: refraction,
  );
}

// ── The interpolating box ───────────────────────────────────

enum _MorphSlot { source, destination }

/// Lays both contents out at their natural size, then sizes itself to
/// the interpolation of the two. Width and height take separate
/// progresses so one can lead the other.
class _MorphBox
    extends SlottedMultiChildRenderObjectWidget<_MorphSlot, RenderBox> {
  final Widget source;
  final Widget destination;
  final double widthProgress;
  final double heightProgress;
  final double widthSquash;
  final Alignment alignment;
  final void Function(Size source, Size destination) onSizes;

  const _MorphBox({
    required this.source,
    required this.destination,
    required this.widthProgress,
    required this.heightProgress,
    required this.widthSquash,
    required this.alignment,
    required this.onSizes,
  });

  @override
  Iterable<_MorphSlot> get slots => _MorphSlot.values;

  @override
  Widget? childForSlot(_MorphSlot slot) => switch (slot) {
        _MorphSlot.source => source,
        _MorphSlot.destination => destination,
      };

  @override
  _RenderMorphBox createRenderObject(BuildContext context) => _RenderMorphBox(
        widthProgress: widthProgress,
        heightProgress: heightProgress,
        widthSquash: widthSquash,
        alignment: alignment,
        onSizes: onSizes,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderMorphBox box) {
    box
      ..widthProgress = widthProgress
      ..heightProgress = heightProgress
      ..widthSquash = widthSquash
      ..alignment = alignment
      ..onSizes = onSizes;
  }
}

class _RenderMorphBox extends RenderBox
    with SlottedContainerRenderObjectMixin<_MorphSlot, RenderBox> {
  _RenderMorphBox({
    required double widthProgress,
    required double heightProgress,
    required double widthSquash,
    required Alignment alignment,
    required this.onSizes,
  })  : _widthProgress = widthProgress,
        _heightProgress = heightProgress,
        _widthSquash = widthSquash,
        _alignment = alignment;

  void Function(Size, Size) onSizes;

  double _widthProgress;
  set widthProgress(double value) {
    if (_widthProgress == value) return;
    _widthProgress = value;
    markNeedsLayout();
  }

  double _heightProgress;
  set heightProgress(double value) {
    if (_heightProgress == value) return;
    _heightProgress = value;
    markNeedsLayout();
  }

  double _widthSquash;
  set widthSquash(double value) {
    if (_widthSquash == value) return;
    _widthSquash = value;
    markNeedsLayout();
  }

  Alignment _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  RenderBox? get _source => childForSlot(_MorphSlot.source);
  RenderBox? get _destination => childForSlot(_MorphSlot.destination);

  Size _lastSource = Size.zero;
  Size _lastDestination = Size.zero;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  Size _blend(Size a, Size b) => Size(
        ui.lerpDouble(a.width, b.width, _widthProgress)! * _widthSquash,
        ui.lerpDouble(a.height, b.height, _heightProgress)!,
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = constraints.loosen();
    final a = _source?.getDryLayout(loose) ?? Size.zero;
    final b = _destination?.getDryLayout(loose) ?? Size.zero;
    return constraints.constrain(_blend(a, b));
  }

  @override
  void performLayout() {
    // Loose constraints on both: each end reports the size it *wants*,
    // and the box interpolates between those two wishes. Neither child
    // ever reflows to the current box, which is the whole point — a
    // 4-row list must not try to squeeze into a 48px capsule on frame 1.
    final loose = constraints.loosen();
    final source = _source;
    final destination = _destination;

    var a = Size.zero;
    if (source != null) {
      source.layout(loose, parentUsesSize: true);
      a = source.size;
    }
    var b = Size.zero;
    if (destination != null) {
      destination.layout(loose, parentUsesSize: true);
      b = destination.size;
    }

    size = constraints.constrain(_blend(a, b));

    if (source != null) {
      (source.parentData! as BoxParentData).offset =
          _alignment.inscribe(a, Offset.zero & size).topLeft;
    }
    if (destination != null) {
      (destination.parentData! as BoxParentData).offset =
          _alignment.inscribe(b, Offset.zero & size).topLeft;
    }

    // The radius clamp upstairs needs both natural sizes; hand them up
    // after the frame, never during layout.
    if (a != _lastSource || b != _lastDestination) {
      _lastSource = a;
      _lastDestination = b;
      SchedulerBinding.instance.addPostFrameCallback((_) => onSizes(a, b));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Source first, destination over it: the incoming layout fades in on
    // top of the dying one.
    for (final child in [_source, _destination]) {
      if (child == null) continue;
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_destination, _source]) {
      if (child == null) continue;
      final childOffset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
