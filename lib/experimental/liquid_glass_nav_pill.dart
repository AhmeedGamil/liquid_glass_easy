import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../src/widgets/lens/liquid_glass_lens.dart';
import '../src/widgets/liquid_glass_config.dart'
    show LiquidGlassAppearance, LiquidGlassRefraction;
import '../src/widgets/liquid_glass_style.dart';
import '../src/widgets/utils/liquid_glass_blur.dart';
import '../src/widgets/utils/liquid_glass_border_mode.dart' show OpticalBorder;
import '../src/widgets/utils/liquid_glass_flex.dart' show LiquidGlassFlexDeform;
import '../src/widgets/utils/liquid_glass_jelly_spring.dart' show liquidGlassSpringStep;
import '../src/widgets/utils/liquid_glass_lens_motion.dart';
import '../src/widgets/utils/liquid_glass_shape.dart';
import '../src/widgets/components/liquid_glass_shadow.dart';

/// **Experimental.** A copy of `LiquidGlassMotionPill` with the two
/// things a nav bar needs and a slider does not. The sliding thumb's whole thumb effect as one
/// isolated, reusable component: the two-state morph (contracted ↔
/// expanded glass), the acceleration squash / stretch
/// ([LiquidGlassLensMotion]), and the driven-lens rendering — so the
/// same living glass pill can ride a slider track, a bottom nav bar, or
/// anything else that moves it.
///
/// ## Division of labour
///
/// The HOST owns position and gesture: where the pill's centre is each
/// frame (drags, glide springs, rubber bands — whatever its own model
/// produces) and when the pill is grabbed. This widget owns everything
/// the thumb itself did:
///
///  * **Morph.** While [active], the pill spring-grows from [restSize]
///    to [activeSize] (0.4 s, ζ 0.6 — overshoot included); on
///    deactivation it contracts on the softer spring (0.6 s, ζ 0.7).
///    The optional [cover] (e.g. the slider's white rest pill) fades
///    out as the glass arrives, so the two read as one crossfade.
///  * **Squash/stretch.** While [active], [center] is sampled every
///    frame into the acceleration model; the resulting deviation scales
///    the pill oppositely on the two axes. Tracking starts on
///    activation and resets instantly when the contract-back begins.
///  * **Rendering.** The deformation is not a rebuilt capsule: the
///    lens renders at its REST (morph) size and the size change rides
///    the shader's `u_shapeScale` + matching clip scale via
///    [LiquidGlassLens], so the end caps go elliptical instead of
///    the shape being re-rounded at each new size — with the refraction
///    band counter-scaled so it keeps its authored width at stretched
///    caps.
///
/// ## Embedding
///
/// The widget fills whatever box the host gives it and positions the
/// (overflowing) pill at [center] in that box's coordinates — place it
/// as the `child` of a `LiquidGlassView`, or anywhere a
/// [LiquidGlassLens] can render. The host just rebuilds with the
/// new [center]; this widget's own ticker does the sampling.
class LiquidGlassNavPill extends StatefulWidget {
  /// The pill's centre in this widget's local coordinates. Update it
  /// every frame however the host moves — set directly from a drag,
  /// driven by a glide spring, anything.
  final Offset center;

  /// Whether the pill is "lifted": expanded to [activeSize] and
  /// tracking its own motion. Flip on grab, off when the pill should
  /// contract back to rest.
  final bool active;

  /// Size of the contracted rest pill.
  final Size restSize;

  /// Size of the expanded (lifted) glass pill.
  final Size activeSize;

  /// Glass look; null keeps the tuned slider default. The default
  /// shape is a continuous capsule tracking the morph height.
  final LiquidGlassStyle? style;

  /// Tuning of the acceleration squash/stretch.
  final LiquidGlassLensMotionSpec motion;

  /// Expand spring, mapped as ω₀ = 2π / duration (0.4 s, ζ 0.6).
  final double expandStiffness;
  final double expandDamping;

  /// Contract spring (0.6 s, ζ 0.7).
  final double contractStiffness;
  final double contractDamping;

  /// Widget drawn over the glass at rest and faded out as the morph
  /// expands — the slider passes its solid white pill here. Laid out at
  /// rest size and pixel-stretched with the outline, so it deforms as
  /// one body with the glass. Takes no pointers.
  final Widget? cover;

  /// Contact shadow drawn around the pill — the soft dark band that hugs
  /// the rim and pools underneath. `null` (the default) draws none.
  ///
  /// It wraps the lens rather than living inside it, so the half that
  /// falls BELOW the pill survives instead of being clipped away; the
  /// pill also hands it the current outline stretch so the ring tracks
  /// an elliptical cap while the glass is squashed. See
  /// [LiquidGlassShadow].
  ///
  /// It paints behind the glass, so an opaque [cover] at rest covers the
  /// shadow along with the glass beneath it.
  final LiquidGlassShadow? shadow;

