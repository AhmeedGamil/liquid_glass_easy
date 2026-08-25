import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../lens/liquid_glass_lens_scope.dart';
import '../utils/liquid_glass_adaptivity.dart';
import '../utils/liquid_glass_adaptivity_driver.dart';

/// An invisible region that **drives adaptivity for everything inside
/// it** — the group form of `LiquidGlassStyle.adaptivity`, with zero
/// wiring.
///
/// The area paints nothing. Its laid-out bounds are the measured
/// region: through the enclosing `LiquidGlassView`'s luminance sampler
/// it reads the background under itself, decides one dark/light verdict
/// (hysteresis, animated flips — the same machine every adaptive widget
/// uses), and every adaptive descendant follows it automatically. One
/// region, one verdict, lockstep flips for the whole cluster:
///
/// ```dart
/// Positioned(
///   left: 0, right: 0, bottom: 0, height: 160,
///   child: LiquidGlassAdaptiveArea(
///     adaptivity: LiquidGlassAdaptivity(...),
///     child: Stack(children: [myNavBar, mySidePill]),
///   ),
/// )
/// ```
///
/// **What descendants do.** A descendant with no `adaptivity` of its
/// own inherits the area's (palettes, duration, everything). A
/// descendant with its own `adaptivity` keeps its palettes but still
/// follows the area's verdict — unless it carries an explicit
/// `permanentBrightness` (manual always wins) or its own `link`
/// (an explicit channel wins over the enclosing area).
///
/// **Outside followers.** Give the area's adaptivity a
/// [LiquidGlassAdaptivity.link] and the area **publishes** its verdict
/// there, so widgets that can't sit inside the subtree (other overlays,
/// pipelines) can follow the same verdict by carrying the same link.
///
/// **Verdict sources**, in the usual priority order: a manual
/// `permanentBrightness` on [adaptivity]; else sampling through the
/// enclosing `LiquidGlassView` (opt in with its `adaptiveSampling`);
/// else the platform brightness. Without a view (standalone Impeller)
/// the area still works — it just can't sample.
class LiquidGlassAdaptiveArea extends StatefulWidget {
  /// The area's adaptivity: the palettes/duration descendants inherit,
  /// the optional manual verdict, and the optional publish [link].
  final LiquidGlassAdaptivity adaptivity;

  /// The subtree the verdict applies to. Laid out as-is — the area adds
  /// no visuals and no constraints of its own.
  final Widget child;

  /// Also drive the system bars' icon brightness from this area's
  /// verdict (see [LiquidGlassSystemChrome]) — dark backdrop → light
  /// icons, flipping with the glass. Off by default.
  ///
  /// The area must **cover the bar's probe point** for this to work:
  /// the bottom-center of the screen for [LiquidGlassSystemChrome
  /// .navigationBar], the top-center for `.statusBar` — an edge-pinned
  /// band qualifies, a floating pill does not.
  final LiquidGlassSystemChrome systemChrome;

  /// Debug: draw a cyan outline around the exact rect this area samples
  /// (its laid-out bounds). Cyan on purpose — the blender's
  /// `debugClipBounds` is magenta, so both overlays can be on at once.
  /// Off by default.
  final bool debugBounds;

  const LiquidGlassAdaptiveArea({
    super.key,
    required this.adaptivity,
    required this.child,
    this.systemChrome = LiquidGlassSystemChrome.none,
    this.debugBounds = false,
  });

  /// The enclosing area's scope, or `null` when there is none. Adaptive
  /// widgets use this to inherit the area's adaptivity and follow its
  /// verdict.
  static LiquidGlassAdaptiveAreaScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LiquidGlassAdaptiveAreaScope>();

  @override
  State<LiquidGlassAdaptiveArea> createState() =>
      _LiquidGlassAdaptiveAreaState();
}

/// What a [LiquidGlassAdaptiveArea] exposes to its descendants: the
/// [adaptivity] to inherit and the [link] carrying the area's verdict.
class LiquidGlassAdaptiveAreaScope extends InheritedWidget {
  /// The area's adaptivity, inherited by descendants that have none.
  final LiquidGlassAdaptivity adaptivity;

  /// The link the area publishes its verdict on; descendants follow it.
  ///
  /// `null` means **config only**: descendants inherit [adaptivity]'s
  /// palettes but resolve their OWN verdict from their own backdrop.
  /// The scaffold hands its chrome palettes down this way, so an app
  /// bar is judged by the pixels behind the app bar rather than by a
  /// strip it does not cover.
  final LiquidGlassAdaptivityLink? link;

  const LiquidGlassAdaptiveAreaScope({
    super.key,
    required this.adaptivity,
    this.link,
    required super.child,
  });

  @override
  bool updateShouldNotify(LiquidGlassAdaptiveAreaScope oldWidget) =>
      adaptivity != oldWidget.adaptivity || !identical(link, oldWidget.link);
}

