import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../lens/liquid_glass_lens.dart';
import '../../liquid_glass_config.dart'
    show LiquidGlassAppearance, LiquidGlassRefraction;
import '../../liquid_glass_style.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart'
    show ClassicBorder, LiquidGlassBorderType, OpticalBorder;
import '../../utils/liquid_glass_flex.dart' show LiquidGlassFlexDeform;
import '../../utils/liquid_glass_spring.dart' show liquidGlassSpringStep;
import '../../utils/liquid_glass_lens_motion.dart';
import '../../utils/liquid_glass_refraction_type.dart';
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_shadow.dart';

/// The moving glass pill of [LiquidGlassAnimatedNavBar], as one
/// self-contained widget: the two-state morph (contracted ↔ expanded
/// glass), the acceleration squash / stretch ([LiquidGlassLensMotion]),
/// and the driven-lens rendering — so the same living glass pill can
/// ride a bottom nav bar or anything else that moves it.
///
/// It is the nav bar's counterpart to [LiquidGlassMotionPill] (the
/// slider's thumb), with the two things a bar needs and a slider does
/// not: an externally supplied morph progress, so the bar's own travel
/// envelope drives the lift, and a motion-tracking switch it can drop
/// mid-travel.
///
/// ## Division of labour
///
/// The HOST owns position and gesture: where the pill's centre is each
/// frame (drags, glide springs, rubber bands — whatever its own model
/// produces) and when the pill is grabbed. This widget owns the rest:
///
///  * **Morph.** While [active], the pill spring-grows from [restSize]
///    to [activeSize]; on deactivation it contracts on the landing spring.
///    That same progress interpolates [restStyle] into [style] on one
///    persistent lens — nothing is cross-faded, inserted or removed. A
///    host running its own size model supplies [envelopeSize] and the
///    two halves separate: its size, this widget's material.
///  * **Squash/stretch.** While motion tracking is requested, [center] is
///    sampled every frame into the acceleration model; the resulting
///    deviation scales the pill oppositely on the two axes. When travel ends,
///    stationary samples let that deformation settle naturally back to zero.
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
class LiquidGlassNavBarMotionPill extends StatefulWidget {
  /// The pill's centre in this widget's local coordinates. Update it
  /// every frame however the host moves — set directly from a drag,
  /// driven by a glide spring, anything.
  final Offset center;

  /// Whether the pill is "lifted": expanded to [activeSize]. Flip on grab,
  /// off when the pill should contract back to rest.
  final bool active;

  /// Optional externally supplied rest/lift progress (`0` = rest, `1` =
  /// lifted). When set, this replaces the pill's internal morph spring while
  /// leaving acceleration deformation and material interpolation intact.
  final double? morphProgress;

  /// Whether the pill continues sampling [center] for acceleration-based
  /// squash/stretch. When null, this follows [active]. A host can keep this
  /// true while [active] becomes false to overlap landing with late travel.
  final bool? trackMotion;

  /// Whether ending [trackMotion] immediately clears acceleration deformation
  /// instead of letting its sampling window ease back to zero. The normal
  /// lift/rest morph keeps running; only motion squash/stretch is removed.
  final bool resetMotionOnStop;

  /// Size of the contracted rest pill.
  final Size restSize;

  /// Size of the expanded (lifted) glass pill.
  final Size activeSize;

  /// The pill's size this frame BEFORE the acceleration deformation,
  /// supplied by the host. When set it replaces the
  /// [restSize]→[activeSize] interpolation for geometry only.
  ///
  /// [morphProgress] goes on driving the material, so the two can run on
  /// separate springs: a host whose glass arrives fast under a size that
  /// is still wobbling into place hands the size in here and the look in
  /// [morphProgress]. [restSize] and [activeSize] are still read for the
  /// corner and rim endpoints.
  final Size? envelopeSize;

  /// Glass look at the fully lifted endpoint. Null keeps the tuned default.
  final LiquidGlassStyle? style;

  /// Glass look at the resting endpoint. Every interpolated frame is still
  /// the same lens; this is not a separate cover or replacement widget.
  final LiquidGlassStyle restStyle;

  /// Tuning of the acceleration squash/stretch.
  final LiquidGlassLensMotionSpec motion;

