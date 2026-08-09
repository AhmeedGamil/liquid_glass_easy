import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_touch.dart';
import '../utils/liquid_glass_flex.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_blender.dart';
import 'liquid_glass_lens_scope.dart';
import 'liquid_glass_shaders.dart';
import 'render_liquid_glass_lens.dart';

/// A liquid-glass lens you can place **anywhere in the widget tree**.
///
/// Unlike the `children:` slot of `LiquidGlassView`, this lens is
/// layout-driven: it has no position or size parameters — it is exactly
/// where layout puts it and exactly as big as its constraints/[child]
/// make it (wrap it in a `SizedBox` to give it explicit dimensions).
///
/// ## Render modes (resolved automatically)
///
/// * **Impeller** (`ImageFilter.isShaderFilterSupported`): the lens
///   refracts the live backdrop — whatever your app painted behind it.
///   No `LiquidGlassView` and **no background widget needed at all**;
///   drop it over any UI and it works.
/// * **Skia / Web with an ancestor [LiquidGlassView]** that has a
///   `backgroundWidget`: the lens refracts the view's captured
///   background, wherever the lens sits inside the view's `child`.
/// * **Skia / Web without a view (or without a background)**: refraction
///   is impossible, so the lens degrades to a frosted look — backdrop
///   blur + tint + border, no refraction — and logs a one-time debug
///   warning.
///
/// The mode is an implementation detail: the widget tree you write is
/// identical in all three cases.
///
/// ## Lenses inside scrollables (Impeller)
///
/// Android's stretch overscroll effect isolates the scrollable's
/// content into its own compositing layer while the stretch plays. A
/// `BackdropFilter`-based lens inside that layer can no longer see the
/// real backdrop and renders **black** at both scroll edges. Disable
/// the overscroll indicator for scrollables that contain lenses:
///
/// ```dart
/// ScrollConfiguration(
///   behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
///   child: ListView(children: [ ...LiquidGlassLens(...)... ]),
/// )
/// ```
///
/// ```dart
/// SizedBox(
///   width: 220,
///   height: 120,
///   child: LiquidGlassLens(
///     style: const LiquidGlassStyle(
///       shape: LiquidGlassShape.roundedRectangle(cornerRadius: 36),
///     ),
///     child: const Center(child: Text('glass')),
///   ),
/// )
/// ```
class LiquidGlassLens extends StatefulWidget {
  /// The lens's look — its [LiquidGlassShape] (corners + border), its
  /// appearance (tint, blur, saturation) and its refraction (how it bends
  /// the content behind it) — bundled as one [LiquidGlassStyle]. A `null`
  /// `style.shape` falls back to a default continuous rounded rectangle.
  final LiquidGlassStyle style;

  /// Whether the lens is shown. When `false` the glass is disabled (no
  /// backdrop cost) and the [child] is removed, so a hidden lens leaves
  /// nothing behind. The change is instant — there is no built-in
  /// show/hide animation; wrap the lens yourself to animate it.
  final bool visibility;

  /// Override for the Impeller fast-path detection, like
  /// `LiquidGlassView.useImpellerBackdrop`. When null, inherits the
  /// ancestor view's setting, falling back to
  /// `ImageFilter.isShaderFilterSupported`.
  final bool? useImpellerBackdrop;

  /// How the lens answers a finger — see [LiquidGlassTouch].
  ///
  /// With a [LiquidGlassTouch.flex] the lens deforms under touch: press it
  /// and it compresses, drag it and it elongates along the pull, pinches in
  /// the cross axis and leans after your finger, then springs back with a
  /// wobble. The lens itself does not move; only its shape and its content
  /// deform.
  ///
  /// `null` (the default) disables the behaviour entirely — no gesture
  /// listener, no ticker, nothing added to the tree.
  ///
  /// Honored inside a `LiquidGlassBlender`: the merged metaball silhouette
  /// picks a member's deformation up from its resized box. Only
  /// [LiquidGlassFlexAdvanced.refractionBoost] does not survive the merge —
  /// see `_buildInner`.
  final LiquidGlassTouch? touch;

  /// Content rendered on top of the glass, clipped to the lens shape.
  final Widget? child;

