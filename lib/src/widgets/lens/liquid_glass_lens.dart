import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../utils/liquid_glass_press.dart';
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

  /// Makes the lens deform under touch — press it and it compresses, drag
  /// it and it elongates along the pull, pinches in the cross axis and
  /// leans after your finger, then springs back with a wobble.
  ///
  /// The lens itself does not move; only its shape and its content deform.
  /// `null` (the default) disables the behaviour entirely — no gesture
  /// listener, no ticker, nothing added to the tree.
  ///
  /// Ignored inside a `LiquidGlassBlender`, whose metaball surface owns
  /// its members' geometry.
  final LiquidGlassPress? press;

  /// Content rendered on top of the glass, clipped to the lens shape.
  final Widget? child;

  const LiquidGlassLens({
    super.key,
    this.style = const LiquidGlassStyle(),
    this.visibility = true,
    this.useImpellerBackdrop,
    this.press,
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

  /// Spring driver behind [LiquidGlassLens.press]. Created on first use, so
  /// a lens without `press` never allocates a ticker.
  LiquidGlassPressDriver? _pressDriver;

  LiquidGlassPressDriver _ensurePressDriver(LiquidGlassPress spec) =>
      (_pressDriver ??= LiquidGlassPressDriver(vsync: this, spec: spec))
        ..spec = spec;

  @override
  void dispose() {
    _pressDriver?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When an ancestor LiquidGlassBlender is present, this lens stops
    // painting its own glass: it hands its geometry to the blender, which
    // merges all member lenses into one metaball surface. The blender owns
    // its members' geometry, so `press` has nothing to deform here.
    final blenderScope = LiquidGlassBlenderScope.maybeOf(context);
    if (blenderScope != null) {
      return blenderScope.buildMember(
        style: widget.style,
        visible: widget.visibility,
        child: widget.child,
      );
    }

    final LiquidGlassPress? press = widget.press;
    if (press == null) {
      return _buildGlass(context, LiquidGlassPressDeform.none, Size.zero);
    }

    // The lens takes its size from layout, so the rest size has to come
    // from the incoming constraints — that is what the deformation is
    // measured against, and what the child is laid out at.
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size rest = constraints.biggest;
        if (!rest.width.isFinite || !rest.height.isFinite || rest.isEmpty) {
          // Unbounded or degenerate: nothing to deform against.
          return _buildGlass(context, LiquidGlassPressDeform.none, Size.zero);
        }

        final driver = _ensurePressDriver(press)..restSize = rest;

        return Listener(
          // Translucent, never opaque: the press must not start swallowing
          // taps that reached the content (or the UI behind) before.
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => driver.down(event.localPosition, rest),
          // Accumulate deltas, not positions — the box is deforming under
          // the finger, so a lens-local position would feed back on itself.
          onPointerMove: (event) => driver.move(event.delta),
          onPointerUp: (_) => driver.up(),
          onPointerCancel: (_) => driver.up(),
          child: SizedBox.fromSize(
            size: rest,
            child: ValueListenableBuilder<LiquidGlassPressDeform>(
              valueListenable: driver,
              builder: (context, deform, _) => liquidGlassPressBox(
                deform: deform,
                restSize: rest,
                child: _buildGlass(context, deform, rest),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the lens proper. [deform] is [LiquidGlassPressDeform.none] and
  /// [restSize] is [Size.zero] whenever `press` is unset — in that case
  /// every press-related branch below collapses to the original behaviour.
  Widget _buildGlass(
    BuildContext context,
    LiquidGlassPressDeform deform,
    Size restSize,
  ) {
    final bool deformed = !deform.isRest && !restSize.isEmpty;

    // Cap the radius against the *deformed* size so a squeezed capsule
    // stays a capsule instead of self-intersecting at the rim.
    final LiquidGlassShape shape = deformed
        ? liquidGlassPressShape(_shape, deform.sizeFrom(restSize))
        : _shape;

    // Pressing deepens the optics rather than popping the scale — this is
    // the cue that reads as glass under pressure instead of rubber.
    final LiquidGlassRefraction refraction = deform.pressAmount > 0
        ? liquidGlassPressRefraction(
            _refraction, widget.press!, deform.pressAmount)
        : _refraction;

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
        appearance: _appearance,
        visible: widget.visibility,
        child: widget.child == null
            ? null
            : liquidGlassPressChild(
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
    final Widget? clippedChild = widget.child == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(shape),
            ),
            child: liquidGlassPressChild(
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
      refraction: refraction,
      appearance: _appearance,
      borderAlpha: 1.0,
      glassEnabled: visible,
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
  final LiquidGlassRefraction refraction;
  final LiquidGlassAppearance appearance;
  final double borderAlpha;
  final bool glassEnabled;
  final Size screenSize;
  final double devicePixelRatio;
  final LiquidGlassLensScope? scope;

  const _RawLiquidGlassLens({
    required this.mode,
    required this.mainShader,
    required this.borderShader,
    required this.shape,
    required this.refraction,
    required this.appearance,
    required this.borderAlpha,
    required this.glassEnabled,
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
      refraction: refraction,
      appearance: appearance,
      borderAlpha: borderAlpha,
      glassEnabled: glassEnabled,
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
      ..refraction = refraction
      ..appearance = appearance
      ..borderAlpha = borderAlpha
      ..glassEnabled = glassEnabled
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
  final Widget? child;

  const _FrostedGlassFallback({
    required this.shape,
    required this.appearance,
    required this.visible,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Hidden: leave nothing behind (instant), matching the refracting
    // path where the child is removed and the glass paint is skipped.
    if (!visible) return const SizedBox.shrink();

    final double radius = liquidGlassClipCornerRadius(shape);
    final BorderRadius borderRadius = BorderRadius.circular(radius);
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