class _LiquidGlassAdaptiveAreaState extends State<LiquidGlassAdaptiveArea>
    with TickerProviderStateMixin, LiquidGlassAdaptiveClient {
  /// One-time debug notice when the area can't sample (no view, or a
  /// view that didn't opt into `adaptiveSampling`).
  static bool _warnedNoSampler = false;

  /// The shared verdict machine — the area is a pure publisher: it
  /// samples its bounds, the driver decides, descendants follow.
  late final LiquidGlassAdaptivityDriver _driver =
      LiquidGlassAdaptivityDriver(vsync: this);

  /// Private publish link, created only when [widget.adaptivity] didn't
  /// bring its own.
  LiquidGlassAdaptivityLink? _ownLink;

  LiquidGlassAdaptivityLink get _publishLink =>
      widget.adaptivity.link ?? (_ownLink ??= LiquidGlassAdaptivityLink());

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
    _ownLink?.dispose();
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

  void _warnNoSamplerOnce(LiquidGlassLensScope? scope) {
    assert(() {
      if (!_warnedNoSampler) {
        _warnedNoSampler = true;
        debugPrint(
          'LiquidGlassAdaptiveArea: background sampling unavailable '
          '(${scope == null ? 'no ancestor LiquidGlassView' : 'the ancestor '
              'LiquidGlassView has no adaptiveSampling'}). The verdict '
          'falls back to permanentBrightness / the app theme\'s '
          'brightness (see LiquidGlassAdaptivity.brightnessFallback). '
          'Pass adaptiveSampling: LiquidGlassAdaptiveSampling() to the '
          'view (LiquidGlassScaffold does this automatically).',
        );
      }
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassAdaptivity adaptivity = widget.adaptivity;
    final LiquidGlassLensScope? scope = LiquidGlassLensScope.maybeOf(context);
    // A host's sampler redirect (e.g. the nav bar's outer view routing
    // clients to its inner pre-glass sampler) wins over the enclosing
    // view's own sampler.
    final LiquidGlassAdaptiveSamplerScope? samplerScope =
        LiquidGlassAdaptiveSamplerScope.maybeOf(context);
    final void Function(LiquidGlassAdaptiveClient)? register =
        samplerScope?.register ?? scope?.registerAdaptiveClient;
    final void Function(LiquidGlassAdaptiveClient)? unregister =
        samplerScope?.unregister ?? scope?.unregisterAdaptiveClient;
    final bool canSample = register != null;
    final bool wantSampling = _driver.samplingWanted(adaptivity,
        following: false, canRegister: canSample);
    if (adaptivity.permanentBrightness == null && !canSample) {
      _warnNoSamplerOnce(scope);
    }

    _syncRegistration(
        register: wantSampling ? register : null, unregister: unregister);
    _driver.onResync = _adaptResync;
    _driver.sync(
      adaptivity,
      canSample: canSample,
      fallbackBrightness: liquidGlassFallbackBrightness(context, adaptivity),
      publish: _publishLink,
    );

    Widget child = widget.child;
    if (widget.debugBounds) {
      // Passthrough keeps the child's layout untouched; the overlay just
      // traces the area's own bounds — i.e. the sampled rect.
      child = Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF00FFFF), width: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (widget.systemChrome != LiquidGlassSystemChrome.none) {
      // The area's verdict rides its publish link, so the annotation
      // rebuilds exactly when the verdict flips. Before any verdict the
      // chrome sits on the same entry guess the palettes use.
      final Brightness guess = adaptivity.permanentBrightness ??
          adaptivity.initialBrightness ??
          liquidGlassFallbackBrightness(context, adaptivity);
      final Widget inner = child;
      child = ValueListenableBuilder<Brightness?>(
        valueListenable: _publishLink,
        builder: (context, verdict, _) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: liquidGlassSystemChromeStyle(
              verdict ?? guess, widget.systemChrome),
          child: inner,
        ),
      );
    }

    return LiquidGlassAdaptiveAreaScope(
      adaptivity: adaptivity,
      link: _publishLink,
      child: child,
    );
  }
}

/// The animated dark/light verdict, published to everything a host draws
/// inside itself.
///
/// A lens hands its child the resolved **content color** through
/// `IconTheme`/`DefaultTextStyle`, which is all an `Icon` or `Text`
/// needs. Anything wanting its OWN pair of colors on the same verdict —
/// the tab bar's static selection pill, sitting on the bar's glass —
/// needs the verdict itself, not one color drawn from it. That is what
/// this carries.
///
/// [flipT] is the driver's animated flip position, so a descendant that
/// lerps its own palette on it changes in step with its host, on the
/// same curve, over the same frames.
@internal
class LiquidGlassAdaptiveVerdictScope extends InheritedWidget {
  /// `0` = the light-background palette, `1` = the dark-background one.
  /// Animated: it sweeps between them over the flip.
  final double flipT;

  const LiquidGlassAdaptiveVerdictScope({
    super.key,
    required this.flipT,
    required super.child,
  });

  /// The enclosing host's flip position, or `null` when nothing above is
  /// adaptive — in which case a descendant keeps its static color.
  static double? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LiquidGlassAdaptiveVerdictScope>()
      ?.flipT;

  /// Resolves [adaptivity]'s glass palette against the enclosing
  /// verdict, falling back to [fallback] where there is none.
  static Color resolve(
    BuildContext context,
    LiquidGlassAdaptivity? adaptivity,
    Color fallback,
  ) {
    if (adaptivity == null || adaptivity.isNone) return fallback;
    final double? t = maybeOf(context);
    if (t == null) return fallback;
    return Color.lerp(
        adaptivity.glassColorOnLight, adaptivity.glassColorOnDark, t)!;
  }

  @override
  bool updateShouldNotify(LiquidGlassAdaptiveVerdictScope oldWidget) =>
      oldWidget.flipT != flipT;
}