  /// A deformation supplied from **outside**, for a host that computes the
  /// glass's shape itself instead of letting a finger do it.
  ///
  /// With [touch] the lens owns the whole gesture: it listens for pointers
  /// and runs its own [LiquidGlassFlexDriver]. Some hosts cannot work that
  /// way — a slider thumb or a nav pill is deformed by where it is being
  /// carried, which only the host knows. Passing a deform here skips the
  /// listener and the driver entirely and renders exactly what is given.
  ///
  /// The lens's own box must ALREADY be the deformed size; [restSize] is
  /// what the deformation is measured against, and the shape is evaluated
  /// there and stretched by deformed ÷ rest — so a capsule's caps go
  /// elliptical instead of being re-rounded at each new size.
  ///
  /// Both this and [restSize] must be set for the external path to engage;
  /// either one alone is ignored. Takes precedence over [touch].
  final LiquidGlassFlexDeform? deform;

  /// The undeformed size [deform] is measured against. See [deform].
  final Size? restSize;

  /// Whether the shader folds the captured backdrop's alpha into its own
  /// coverage — **Skia capture path only**, ignored on Impeller.
  ///
  /// `false` (the default) treats the capture as opaque, which is right
  /// for a view whose background is a full page. Set it when the captured
  /// background carries *authored* transparency that must pass through the
  /// glass, such as a slider's track, where opaque treatment renders the
  /// lens's overhang as a dark body.
  final bool honorBackdropAlpha;

  const LiquidGlassLens({
    super.key,
    this.style = const LiquidGlassStyle(),
    this.visibility = true,
    this.useImpellerBackdrop,
    this.touch,
    this.deform,
    this.restSize,
    this.honorBackdropAlpha = false,
    this.child,
  });

  @override
  State<LiquidGlassLens> createState() => _LiquidGlassLensState();
}