  /// Squash/stretch supplied from **outside**, replacing this widget's own
  /// acceleration model. `scaleX = 1 + deviation`, `scaleY = 1 − deviation`.
  ///
  /// A host hands this in when the deformation is not this widget's to
  /// own — a nav bar drives one shared model so the squash is continuous
  /// across a pill that gets mounted and unmounted, and so it can tell
  /// when the deformation has drained. When set, [motion], [trackMotion]
  /// and [resetMotionOnStop] are unused: the host owns the sampling and
  /// this widget only renders what it is given.
  final double? deviation;

  /// How much of the glass is present, `0`..`1`, on top of the lift.
  ///
  /// The lift ([morphProgress]) says how big and how raised the pill is;
  /// this says how much of it still reads as glass. They are separate
  /// because a pill that is handing over to a plain painted twin has to
  /// shed its glass **while still moving and still deformed** — the rim
  /// and its shadow first, the refraction easing out behind them.
  ///
  /// `1` (the default) is the full material.
  final double glassPresence;

  /// Expand spring, mapped as ω₀ = 2π / duration (0.4 s, ζ 0.6).
  final double expandStiffness;
  final double expandDamping;

  /// Landing spring (about 0.4 s, damping ratio about 0.55).
  final double contractStiffness;
  final double contractDamping;

  /// Whether the lift-to-rest morph may compress below the authored rest size
  /// and rebound once before settling. This affects only the state morph; the
  /// acceleration-driven outline stretch remains active either way.
  final bool restBounce;

  /// Contact shadow drawn around the pill — the soft dark band that hugs
  /// the rim and pools underneath. `null` (the default) draws none.
  ///
  /// It wraps the lens rather than living inside it, so the half that
  /// falls BELOW the pill survives instead of being clipped away; the
  /// pill also hands it the current outline stretch so the ring tracks
  /// an elliptical cap while the glass is squashed. See
  /// [LiquidGlassShadow].
  ///
  /// It paints behind the glass and its opacity follows the active-style
  /// progress, reaching zero at rest without replacing the lens.
  final LiquidGlassShadow? shadow;

  /// Reports the pill's live size, for a host that has to draw something
  /// aligned to the glass — the nav bar's icon shell wipes the selected
  /// colour on through exactly this rect.
  ///
  /// The reported value is the DEFORMED size, matching what the shader draws.
  /// The nullable type is retained for existing hosts, but this persistent
  /// lens publishes a size at rest as well as while lifted.
  ///
  /// Written from the ticker, never from `build`, so a host may listen to
  /// it and call `setState` without a build-during-build.
  final ValueNotifier<Size?>? geometry;

  /// Whether the shader folds the captured backdrop's alpha into its
  /// coverage — required over an authored-transparent capture (a
  /// slider's track, a demo bar). Skia capture path only.
  final bool honorBackdropAlpha;

  const LiquidGlassNavBarMotionPill({
    super.key,
    required this.center,
    required this.active,
    this.morphProgress,
    this.trackMotion,
    this.resetMotionOnStop = false,
    required this.restSize,
    required this.activeSize,
    this.envelopeSize,
    this.style,
    this.restStyle = const LiquidGlassStyle(),
    this.motion = const LiquidGlassLensMotionSpec(),
    this.deviation,
    this.glassPresence = 1.0,
    this.expandStiffness = 247,
    this.expandDamping = 18.9,
    this.contractStiffness = 260,
    this.contractDamping = 17.7,
    this.restBounce = true,
    this.shadow,
    this.geometry,
    this.honorBackdropAlpha = true,
  });

  @override
  State<LiquidGlassNavBarMotionPill> createState() =>
      _LiquidGlassNavBarMotionPillState();
}