  /// Reports the pill's live size, for a host that has to draw something
  /// aligned to the glass — the nav bar's icon shell wipes the selected
  /// colour on through exactly this rect.
  ///
  /// `null` **means the pill is resting**: no glass is being rendered at
  /// all, so there is nothing to align to and nothing for the host's
  /// capture to keep awake for. A `Size` means it is lifted, and is the
  /// DEFORMED size, matching what the shader actually draws.
  ///
  /// Written from the ticker, never from `build`, so a host may listen to
  /// it and call `setState` without a build-during-build.
  final ValueNotifier<Size?>? geometry;

  /// Whether the shader folds the captured backdrop's alpha into its
  /// coverage — required over an authored-transparent capture (a
  /// slider's track, a demo bar). Skia capture path only.
  final bool honorBackdropAlpha;

  const LiquidGlassNavPill({
    super.key,
    required this.center,
    required this.active,
    required this.restSize,
    required this.activeSize,
    this.style,
    this.motion = const LiquidGlassLensMotionSpec(),
    this.expandStiffness = 247,
    this.expandDamping = 18.9,
    this.contractStiffness = 110,
    this.contractDamping = 14.7,
    this.cover,
    this.shadow,
    this.geometry,
    this.honorBackdropAlpha = true,
  });

  @override
  State<LiquidGlassNavPill> createState() => _LiquidGlassNavPillState();
}