class _LiquidGlassLensState extends State<LiquidGlassLens>
    with SingleTickerProviderStateMixin {
  /// One-time debug notice when a lens has to degrade to frosted glass.
  static bool _warnedFrostedFallback = false;

  // Resolved look: read straight from the style; a null shape falls back
  // to the default continuous rounded rectangle (with the cheap circular
  // rounded-rectangle clip).
  LiquidGlassShape get _shape =>
      widget.style.shape ?? const LiquidGlassShape.continuousRoundedRectangle();
  LiquidGlassAppearance get _appearance => widget.style.appearance;
  LiquidGlassRefraction get _refraction => widget.style.refraction;

  /// Per-lens shader instances, created from the shared program cache.
  /// Deliberately not disposed manually: retained layers may still
  /// reference them during teardown (mirrors the legacy view, which
  /// also relies on GC finalizers for shader instances).
  ui.FragmentShader? _mainShader;
  ui.FragmentShader? _borderShader;

  @override
  void initState() {
    super.initState();
    if (!LiquidGlassShaders.isLoaded) {
      LiquidGlassShaders.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object _) {
        // Shaders unavailable (broken build / unsupported test env):
        // the lens simply stays on the frosted fallback.
      });
    }
  }

  void _warnFrostedOnce(String reason) {
    assert(() {
      if (!_warnedFrostedFallback) {
        _warnedFrostedFallback = true;
        debugPrint(
          'LiquidGlassLens: refraction unavailable ($reason). '
          'Falling back to a frosted (blur + tint) look. Refraction '
          'needs Impeller, or an ancestor LiquidGlassView with a '
          'backgroundWidget on Skia/Web.',
        );
      }
      return true;
    }());
  }

  /// Spring driver behind [LiquidGlassTouch.flex]. Created on first use, so
  /// a lens without a `touch` never allocates a ticker.
  LiquidGlassFlexDriver? _flexDriver;

  LiquidGlassFlexDriver _ensureFlexDriver(LiquidGlassFlex spec) =>
      (_flexDriver ??= LiquidGlassFlexDriver(vsync: this, spec: spec))
        ..spec = spec;

  @override
  void dispose() {
    _flexDriver?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When an ancestor LiquidGlassBlender is present, this lens stops
    // painting its own glass: it hands its geometry to the blender, which
    // merges all member lenses into one metaball surface.
    final blenderScope = LiquidGlassBlenderScope.maybeOf(context);

    // An externally-driven lens renders what it is handed and adds no
    // gesture machinery at all: its box is already the deformed size, so
    // there is nothing to measure and no finger to follow.
    final LiquidGlassFlexDeform? given = widget.deform;
    final Size? givenRest = widget.restSize;
    if (given != null && givenRest != null) {
      return _buildInner(context, blenderScope, given, givenRest);
    }

    final LiquidGlassFlex? flex = widget.touch?.flex;
    if (flex == null) {
      return _buildInner(
          context, blenderScope, LiquidGlassFlexDeform.none, Size.zero);
    }

    // The lens takes its size from layout, so the rest size has to come
    // from the incoming constraints — that is what the deformation is
    // measured against, and what the child is laid out at.
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size rest = constraints.biggest;
        if (!rest.width.isFinite || !rest.height.isFinite || rest.isEmpty) {
          // Unbounded or degenerate: nothing to deform against.
          return _buildInner(context, blenderScope,
              LiquidGlassFlexDeform.none, Size.zero);
        }

        final driver = _ensureFlexDriver(flex)..restSize = rest;

        return Listener(
          // Translucent, never opaque: the press must not start swallowing
          // taps that reached the content (or the UI behind) before.
          behavior: HitTestBehavior.translucent,
          // The pointer id goes with every event: a Listener reports all of
          // them, and the driver holds one finger's worth of state.
          onPointerDown: (event) =>
              driver.down(event.localPosition, rest, pointer: event.pointer),
          // Accumulate deltas, not positions — the box is deforming under
          // the finger, so a lens-local position would feed back on itself.
          onPointerMove: (event) =>
              driver.move(event.delta, pointer: event.pointer),
          onPointerUp: (event) => driver.up(pointer: event.pointer),
          onPointerCancel: (event) => driver.up(pointer: event.pointer),
          child: SizedBox.fromSize(
            size: rest,
            child: ValueListenableBuilder<LiquidGlassFlexDeform>(
              valueListenable: driver,
              builder: (context, deform, _) => liquidGlassFlexBox(
                deform: deform,
                restSize: rest,
                child: _buildInner(context, blenderScope, deform, rest),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Routes to whichever thing this lens actually is — a blended member, or
  /// a lens that paints its own glass — with the deformation already applied.
  ///
  /// Inside a [LiquidGlassBlender] the surrounding [liquidGlassFlexBox]
  /// has already resized this member's box, and the blender derives every
  /// member's rect from the render tree — `MatrixUtils.transformRect` over
  /// `member.getTransformTo(target)` — so the merged metaball silhouette
  /// picks the deformation up on its own, radius cap included. A resized
  /// member also notifies the registry from its `performLayout`, so the
  /// surface repaints. All that is left here is the content transform.
  ///
  /// One thing does not survive the trip:
  /// [LiquidGlassFlexAdvanced.refractionBoost]. The blender refracts
  /// through a single shared style for the whole merged surface, and its
  /// per-member uniforms carry only geometry — so a press on one blob cannot
  /// deepen its own optics without deepening every other blob's too. Geometry
  /// (stretch, squeeze, lean, grip, holdScale, tapScale) and
  /// [LiquidGlassFlexAdvanced.childFollow] all behave normally.
  Widget _buildInner(
    BuildContext context,
    LiquidGlassBlenderScope? blenderScope,
    LiquidGlassFlexDeform deform,
    Size restSize,
  ) {
    // A blender that cannot paint (Skia / web with no LiquidGlassView) must
    // not take this lens's glass with it: hand nothing over, and render solo
    // below with the GROUP's material so the tint still lands.
    if (blenderScope != null && !blenderScope.canBlend) {
      return _buildGlass(
        context,
        deform,
        restSize,
        style: blenderScope.soloStyleFor(widget.style),
      );
    }

    if (blenderScope != null) {
      return blenderScope.buildMember(
        style: widget.style,
        visible: widget.visibility,
        // Layout has already resized this member's box; the SCALE is the part
        // the blender cannot infer from it, and the metaball needs it to
        // evaluate the lens at its rest size.
        shapeScale: restSize.isEmpty
            ? const Offset(1, 1)
            : deform.scaleFrom(restSize),
        child: widget.child == null
            ? null
            : liquidGlassFlexChild(
                deform: deform,
                restSize: restSize,
                child: widget.child!,
              ),
      );
    }
    return _buildGlass(context, deform, restSize);
  }

  /// Builds the lens proper. [deform] is [LiquidGlassFlexDeform.none] and
  /// [restSize] is [Size.zero] whenever `touch.flex` is unset — in that case
  /// every press-related branch below collapses to the original behaviour.
  ///
  /// [style] overrides this lens's own — used by a member standing in for a
  /// blend that cannot paint, where the material belongs to the group.
  Widget _buildGlass(
    BuildContext context,
    LiquidGlassFlexDeform deform,
    Size restSize, {
    LiquidGlassStyle? style,
  }) {
    final bool deformed = !deform.isRest && !restSize.isEmpty;

    final LiquidGlassAppearance appearance =
        style?.appearance ?? _appearance;
    final LiquidGlassRefraction baseRefraction =
        style?.refraction ?? _refraction;

    // The shape is passed through untouched. The shader evaluates it at REST
    // size in a domain divided by `shapeScale`, so the whole outline stretches
    // -- a circle becomes an ellipse rather than a stadium with flat runs.
    final LiquidGlassShape shape = style == null
        ? _shape
        : (style.shape ??
            const LiquidGlassShape.continuousRoundedRectangle());
    final Offset shapeScale =
        deformed ? deform.scaleFrom(restSize) : const Offset(1, 1);
    // Clips can be pinned circular independently, to reproduce the state where
    // the shader stretched but they did not.
    final Offset clipScale =
        deformed ? deform.clipScaleFrom(restSize) : const Offset(1, 1);

    // Pressing deepens the optics rather than popping the scale — this is
    // the cue that reads as glass under pressure instead of rubber. Only
    // a touch-driven lens has a spec to read the boost from; an external
    // deform carries no press of its own.
    final LiquidGlassFlex? pressSpec = widget.touch?.flex;
    final LiquidGlassRefraction refraction =
        deform.pressAmount > 0 && pressSpec != null
            ? liquidGlassFlexRefraction(
                baseRefraction, pressSpec, deform.pressAmount)
            : baseRefraction;

    final LiquidGlassLensScope? scope = LiquidGlassLensScope.maybeOf(context);
    // `true`/`null` (here or on the scope) → prefer Impeller, but only when
    // the shader path is actually supported; explicit `false` forces it off.
    final bool impeller =
        (widget.useImpellerBackdrop ?? scope?.useImpellerBackdrop ?? true) &&
            ui.ImageFilter.isShaderFilterSupported;

    LiquidGlassLensRenderMode? mode;
    if (impeller) {
      mode = LiquidGlassLensRenderMode.impellerBackdrop;
    } else if (scope != null) {
      mode = LiquidGlassLensRenderMode.skiaCapture;
    } else {
      _warnFrostedOnce('no Impeller and no ancestor LiquidGlassView');
    }

    if (mode == null || !LiquidGlassShaders.isLoadedFor(impeller)) {
      // Frosted fallback — also shown for the brief async shader load on the
      // very first lens of the app's lifetime. If this lens's backend differs
      // from the one preloaded in initState, kick its load and rebuild.
      if (mode != null) {
        LiquidGlassShaders.ensureLoaded(impeller).then((_) {
          if (mounted) setState(() {});
        }).catchError((Object _) {});
      }
      return _FrostedGlassFallback(
        shape: shape,
        shapeScale: shapeScale,
        appearance: appearance,
        visible: widget.visibility,
        child: widget.child == null
            ? null
            : liquidGlassFlexChild(
                deform: deform,
                restSize: restSize,
                child: widget.child!,
              ),
      );
    }

    _mainShader ??= LiquidGlassShaders.createMainShader(impeller);
    if (mode == LiquidGlassLensRenderMode.skiaCapture) {
      _borderShader ??= LiquidGlassShaders.createBorderShader(impeller);
    }

    final Size screenSize = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);

    // Clip at the deformed lens bounds, scale the content inside it: the
    // child stretches as pixels but can never spill past the glass edge.
    final double clipRadius = liquidGlassClipCornerRadius(shape);
    final Widget? clippedChild = widget.child == null
        ? null
        : ClipRRect(
            // Elliptical while deformed, so the clip follows the stretched
            // outline the shader draws instead of a fixed-radius rounded rect.
            borderRadius: deformed
                ? BorderRadius.all(Radius.elliptical(
                    clipRadius * clipScale.dx, clipRadius * clipScale.dy))
                : BorderRadius.circular(clipRadius),
            child: liquidGlassFlexChild(
              deform: deform,
              restSize: restSize,
              child: widget.child!,
            ),
          );

    // Instant show/hide: when hidden the glass paint is skipped
    // (glassEnabled = false, no backdrop cost) and the child is removed
    // entirely, so nothing is left behind.
    final bool visible = widget.visibility;
    return _RawLiquidGlassLens(
      mode: mode,
      mainShader: _mainShader!,
      borderShader: _borderShader,
      shape: shape,
      shapeScale: shapeScale,
      clipScale: clipScale,
      refraction: refraction,
      appearance: appearance,
      borderAlpha: 1.0,
      glassEnabled: visible,
      honorBackdropAlpha: widget.honorBackdropAlpha,
      screenSize: screenSize,
      devicePixelRatio: dpr,
      scope: scope,
      child: visible ? clippedChild : null,
    );
  }
}

class _RawLiquidGlassLens extends SingleChildRenderObjectWidget {
  final LiquidGlassLensRenderMode mode;
  final ui.FragmentShader mainShader;
  final ui.FragmentShader? borderShader;
  final LiquidGlassShape shape;
  final Offset shapeScale;
  final Offset clipScale;
  final LiquidGlassRefraction refraction;
  final LiquidGlassAppearance appearance;
  final double borderAlpha;
  final bool glassEnabled;
  final bool honorBackdropAlpha;
  final Size screenSize;
  final double devicePixelRatio;
  final LiquidGlassLensScope? scope;

  const _RawLiquidGlassLens({
    required this.mode,
    required this.mainShader,
    required this.borderShader,
    required this.shape,
    required this.shapeScale,
    required this.clipScale,
    required this.refraction,
    required this.appearance,
    required this.borderAlpha,
    required this.glassEnabled,
    required this.honorBackdropAlpha,
    required this.screenSize,
    required this.devicePixelRatio,
    required this.scope,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassLens(
      mode: mode,
      mainShader: mainShader,
      borderShader: borderShader,
      shape: shape,
      shapeScale: shapeScale,
      clipScale: clipScale,
      refraction: refraction,
      appearance: appearance,
      borderAlpha: borderAlpha,
      glassEnabled: glassEnabled,
      honorBackdropAlpha: honorBackdropAlpha,
      screenSize: screenSize,
      devicePixelRatio: devicePixelRatio,
      captureRevision: scope?.captureRevision,
      currentImage: scope?.currentImage,
      captureFallback: scope?.captureFallback,
      backgroundRenderBox: scope?.backgroundRenderBox,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderLiquidGlassLens renderObject) {
    renderObject
      ..mode = mode
      ..mainShader = mainShader
      ..borderShader = borderShader
      ..shape = shape
      ..shapeScale = shapeScale
      ..clipScale = clipScale
      ..refraction = refraction
      ..appearance = appearance
      ..borderAlpha = borderAlpha
      ..glassEnabled = glassEnabled
      ..honorBackdropAlpha = honorBackdropAlpha
      ..screenSize = screenSize
      ..devicePixelRatio = devicePixelRatio
      ..captureRevision = scope?.captureRevision
      ..currentImage = scope?.currentImage
      ..captureFallback = scope?.captureFallback
      ..backgroundRenderBox = scope?.backgroundRenderBox;
  }
}

/// Non-refracting stand-in: backdrop blur + tint + hairline border.
/// Used where real refraction is impossible (Skia without a captured
/// background) and during the one-time async shader load.
class _FrostedGlassFallback extends StatelessWidget {
  final LiquidGlassShape shape;
  final LiquidGlassAppearance appearance;
  final bool visible;

  /// Deformed size / rest size; `(1,1)` when undeformed.
  final Offset shapeScale;
  final Widget? child;

  const _FrostedGlassFallback({
    required this.shape,
    required this.appearance,
    required this.visible,
    this.shapeScale = const Offset(1, 1),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Hidden: leave nothing behind (instant), matching the refracting
    // path where the child is removed and the glass paint is skipped.
    if (!visible) return const SizedBox.shrink();

    final double radius = liquidGlassClipCornerRadius(shape);
    // Elliptical while deformed, so the frosted lens stretches its OUTLINE
    // the same way the refracting one does.
    final BorderRadius borderRadius =
        (shapeScale.dx == 1.0 && shapeScale.dy == 1.0)
            ? BorderRadius.circular(radius)
            : BorderRadius.all(Radius.elliptical(
                radius * shapeScale.dx, radius * shapeScale.dy));
    // Without refraction, blur is what sells "glass" — give it a floor
    // so a lens configured with zero blur still reads as frosted.
    final double sigmaX =
        appearance.blur.sigmaX > 0 ? appearance.blur.sigmaX : 10.0;
    final double sigmaY =
        appearance.blur.sigmaY > 0 ? appearance.blur.sigmaY : 10.0;
    final Color tint = appearance.color.a > 0
        ? appearance.color
        : const Color(0x14FFFFFF);
    final Color borderColor =
        shape.borderColor ?? const Color(0x40FFFFFF);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor,
              width: shape.borderWidth > 0 ? shape.borderWidth : 1.0,
            ),
          ),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}
