import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens_scope.dart';
import '../utils/liquid_glass_adaptivity.dart';
import '../utils/liquid_glass_adaptivity_driver.dart';
import 'liquid_glass_adaptive_area.dart';

/// Makes **bare content adaptive** — icons and text that sit directly on
/// the page with no glass behind them (a hero title over a photo, a
/// floating caption) follow the animated adaptive content color exactly
/// like a lens child would.
///
/// A `LiquidGlassLens` installs the adaptive content color only for its
/// own child; content outside any lens has no way to adapt. This wrapper
/// closes that gap: it runs the same verdict machine and installs the
/// animated `IconTheme` + `DefaultTextStyle` over [child], so any `Icon`
/// or `Text` inside that doesn't hardcode a color adapts automatically.
///
/// ```dart
/// LiquidGlassAdaptiveContent(
///   child: Text('Thailand Trip'),   // no explicit color
/// )
/// ```
///
/// **Verdict sources** — the standard consumer chain: [adaptivity]'s
/// manual `permanentBrightness` → its explicit `link` → the enclosing
/// [LiquidGlassAdaptiveArea] → own sampling of this widget's bounds
/// through the enclosing `LiquidGlassView` (needs its
/// `adaptiveSampling`) → platform brightness. With [adaptivity] `null`
/// the enclosing area's config is inherited entirely; with no area
/// either, the widget is inert and just returns [child].
class LiquidGlassAdaptiveContent extends StatefulWidget {
  /// The adaptivity to apply. `null` (the default) inherits the
  /// enclosing [LiquidGlassAdaptiveArea]'s config — palettes, duration,
  /// verdict. [LiquidGlassAdaptivity.none] opts out entirely.
  final LiquidGlassAdaptivity? adaptivity;

  /// The content the animated color applies to. Bare `Icon`/`Text`
  /// (no explicit color) adapt automatically. Optional when [builder]
  /// is given; when both are set [builder] wins (and may render it).
  final Widget? child;

  /// Builds fully custom adaptive content instead of relying on the
  /// `IconTheme`/`DefaultTextStyle` install over [child].
  ///
  /// Called with the animated content `color` (the exact color the
  /// widget would otherwise push into those themes) and the current
  /// dark/light `brightness` verdict — so content that ignores those
  /// themes (an `SvgPicture`, a `CustomPaint`) can still adapt: tint
  /// with `color`, or swap assets on `brightness`. Rebuilt every frame
  /// of a palette flip, exactly like the theme install.
  ///
  /// ```dart
  /// LiquidGlassAdaptiveContent(
  ///   builder: (context, color, brightness) => SvgPicture.asset(
  ///     'assets/leaf.svg',
  ///     colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  ///   ),
  /// )
  /// ```
  final Widget Function(
      BuildContext context, Color color, Brightness brightness)? builder;

  const LiquidGlassAdaptiveContent({
    super.key,
    this.adaptivity,
    this.child,
    this.builder,
  }) : assert(child != null || builder != null,
            'LiquidGlassAdaptiveContent needs a child, a builder, or both');

  @override
  State<LiquidGlassAdaptiveContent> createState() =>
      _LiquidGlassAdaptiveContentState();
}

class _LiquidGlassAdaptiveContentState extends State<LiquidGlassAdaptiveContent>
    with TickerProviderStateMixin, LiquidGlassAdaptiveClient {
  /// The shared verdict machine — same driver as the lens/area/bar.
  late final LiquidGlassAdaptivityDriver _driver =
      LiquidGlassAdaptivityDriver(vsync: this);

  /// Registration bookkeeping against the view's sampler (same contract
  /// as the lens's).
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
    // Adaptivity precedence: the widget's own config, else the enclosing
    // area's — and `LiquidGlassAdaptivity.none` opts out of both. The
    // verdict source: manual override → explicit link → enclosing
    // area's link → own sampling → platform brightness.
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
    final void Function(LiquidGlassAdaptiveClient)? register =
        samplerScope?.register ?? scope?.registerAdaptiveClient;
    final void Function(LiquidGlassAdaptiveClient)? unregister =
        samplerScope?.unregister ?? scope?.unregisterAdaptiveClient;
    final bool wantSampling = _driver.samplingWanted(adaptivity,
        following: follow != null, canRegister: register != null);

    _syncRegistration(
        register: wantSampling ? register : null, unregister: unregister);
    _driver.onResync = _adaptResync;
    final Brightness fallbackBrightness =
        liquidGlassFallbackBrightness(context, adaptivity);
    _driver.sync(
      adaptivity,
      follow: follow,
      canSample: register != null,
      fallbackBrightness: fallbackBrightness,
    );
    if (adaptivity == null) {
      // Inert (opted out / nothing to follow): the child is unchanged.
      // A builder-only caller still renders — it gets the ambient
      // content color and the platform brightness, just no adaptation.
      if (widget.child != null) return widget.child!;
      final Color ambient = IconTheme.of(context).color ??
          DefaultTextStyle.of(context).style.color ??
          (fallbackBrightness == Brightness.dark ? Colors.white : Colors.black);
      return widget.builder!(context, ambient, fallbackBrightness);
    }

    // Rebuild while the palette animates — idle between flips.
    return AnimatedBuilder(
      animation: _driver.listenable!,
      builder: (context, _) {
        final Color content = _driver.contentColor(adaptivity);
        // The discrete verdict, resolved to the entry guess before the
        // first one lands so the builder never receives null.
        final Brightness brightness = _driver.verdict ??
            adaptivity.initialBrightness ??
            fallbackBrightness;
        if (widget.builder != null) {
          return widget.builder!(context, content, brightness);
        }
        return IconTheme.merge(
          data: IconThemeData(color: content),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: content),
            child: widget.child!,
          ),
        );
      },
    );
  }
}