class _LiquidGlassNavPillState extends State<LiquidGlassNavPill>
    with SingleTickerProviderStateMixin {
  /// Morph progress: 0 = contracted, 1 = expanded. The expand spring
  /// overshoots past 1 on purpose — that is the bounce.
  double _morph = 0;
  double _morphVel = 0;

  late final LiquidGlassLensMotion _motion =
      LiquidGlassLensMotion(spec: widget.motion);

  Ticker? _ticker;
  Duration? _tickerLast;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _motion.start();
      _ensureTicking();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LiquidGlassNavPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _motion.spec = widget.motion;
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _motion.start();
      } else {
        // Contract-back begins: instant reset, masked by the morph.
        _motion.stop();
      }
      _publishGeometry();
      _ensureTicking();
    }
  }

  void _ensureTicking() {
    final ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) {
      _tickerLast = null;
      ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;
    if (dt <= 0) return;

    bool busy = false;

    // The morph — expand and contract carry two different springs,
    // chosen by which way the target points.
    final double target = widget.active ? 1 : 0;
    final (m, mv) = liquidGlassSpringStep(
      x: _morph,
      vel: _morphVel,
      target: target,
      dt: dt,
      stiffness: widget.active ? widget.expandStiffness : widget.contractStiffness,
      damping: widget.active ? widget.expandDamping : widget.contractDamping,
    );
    _morph = m;
    _morphVel = mv;
    if ((_morph - target).abs() < 0.001 && _morphVel.abs() < 0.01) {
      _morph = target;
      _morphVel = 0;
    } else {
      busy = true;
    }

    // Sample the host-supplied centre — real per-frame positions feed
    // the model (drags AND glides), so a glide's launch stretches and
    // its arrival squashes.
    if (_motion.isTracking) {
      _motion.track(widget.center,
          now: elapsed.inMicroseconds / 1e6, dt: dt);
      busy = true;
    }

    if (!busy) _ticker?.stop();
    _publishGeometry();
    if (mounted) setState(() {});
  }

  /// Whether any glass is on screen. At `false` the cover is opaque and
  /// the lens beneath it could not be seen even if it were drawn — so it
  /// is not drawn, and the host's capture has nothing to stay awake for.
  bool get _live => widget.active || _morph > 0.0005;

  /// Morph size, then the lens deviation on top of it: opposite scales on
  /// the two axes, the frame re-centred so the deformation grows about
  /// the middle.
  ({double morphW, double morphH, double pillW, double pillH}) _metrics() {
    final Size rest = widget.restSize;
    final Size active = widget.activeSize;
    final double morphW = rest.width + (active.width - rest.width) * _morph;
    final double morphH = rest.height + (active.height - rest.height) * _morph;
    final double d = _motion.deviation;
    return (
      morphW: morphW,
      morphH: morphH,
      pillW: morphW * (1 + d),
      pillH: morphH * (1 - d),
    );
  }

  /// Pushes the live size out to [LiquidGlassNavPill.geometry]. Called
  /// from the ticker only — never from `build` — so a listening host can
  /// safely rebuild on it.
  void _publishGeometry() {
    final ValueNotifier<Size?>? out = widget.geometry;
    if (out == null) return;
    if (!_live) {
      if (out.value != null) out.value = null;
      return;
    }
    final m = _metrics();
    final Size next = Size(m.pillW, m.pillH);
    if (out.value != next) out.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics();
    final double morphW = m.morphW;
    final double morphH = m.morphH;
    final double pillW = m.pillW;
    final double pillH = m.pillH;
    final coverOpacity = (1.0 - _morph).clamp(0.0, 1.0);
    final Widget? restCover = widget.cover;

    // Resting: draw the cover alone. It is opaque here, so the glass
    // underneath is invisible — and rendering it anyway would keep a
    // backdrop pass (and the host's capture) alive for nothing.
    if (!_live) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (restCover != null)
            Positioned(
              left: widget.center.dx - morphW / 2,
              top: widget.center.dy - morphH / 2,
              width: math.max(1.0, morphW),
              height: math.max(1.0, morphH),
              child: IgnorePointer(child: restCover),
            ),
        ],
      );
    }

    // The deformed box's top-left in the host's coordinates.
    final Offset deformedTopLeft =
        Offset(widget.center.dx - pillW / 2, widget.center.dy - pillH / 2);
    final double scaleX = morphW > 0 ? pillW / morphW : 1.0;
    final double scaleY = morphH > 0 ? pillH / morphH : 1.0;


    Widget pill = LiquidGlassLens(
      style: _resolveStyle(morphH, scaleX),
      honorBackdropAlpha: widget.honorBackdropAlpha,
      restSize: Size(morphW, morphH),
      deform: LiquidGlassFlexDeform(
        left: (pillW - morphW) / 2,
        right: (pillW - morphW) / 2,
        top: (pillH - morphH) / 2,
        bottom: (pillH - morphH) / 2,
        childScaleX: scaleX,
        childScaleY: scaleY,
        childTranslateX: 0,
        childTranslateY: 0,
        pressAmount: 0,
      ),
      child: restCover == null
          ? null
          : IgnorePointer(child: Opacity(opacity: coverOpacity, child: restCover)),
    );

    // The shadow WRAPS the glass instead of riding inside it, so the arc
    // that pools below the pill is not clipped off at the outline. It is
    // handed the morph's own corner and the live stretch, so the ring
    // stays on the rim while the pill squashes. It paints BEHIND, so the
    // glass — and the solid cover at rest — sit over it.
    final LiquidGlassShadow? shadow = widget.shadow;
    if (shadow != null) {
      pill = LiquidGlassShadow(
        blur: shadow.blur,
        opacity: shadow.opacity,
        color: shadow.color,
        offset: shadow.offset,
        cornerRadius: shadow.cornerRadius ?? morphH / 2,
        scale: Offset(scaleX, scaleY),
        inset: shadow.inset,
        visible: shadow.visible,
        child: pill,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: deformedTopLeft.dx,
          top: deformedTopLeft.dy,
          width: math.max(1.0, pillW),
          height: math.max(1.0, pillH),
          child: pill,
        ),
      ],
    );
  }

  /// The pill's glass style at the current morph size: the caller's
  /// style (or the tuned default look) with a height-tracking capsule
  /// shape when none is set, the refraction band kept proportional
  /// below full size — and counter-scaled against the outline's
  /// horizontal stretch ([stretchX]).
  LiquidGlassStyle _resolveStyle(double morphH, double stretchX) {
    final LiquidGlassStyle base = widget.style ?? _defaultStyle;
    final LiquidGlassShape shape = base.shape ??
        LiquidGlassShape(
          cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
          cornerRadius: morphH / 2,
          borderWidth: 0.6,
          lightIntensity: 1.3,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.4,
            ambientIntensity: 1.0,
            borderSolidity: 0.5,
          ),
        );
    final double bandScale =
        (morphH / widget.activeSize.height).clamp(0.0, 1.0);
    // The band lives in REST space, so the outline stretch multiplies
    // its screen width by scaleX at the end caps; dividing the authored
    // width back out pins the caps' band at its authored visual width.
    final double comp = stretchX > 0 ? 1.0 / stretchX : 1.0;
    return LiquidGlassStyle(
      shape: shape,
      appearance: base.appearance,
      refraction: base.refraction.copyWith(
        distortionWidth: base.refraction.distortionWidth * bandScale * comp,
      ),
    );
  }

  /// The tuned default glass carried over from the stretch slider.
  static const LiquidGlassStyle _defaultStyle = LiquidGlassStyle(
    appearance: LiquidGlassAppearance(
      color: Color(0x1CFFFFFF),
      blur: LiquidGlassBlur(sigmaX: 1.5, sigmaY: 1.5),
    ),
    refraction: LiquidGlassRefraction(
      distortion: 0.12,
      distortionWidth: 18,
    ),
  );
}