class _LiquidGlassNavBarMotionPillState
    extends State<LiquidGlassNavBarMotionPill>
    with SingleTickerProviderStateMixin {
  /// Morph progress: 0 = contracted, 1 = expanded. The expand spring
  /// overshoots past 1 on purpose — that is the bounce.
  double _morph = 0;
  double _morphVel = 0;
  bool _restSpringHasCompressed = false;
  bool _motionSettling = false;

  late final LiquidGlassLensMotion _motion =
      LiquidGlassLensMotion(spec: widget.motion);

  Ticker? _ticker;
  Duration? _tickerLast;

  /// The deformation actually drawn: the host's when it owns the model,
  /// this widget's own acceleration sampling otherwise.
  double get _deviation => widget.deviation ?? _motion.deviation;

  @override
  void initState() {
    super.initState();
    _morph = widget.morphProgress?.clamp(0.0, 1.0) ?? 0;
    final bool tracking =
        widget.deviation == null && (widget.trackMotion ?? widget.active);
    if (tracking) {
      _motion.start();
    }
    if (widget.active || tracking) {
      _ensureTicking();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LiquidGlassNavBarMotionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _motion.spec = widget.motion;
    if (widget.morphProgress != null) {
      _morph = widget.morphProgress!.clamp(0.0, 1.0);
      _morphVel = 0;
      _restSpringHasCompressed = false;
      if (widget.morphProgress != oldWidget.morphProgress) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _publishGeometry();
        });
      }
    } else if (widget.active != oldWidget.active ||
        oldWidget.morphProgress != null) {
      _restSpringHasCompressed = false;
      // A tap can begin landing while the lift spring is still moving outward.
      // Carrying that large positive velocity into the opposite target makes
      // the glass-to-rest transition collapse abruptly. A drag has already
      // settled near zero velocity, so this only materially corrects taps.
      if (!widget.active && _morphVel > 0) {
        _morphVel = 0;
      }
      _ensureTicking();
    }
    if (widget.deviation != null) return; // the host owns the model
    final bool wasTracking = oldWidget.trackMotion ?? oldWidget.active;
    final bool isTracking = widget.trackMotion ?? widget.active;
    if (isTracking != wasTracking) {
      if (isTracking) {
        _motionSettling = false;
        if (!_motion.isTracking) _motion.start();
        _ensureTicking();
      } else if (widget.resetMotionOnStop) {
        _motion.stop();
        _motionSettling = false;
      } else {
        // Keep sampling the now-stationary centre. The acceleration window
        // and response easing then return squash/stretch to zero naturally.
        _motionSettling = true;
        _ensureTicking();
      }
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

    if (widget.morphProgress != null) {
      _morph = widget.morphProgress!.clamp(0.0, 1.0);
      _morphVel = 0;
    } else {
      // The morph — expand and contract carry two different springs,
      // chosen by which way the target points.
      final double target = widget.active ? 1 : 0;
      final bool wasBelowRest = _morph < 0;
      final result = liquidGlassSpringStep(
        x: _morph,
        vel: _morphVel,
        target: target,
        dt: dt,
        stiffness:
            widget.active ? widget.expandStiffness : widget.contractStiffness,
        damping: widget.active ? widget.expandDamping : widget.contractDamping,
      );
      double nextMorph = result.$1;
      double nextMorphVel = result.$2;

      if (!widget.active) {
        if (!widget.restBounce && nextMorph <= 0) {
          nextMorph = 0;
          nextMorphVel = 0;
        } else if (widget.restBounce) {
          // Let the landing spring compress below rest, then finish on its
          // first rebound through the authored size.
          if (nextMorph < 0) _restSpringHasCompressed = true;
          if (_restSpringHasCompressed && wasBelowRest && nextMorph >= 0) {
            nextMorph = 0;
            nextMorphVel = 0;
          }
        }
      }

      _morph = nextMorph;
      _morphVel = nextMorphVel;
      if ((_morph - target).abs() < 0.001 && _morphVel.abs() < 0.01) {
        _morph = target;
        _morphVel = 0;
      } else {
        busy = true;
      }
    }

    // Sample the host-supplied centre — real per-frame positions feed
    // the model (drags AND glides), so a glide's launch stretches and
    // its arrival squashes.
    if (_motion.isTracking) {
      _motion.track(widget.center, now: elapsed.inMicroseconds / 1e6, dt: dt);
      if (_motionSettling && _motion.deviation.abs() < 0.0005) {
        _motion.stop();
        _motionSettling = false;
      } else {
        busy = true;
      }
    }

    if (!busy) _ticker?.stop();
    _publishGeometry();
    if (mounted) setState(() {});
  }

  /// Morph size, then the lens deviation on top of it: opposite scales on
  /// the two axes, the frame re-centred so the deformation grows about
  /// the middle.
  ({double morphW, double morphH, double pillW, double pillH}) _metrics() {
    final Size rest = widget.restSize;
    final Size active = widget.activeSize;
    final Size? envelope = widget.envelopeSize;
    final double morphW =
        envelope?.width ?? rest.width + (active.width - rest.width) * _morph;
    final double morphH = envelope?.height ??
        rest.height + (active.height - rest.height) * _morph;
    final double d = _deviation;
    return (
      morphW: morphW,
      morphH: morphH,
      pillW: morphW * (1 + d),
      pillH: morphH * (1 - d),
    );
  }

  /// Pushes the live size out to [LiquidGlassNavBarMotionPill.geometry]. Called
  /// from the ticker only — never from `build` — so a listening host can
  /// safely rebuild on it.
  void _publishGeometry() {
    final ValueNotifier<Size?>? out = widget.geometry;
    if (out == null) return;
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
    final double styleProgress = _morph.clamp(0.0, 1.0);

    // The deformed box's top-left in the host's coordinates.
    final Offset deformedTopLeft =
        Offset(widget.center.dx - pillW / 2, widget.center.dy - pillH / 2);
    final double scaleX = morphW > 0 ? pillW / morphW : 1.0;
    final double scaleY = morphH > 0 ? pillH / morphH : 1.0;

    // Handing over: the rim and its shadow go first and are gone by the
    // time the refraction is halfway out, so the pill reads as glass
    // losing its edges rather than a surface being switched off.
    final double presence = widget.glassPresence.clamp(0.0, 1.0);
    // Gone by the time the hand-off is 55% through, so the refraction is
    // still easing out behind it — edges first, body after.
    final double rim = ((presence - 0.45) / 0.55).clamp(0.0, 1.0);

    Widget glassPill = LiquidGlassLens(
      style: _resolveStyle(styleProgress, scaleX, presence: presence, rim: rim),
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
    );

    // The shadow remains part of this same surface and eases away with the
    // active style instead of being hidden by a replacement rest widget.
    final LiquidGlassShadow? shadow = widget.shadow;
    if (shadow != null) {
      glassPill = LiquidGlassShadow(
        blur: shadow.blur,
        opacity: shadow.opacity * styleProgress * rim,
        color: shadow.color,
        offset: shadow.offset,
        cornerRadius: shadow.cornerRadius ?? morphH / 2,
        scale: Offset(scaleX, scaleY),
        inset: shadow.inset,
        visible: shadow.visible,
        child: glassPill,
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
          child: glassPill,
        ),
      ],
    );
  }

  /// Resolves one continuously changing material. Geometry, tint, blur,
  /// refraction and rim values all use the same spring progress; there is no
  /// rest widget to fade in and no glass widget to remove.
  LiquidGlassStyle _resolveStyle(
    double progress,
    double stretchX, {
    double presence = 1.0,
    double rim = 1.0,
  }) {
    final double t = progress.clamp(0.0, 1.0);
    final LiquidGlassStyle active = widget.style ?? _defaultStyle;
    final LiquidGlassStyle rest = widget.restStyle;
    final LiquidGlassShape activeShape =
        active.shape ?? _defaultShape(widget.activeSize.height / 2);
    final LiquidGlassShape restShape = _withoutRim(
      rest.shape ?? _defaultShape(widget.restSize.height / 2),
    );
    final double widthCompensation = stretchX > 0 ? 1 / stretchX : 1;

    return LiquidGlassStyle(
      // The rim rides `rim` on top of the lift, so it can be retired while
      // the pill is still large and still deformed.
      shape: _scaleRim(_lerpShape(restShape, activeShape, t), rim),
      appearance: _lerpAppearance(rest.appearance, active.appearance, t),
      // Refraction leaves on `presence`: the band narrows to nothing, so
      // what is behind the pill straightens out rather than snapping.
      refraction: _compensateRefractionWidth(
        _lerpRefraction(rest.refraction, active.refraction, t),
        widthCompensation * presence,
      ),
    );
  }

  /// The same rim at a fraction of its width. `0` retires it outright —
  /// with it the optical border's own extra width, which is only added
  /// while `borderWidth > 0`.
  static LiquidGlassShape _scaleRim(LiquidGlassShape s, double factor) {
    if (factor >= 1.0 || s.borderWidth == 0) return s;
    return LiquidGlassShape(
      cornerStyle: s.cornerStyle,
      clipQuality: s.clipQuality,
      lightMode: s.lightMode,
      cornerRadius: s.cornerRadius,
      borderWidth: s.borderWidth * factor,
      borderColor: s.borderColor,
      lightIntensity: s.lightIntensity,
      lightColor: s.lightColor,
      lightDirection: s.lightDirection,
      borderType: s.borderType,
    );
  }

  /// The rest end of the material, with the rim taken off — same corners,
  /// no border.
  ///
  /// A settled pill is handed over to a plain painted one, which draws a
  /// fill and nothing else. Anything the glass still carries at that
  /// moment has nowhere to go and pops off in a single frame. The
  /// refraction already interpolates to zero; the rim does not, because
  /// it lives on the shape the host authored for the pill's corners. So
  /// the corner geometry is kept and only `borderWidth` (with it, the
  /// optical rim's own extra width) is retired.
  ///
  /// Only the REST end is stripped: the lifted pill keeps the full rim it
  /// was given, and the lerp between them is the fade.
  static LiquidGlassShape _withoutRim(LiquidGlassShape s) {
    if (s.borderWidth == 0) return s;
    return LiquidGlassShape(
      cornerStyle: s.cornerStyle,
      clipQuality: s.clipQuality,
      lightMode: s.lightMode,
      cornerRadius: s.cornerRadius,
      borderWidth: 0,
      borderColor: s.borderColor,
      lightIntensity: s.lightIntensity,
      lightColor: s.lightColor,
      lightDirection: s.lightDirection,
      borderType: s.borderType,
    );
  }

  static LiquidGlassShape _defaultShape(double cornerRadius) {
    return LiquidGlassShape(
      cornerStyle: LiquidGlassCornerStyle.continuousRoundedRectangle,
      cornerRadius: cornerRadius,
      borderWidth: 0.6,
      lightIntensity: 1.3,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    );
  }

  static double _lerpDouble(double from, double to, double t) =>
      from + (to - from) * t;

  static LiquidGlassShape _lerpShape(
    LiquidGlassShape from,
    LiquidGlassShape to,
    double t,
  ) {
    final Color? borderColor =
        from.borderColor == null && to.borderColor == null
            ? null
            : Color.lerp(
                from.borderColor ?? Colors.transparent,
                to.borderColor ?? Colors.transparent,
                t,
              );
    return LiquidGlassShape(
      // Discrete shape modes stay stable for the lifetime of the one lens.
      cornerStyle: from.cornerStyle,
      clipQuality: from.clipQuality,
      lightMode: from.lightMode,
      cornerRadius: _lerpDouble(from.cornerRadius, to.cornerRadius, t),
      borderWidth: _lerpDouble(from.borderWidth, to.borderWidth, t),
      borderColor: borderColor,
      lightIntensity: _lerpDouble(
        from.lightIntensity,
        to.lightIntensity,
        t,
      ),
      lightColor: Color.lerp(from.lightColor, to.lightColor, t)!,
      lightDirection: _lerpDouble(
        from.lightDirection,
        to.lightDirection,
        t,
      ),
      borderType: _lerpBorder(from.borderType, to.borderType, t),
    );
  }

  static LiquidGlassBorderType _lerpBorder(
    LiquidGlassBorderType from,
    LiquidGlassBorderType to,
    double t,
  ) {
    if (from is OpticalBorder && to is OpticalBorder) {
      return OpticalBorder(
        borderSaturation: _lerpDouble(
          from.borderSaturation,
          to.borderSaturation,
          t,
        ),
        ambientIntensity: _lerpDouble(
          from.ambientIntensity,
          to.ambientIntensity,
          t,
        ),
        borderSolidity: _lerpDouble(
          from.borderSolidity,
          to.borderSolidity,
          t,
        ),
        lightSpread: _lerpDouble(from.lightSpread, to.lightSpread, t),
      );
    }
    if (from is ClassicBorder && to is ClassicBorder) {
      return ClassicBorder(
        borderSoftness: _lerpDouble(
          from.borderSoftness,
          to.borderSoftness,
          t,
        ),
        shadowColor: Color.lerp(from.shadowColor, to.shadowColor, t)!,
        oneSideLightIntensity: _lerpDouble(
          from.oneSideLightIntensity,
          to.oneSideLightIntensity,
          t,
        ),
        doubleSideLightIntensity: _lerpDouble(
          from.doubleSideLightIntensity,
          to.doubleSideLightIntensity,
          t,
        ),
      );
    }
    return from;
  }

  static LiquidGlassAppearance _lerpAppearance(
    LiquidGlassAppearance from,
    LiquidGlassAppearance to,
    double t,
  ) {
    return LiquidGlassAppearance(
      saturation: _lerpDouble(from.saturation, to.saturation, t),
      blur: LiquidGlassBlur(
        sigmaX: _lerpDouble(from.blur.sigmaX, to.blur.sigmaX, t),
        sigmaY: _lerpDouble(from.blur.sigmaY, to.blur.sigmaY, t),
      ),
      color: Color.lerp(from.color, to.color, t)!,
      enableInnerRadiusTransparent: t < 0.5
          ? from.enableInnerRadiusTransparent
          : to.enableInnerRadiusTransparent,
      // Deliberately NO shadow: the pill draws its own tracked ring
      // (scaled with the outline, faded with the rim), and the bar
      // hoists an appearance-authored shadow into that path — leaving
      // it here would have the inner lens wrap a second, frozen ring.
    );
  }

  static LiquidGlassRefraction _lerpRefraction(
    LiquidGlassRefraction from,
    LiquidGlassRefraction to,
    double t,
  ) {
    return LiquidGlassRefraction(
      distortion: _lerpDouble(from.distortion, to.distortion, t),
      distortionWidth: _lerpDouble(
        from.distortionWidth,
        to.distortionWidth,
        t,
      ),
      magnification: _lerpDouble(
        from.magnification,
        to.magnification,
        t,
      ),
      chromaticAberration: _lerpDouble(
        from.chromaticAberration,
        to.chromaticAberration,
        t,
      ),
      refractionMode: from.refractionMode,
      refractionType: _lerpRefractionType(
        from.refractionType,
        to.refractionType,
        t,
      ),
      diagonalFlip: _lerpDouble(from.diagonalFlip, to.diagonalFlip, t),
    );
  }

  static LiquidGlassRefractionType? _lerpRefractionType(
    LiquidGlassRefractionType? from,
    LiquidGlassRefractionType? to,
    double t,
  ) {
    if (from == null && to == null) return null;
    if (from is StandardRefraction && to is StandardRefraction) {
      return StandardRefraction(
        distortion: _lerpDouble(from.distortion, to.distortion, t),
        distortionWidth: _lerpDouble(
          from.distortionWidth,
          to.distortionWidth,
          t,
        ),
      );
    }
    if (from is OpticalRefraction && to is OpticalRefraction) {
      return OpticalRefraction(
        refraction: _lerpDouble(from.refraction, to.refraction, t),
        refractionWidth: _lerpDouble(
          from.refractionWidth,
          to.refractionWidth,
          t,
        ),
        depth: _lerpDouble(from.depth, to.depth, t),
      );
    }
    // One end has no type at all. The calculation itself can't be
    // interpolated, but its WIDTH can — a zero-width band bends nothing,
    // which is precisely what the absent end means. Without this the
    // surviving type stayed at full strength for every `t`, so a pill
    // whose lifted glass names a refraction type went on refracting right
    // through its own rest state.
    if (from == null && to != null) return to.withWidthFactor(t);
    if (to == null && from != null) return from.withWidthFactor(1 - t);
    // Two different calculations: keep one stable rather than swapping
    // shader surfaces mid-travel.
    return to ?? from;
  }

  static LiquidGlassRefraction _compensateRefractionWidth(
    LiquidGlassRefraction refraction,
    double factor,
  ) {
    return refraction.copyWith(
      distortionWidth: refraction.distortionWidth * factor,
      refractionType: refraction.refractionType?.withWidthFactor(factor),
    );
  }

  /// The tuned default glass.
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
