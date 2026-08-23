import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

final List<double> _liquidGlassLinearSrgb8 = List<double>.unmodifiable(
  List<double>.generate(256, (int channel) {
    final double encoded = channel / 255.0;
    return encoded <= 0.04045
        ? encoded / 12.92
        : math.pow((encoded + 0.055) / 1.055, 2.4).toDouble();
  }),
);

/// WCAG relative luminance for an 8-bit sRGB pixel. The channel transfer
/// function is applied before the Rec. 709 weights; applying the weights
/// directly to encoded bytes gives incorrect answers for saturated colors.
@internal
double liquidGlassRelativeLuminanceFromSrgb8(int red, int green, int blue) {
  return 0.2126 * _liquidGlassLinearSrgb8[red] +
      0.7152 * _liquidGlassLinearSrgb8[green] +
      0.0722 * _liquidGlassLinearSrgb8[blue];
}

/// Converts relative luminance to normalized CIE L* perceptual lightness.
/// Unlike raw luminance, equal steps in this value are intended to look
/// approximately equal to human vision. `0.5` is the neutral light/dark split.
@internal
double liquidGlassPerceptualLightness(double relativeLuminance) {
  final double luminance = relativeLuminance.clamp(0.0, 1.0);
  const double epsilon = 216 / 24389;
  const double kappa = 24389 / 27;
  final double lStar = luminance <= epsilon
      ? kappa * luminance
      : 116 * math.pow(luminance, 1 / 3).toDouble() - 16;
  return (lStar / 100).clamp(0.0, 1.0);
}

/// Background-only statistics for one client's complete region. Every pixel
/// across every reported rect contributes to one area-weighted value, so the
/// eventual result remains one uniform verdict for the whole glass.
@immutable
@internal
class LiquidGlassBackdropSample {
  final double meanLuminance;

  /// Mean normalized CIE L* of the sampled background. This is the primary
  /// dark/light decision signal and is independent of all configured colors.
  final double meanLightness;

  /// Diagnostic share of samples whose CIE L* is at least 0.5. Retained for
  /// older custom sampling clients; package widgets use [meanLightness].
  final double lightFraction;
  final int sampleCount;

  const LiquidGlassBackdropSample({
    required this.meanLuminance,
    required this.meanLightness,
    required this.lightFraction,
    required this.sampleCount,
  })  : assert(meanLuminance >= 0 && meanLuminance <= 1),
        assert(meanLightness >= 0 && meanLightness <= 1),
        assert(lightFraction >= 0 && lightFraction <= 1),
        assert(sampleCount > 0);

  /// Test/helper constructor for building the same perceptual average the
  /// pixel sampler produces.
  @visibleForTesting
  factory LiquidGlassBackdropSample.fromLuminances(
      Iterable<double> luminances) {
    double luminanceSum = 0;
    double lightnessSum = 0;
    int lightCount = 0;
    int count = 0;
    for (final double value in luminances) {
      final double luminance = value.clamp(0.0, 1.0);
      final double lightness = liquidGlassPerceptualLightness(luminance);
      luminanceSum += luminance;
      lightnessSum += lightness;
      if (lightness >= 0.5) lightCount++;
      count++;
    }
    if (count == 0) {
      throw ArgumentError.value(
          luminances, 'luminances', 'must contain at least one value');
    }
    return LiquidGlassBackdropSample(
      meanLuminance: luminanceSum / count,
      meanLightness: lightnessSum / count,
      lightFraction: lightCount / count,
      sampleCount: count,
    );
  }
}

/// Which system bars an adaptive widget's verdict also drives — the
/// glass and the OS chrome flip together, like Android's own gesture
/// pill.
///
/// Honored by `LiquidGlassAdaptiveArea.systemChrome` and
/// `LiquidGlassScaffold.systemChrome`. Implemented declaratively with
/// Flutter's `AnnotatedRegion`, so the influence exists exactly while
/// the widget covers the system bar's probe point (bottom-center of the
/// screen for the navigation bar, top-center for the status bar) and
/// vanishes on unmount — no global state, nothing to undo.
///
/// Only the **icon brightness** of the bars is driven; their colors are
/// never touched. With [none] (the default) no `AnnotatedRegion` exists
/// in the tree at all — the feature is completely off.
enum LiquidGlassSystemChrome {
  /// System bars untouched (default).
  none,

  /// Drive the status bar's icon brightness.
  statusBar,

  /// Drive the navigation bar's icon (and gesture hint) brightness.
  navigationBar,

  /// Drive both bars.
  both,
}

/// Maps a backdrop [brightness] verdict to the system-bar styling for
/// [chrome]: dark backdrop → light icons, and vice versa. Sets only the
/// icon-brightness fields (plus iOS's `statusBarBrightness`) — bar
/// colors are left untouched.
@internal
SystemUiOverlayStyle liquidGlassSystemChromeStyle(
    Brightness brightness, LiquidGlassSystemChrome chrome) {
  final Brightness icons =
      brightness == Brightness.dark ? Brightness.light : Brightness.dark;
  final bool status = chrome == LiquidGlassSystemChrome.statusBar ||
      chrome == LiquidGlassSystemChrome.both;
  final bool nav = chrome == LiquidGlassSystemChrome.navigationBar ||
      chrome == LiquidGlassSystemChrome.both;
  return SystemUiOverlayStyle(
    statusBarIconBrightness: status ? icons : null,
    // iOS expresses the same thing inversely: the BAR's brightness
    // (a dark bar gets light content).
    statusBarBrightness: status ? brightness : null,
    systemNavigationBarIconBrightness: nav ? icons : null,
  );
}

/// Shares one adaptivity verdict between widgets that can't sit in the
/// same subtree, so they flip **together** — same state, same instant.
///
/// The common case doesn't need a link at all: wrap the widgets in a
/// `LiquidGlassAdaptiveArea` and they follow it automatically. Reach
/// for a link when a follower lives in a different subtree or pipeline:
/// a `LiquidGlassAdaptiveArea` **publishes** to the link it's given,
/// and any consumer widget given the same link **follows** it. Give
/// publisher and followers the same `duration` and their transitions
/// run in lockstep.
///
/// ```dart
/// final link = LiquidGlassAdaptivityLink();
///
/// LiquidGlassAdaptiveArea(                  // PUBLISHER — samples its bounds
///   adaptivity: LiquidGlassAdaptivity(link: link, ...),
///   child: ...,
/// )
/// LiquidGlassLens(                          // FOLLOWER — mirrors the area
///   style: LiquidGlassStyle(
///     adaptivity: LiquidGlassAdaptivity(link: link, ...),
///   ),
/// )
/// ```
///
/// Use exactly one publisher per link. The link is a plain
/// `ValueNotifier<Brightness?>`, so an app can also drive a whole group
/// by setting [value] itself.
class LiquidGlassAdaptivityLink extends ValueNotifier<Brightness?> {
  LiquidGlassAdaptivityLink() : super(null);

  /// Latest mean background lightness (normalized CIE L*, 0 = black,
  /// 1 = white) published by the area on every sample.
  ///
  /// Only followers running [LiquidGlassAdaptivity.continuousGlassColor]
  /// read it — they glide their tint from this, in step with the
  /// publisher. The binary verdict rides [value] as usual.
  final ValueNotifier<double?> lightness = ValueNotifier<double?>(null);

  @override
  void dispose() {
    lightness.dispose();
    super.dispose();
  }

  /// Re-delivers the current [value] even though it did not change.
  /// A publisher finishing a one-shot look (see
  /// [LiquidGlassAdaptivityController.adaptOnce]) whose verdict came
  /// out unchanged calls this so held followers waiting on the same
  /// request can complete theirs.
  @internal
  void republish() => notifyListeners();
}

/// Runtime pause/resume switch for [LiquidGlassAdaptivity] — attach one
/// via [LiquidGlassAdaptivity.controller] and every widget carrying that
/// config obeys it. Share one instance across configs for a page-wide
/// master switch.
///
/// **Disabled = hold, not off.** The palettes stay applied, frozen at
/// the current verdict (at mount that's the `initialBrightness` guess),
/// and background sampling stops completely — zero captures while
/// disabled. A manual `permanentBrightness` still applies (it is an
/// explicit override, not adaptation). On [enable] sampling resumes and
/// the next verdict **animates** in; [adaptOnce] instead takes a single
/// on-demand look while staying disabled. For a permanent opt-out use
/// [LiquidGlassAdaptivity.none] instead.
///
/// The classic use is entry control — mount frozen on the guess, adapt
/// only once the page has settled:
///
/// ```dart
/// final adaptCtrl = LiquidGlassAdaptivityController(enabled: false);
/// // ...adaptivity: LiquidGlassAdaptivity(controller: adaptCtrl, ...)
/// WidgetsBinding.instance.addPostFrameCallback((_) => adaptCtrl.enable());
/// ```
///
/// Owned by the developer — dispose it like any controller.
class LiquidGlassAdaptivityController extends ChangeNotifier {
  LiquidGlassAdaptivityController({bool enabled = true}) : _enabled = enabled;

  bool _enabled;

  /// Whether adaptivity is currently allowed to follow the background.
  bool get enabled => _enabled;

  /// Resumes adapting; the next verdict animates in.
  void enable() {
    if (_enabled) return;
    _enabled = true;
    notifyListeners();
  }

  /// Pauses adapting; the current palette holds and sampling stops.
  void disable() {
    if (!_enabled) return;
    _enabled = false;
    notifyListeners();
  }

  int _refreshGeneration = 0;

  /// Monotonic count of [adaptOnce] requests. Each attached widget
  /// compares it against the generation it last served, so every widget
  /// answers a request exactly once, at its own delivery pace.
  int get refreshGeneration => _refreshGeneration;

  /// While disabled, requests a **single** adaptation: every widget
  /// holding this controller takes exactly one look at its background,
  /// animates to the resulting verdict, and freezes again — [enabled]
  /// stays `false` throughout. Sampling runs for just that one capture.
  ///
  /// The classic use is event-driven adaptation — hold during a scroll,
  /// adapt once it settles:
  ///
  /// ```dart
  /// NotificationListener<ScrollEndNotification>(
  ///   onNotification: (_) { adaptCtrl.adaptOnce(); return false; },
  ///   child: ...,
  /// )
  /// ```
  ///
  /// A verdict that confirms the current palette moves nothing — the
  /// look still counts as taken. Followers of a link complete their
  /// look on the group's next delivery (the publishing area re-delivers
  /// even an unchanged verdict). While [enabled] this is a no-op:
  /// continuous adaptation is already live.
  void adaptOnce() {
    if (_enabled) return;
    _refreshGeneration++;
    notifyListeners();
  }
}

/// iOS-style adaptivity: the glass tint **and** the lens content switch
/// between two palettes depending on whether the background behind the
/// lens is dark or light.
///
/// Attach it to a style and `LiquidGlassLens` does the rest:
///
/// ```dart
/// LiquidGlassStyle(
///   adaptivity: LiquidGlassAdaptivity(
///     glassColorOnDark: Color(0x33000000),
///     contentColorOnDark: Colors.white,
///     glassColorOnLight: Color(0x40FFFFFF),
///     contentColorOnLight: Color(0xFF1C1C1E),
///   ),
/// )
/// ```
///
/// **How the verdict is decided**, in priority order:
///
/// 1. [permanentBrightness], when set — a manual override; no sampling
///    runs at all.
/// 2. Automatic sampling, when the lens sits inside a `LiquidGlassView`:
///    the view captures its `backgroundWidget` at a very low pixel ratio
///    and frame rate (see `LiquidGlassView.adaptiveSampling`), converts the
///    sampled sRGB pixels to perceptual CIE L* lightness, and classifies the
///    area with temporal smoothing and hysteresis.
/// 3. The platform brightness, as a last resort (a standalone Impeller
///    lens has no readable backdrop).
///
/// **What gets tinted.** The glass fill uses the active `glassColorOn*`
/// (overriding `appearance.color` while adaptivity is enabled). The
/// [child] is wrapped in `IconTheme` + `DefaultTextStyle` carrying the
/// active `contentColorOn*`, so any `Icon` or `Text` that doesn't
/// hardcode its own color adapts automatically. Both animate together
/// over [duration] on every flip.
@immutable
class LiquidGlassAdaptivity {
  /// Glass tint used while the background behind the lens is **dark**.
  ///
  /// Defaults to a dark veil, not a light one: the glass AGREES with the
  /// background — dark page, dark surface — and it is the content that
  /// contrasts. Inverting the two reads as a bright chip stamped on a
  /// dark page rather than as glass sitting in it.
  final Color glassColorOnDark;

  /// Content (icons/text) color used while the background is **dark**.
  /// Contrasts the surface, so it is the light one of the pair.
  final Color contentColorOnDark;

  /// Glass tint used while the background behind the lens is **light**.
  /// The mirror of [glassColorOnDark]: a light veil over a light page.
  final Color glassColorOnLight;

  /// Content (icons/text) color used while the background is **light**.
  /// Contrasts the surface, so it is the dark one of the pair.
  final Color contentColorOnLight;

  /// How long the flip between the two palettes animates.
  final Duration duration;

  /// Manual verdict override. When non-null, no background sampling runs
  /// and the palettes follow this value directly (still animated).
  /// `Brightness.dark` means "the background is dark".
  final Brightness? permanentBrightness;

  /// The palette to **assume before the first verdict arrives** — the
  /// developer's guess for what the widget mounts over. Unlike
  /// [permanentBrightness] it is a placeholder, not a verdict: sampling
  /// (or a link) still runs and takes over. When the first verdict
  /// confirms the guess nothing moves at all; when it differs, the
  /// palettes animate into the truth.
  ///
  /// `null` (the default) assumes the platform brightness — dark-mode
  /// users get the dark palette from the very first frame.
  final Brightness? initialBrightness;

  /// Optional verdict link (see [LiquidGlassAdaptivityLink]).
  ///
  /// On a **consumer** widget (lens, scroll edge, nav bar, …) a link
  /// always means **follow it**: the widget never samples and mirrors
  /// the link's verdict, flipping at the same instant as its publisher.
  /// On a `LiquidGlassAdaptiveArea` a link always means **publish to
  /// it**: the area broadcasts its verdict there for followers that
  /// can't sit inside the area's subtree. (Consumers *inside* an area
  /// follow it automatically — no link needed.)
  final LiquidGlassAdaptivityLink? link;

  /// Optional runtime pause/resume switch (see
  /// [LiquidGlassAdaptivityController]). While disabled the current
  /// palette holds, sampling stops, and link/sampled verdicts are
  /// ignored; a manual [permanentBrightness] still applies. `null`
  /// (the default) = always enabled.
  final LiquidGlassAdaptivityController? controller;

  /// Mean perceptual-background-lightness threshold below which the verdict
  /// flips to **dark**. The signal is normalized CIE L*: `0` is black, `1`
  /// is white, and `0.5` is the neutral dark/light split.
  ///
  /// Defaults to the neutral split, the same value as [lightAbove], so
  /// the verdict simply follows which side of the middle the background
  /// is on.
  ///
  /// Pulling the two apart opens an anti-strobe hysteresis band: inside
  /// it the current verdict holds, so a background hovering near the
  /// split cannot chatter between palettes. Worth doing for content that
  /// averages near mid-grey. Even with the band closed the driver
  /// smooths the signal and waits for two confirming samples before it
  /// flips, and a background landing exactly on the split holds rather
  /// than flipping — the band is a second line of defence, not the only
  /// one.
  final double darkBelow;

  /// Background-lightness threshold above which the verdict flips to
  /// **light**. See [darkBelow] for the band the two form when they
  /// differ.
  final double lightAbove;

  /// When `true` the **glass tint** tracks the background continuously —
  /// gliding through the whole range between [glassColorOnLight] and
  /// [glassColorOnDark] instead of switching between them. The content
  /// colors keep their binary flip either way, so text and icons never
  /// sit at a muddy half-tone.
  ///
  /// The glide runs on perceptual lightness: [kContinuousFloor] maps to
  /// the fully dark tint and [kContinuousCeiling] to the fully light
  /// one, with the ends clamped. Sample-to-sample jitter below a small
  /// delta is ignored, so a still background costs nothing.
  ///
  /// Needs a lightness source — its own sampling, or a followed link
  /// whose publisher samples. With only a manual `permanentBrightness`
  /// or the platform brightness there is nothing to glide along, and
  /// the tint falls back to the binary flip.
  final bool continuousGlassColor;

  /// Background lightness mapping to the fully **dark** glass tint.
  static const double kContinuousFloor = 0.2;

  /// Background lightness mapping to the fully **light** glass tint.
  static const double kContinuousCeiling = 0.8;

  /// Distinguishes the [none] sentinel from every real configuration
  /// (const canonicalization is by field values, so the sentinel needs
  /// one of its own).
  final bool _disabled;

  const LiquidGlassAdaptivity({
    this.glassColorOnDark = const Color(0x26000000),
    this.contentColorOnDark = const Color(0xFFFFFFFF),
    this.glassColorOnLight = const Color(0x3DFFFFFF),
    this.contentColorOnLight = const Color(0xFF1C1C1E),
    this.duration = const Duration(milliseconds: 300),
    this.permanentBrightness,
    this.initialBrightness,
    this.link,
    this.controller,
    this.darkBelow = 0.50,
    this.lightAbove = 0.50,
    this.continuousGlassColor = false,
  })  : _disabled = false,
        assert(darkBelow <= lightAbove, 'darkBelow must not exceed lightAbove'),
        assert(darkBelow >= 0 && lightAbove <= 1,
            'Thresholds are background lightness values in 0..1');

  const LiquidGlassAdaptivity._none()
      : glassColorOnDark = const Color(0x26000000),
        contentColorOnDark = const Color(0xFFFFFFFF),
        glassColorOnLight = const Color(0x3DFFFFFF),
        contentColorOnLight = const Color(0xFF1C1C1E),
        duration = const Duration(milliseconds: 300),
        permanentBrightness = null,
        initialBrightness = null,
        link = null,
        controller = null,
        darkBelow = 0.50,
        lightAbove = 0.50,
        continuousGlassColor = false,
        _disabled = true;

  /// The opt-out sentinel: a widget whose adaptivity is [none] is **not
  /// adaptive at all** — it keeps its plain style even inside a
  /// `LiquidGlassAdaptiveArea` (which it would otherwise inherit from).
  ///
  /// ```dart
  /// LiquidGlassLens(
  ///   style: LiquidGlassStyle(adaptivity: LiquidGlassAdaptivity.none),
  ///   ...
  /// )
  /// ```
  static const LiquidGlassAdaptivity none = LiquidGlassAdaptivity._none();

  /// Whether this is the [none] opt-out sentinel.
  bool get isNone => _disabled;

  /// A copy carrying everything but the [link].
  ///
  /// Used where a config is handed DOWN to widgets that must resolve
  /// their own verdict — the scaffold inheriting its palettes to the
  /// app bar / bottom bar / action. Keeping the link would make each of
  /// them follow the publisher instead of judging its own backdrop,
  /// which is exactly the coupling that has to stay opt-in.
  @internal
  LiquidGlassAdaptivity withoutLink() {
    if (link == null) return this;
    return LiquidGlassAdaptivity(
      glassColorOnDark: glassColorOnDark,
      contentColorOnDark: contentColorOnDark,
      glassColorOnLight: glassColorOnLight,
      contentColorOnLight: contentColorOnLight,
      duration: duration,
      permanentBrightness: permanentBrightness,
      initialBrightness: initialBrightness,
      controller: controller,
      darkBelow: darkBelow,
      lightAbove: lightAbove,
      continuousGlassColor: continuousGlassColor,
    );
  }

  /// Returns a copy with the given fields replaced.
  LiquidGlassAdaptivity copyWith({
    Color? glassColorOnDark,
    Color? contentColorOnDark,
    Color? glassColorOnLight,
    Color? contentColorOnLight,
    Duration? duration,
    Brightness? permanentBrightness,
    Brightness? initialBrightness,
    LiquidGlassAdaptivityLink? link,
    LiquidGlassAdaptivityController? controller,
    double? darkBelow,
    double? lightAbove,
    bool? continuousGlassColor,
  }) {
    return LiquidGlassAdaptivity(
      glassColorOnDark: glassColorOnDark ?? this.glassColorOnDark,
      contentColorOnDark: contentColorOnDark ?? this.contentColorOnDark,
      glassColorOnLight: glassColorOnLight ?? this.glassColorOnLight,
      contentColorOnLight: contentColorOnLight ?? this.contentColorOnLight,
      duration: duration ?? this.duration,
      permanentBrightness: permanentBrightness ?? this.permanentBrightness,
      initialBrightness: initialBrightness ?? this.initialBrightness,
      link: link ?? this.link,
      controller: controller ?? this.controller,
      darkBelow: darkBelow ?? this.darkBelow,
      lightAbove: lightAbove ?? this.lightAbove,
      continuousGlassColor:
          continuousGlassColor ?? this.continuousGlassColor,
    );
  }
}

/// Tuning for the background sampling that powers [LiquidGlassAdaptivity]
/// inside a `LiquidGlassView`.
///
/// The sampler is a second, tiny capture of the view's `backgroundWidget`
/// — completely separate from the rendering capture. It runs **only**
/// while at least one descendant lens has adaptivity enabled, is
/// self-paced (a new sample never starts before the previous readback
/// finished), and reads back a few kilobytes per sample. It is also
/// idle-gated: while no frames are being rendered (a fully static
/// screen), no captures run at all — pixels can only change through a
/// rendered frame, so a frameless stretch is guaranteed unchanged.
@immutable
class LiquidGlassAdaptiveSampling {
  /// Pixel ratio of the sampling capture — same meaning as
  /// `LiquidGlassView.pixelRatio`, just much lower. The default (0.05)
  /// turns a 400 px-wide background into a ~20 px sample. The sampler may
  /// raise it enough to satisfy [minimumRegionSamples] for a small client.
  final double pixelRatio;

  /// Maximum samples per second. The default (8) is plenty for a color
  /// flip that animates over ~250 ms.
  final double frameLimit;

  /// Minimum captured pixels across the shortest visible dimension of every
  /// registered region. This keeps a small lens from deciding from only two
  /// or three texels even when the full backdrop is large.
  final int minimumRegionSamples;

  const LiquidGlassAdaptiveSampling({
    this.pixelRatio = 0.05,
    this.frameLimit = 8,
    this.minimumRegionSamples = 8,
  })  : assert(pixelRatio > 0 && pixelRatio <= 1),
        assert(frameLimit >= 0),
        assert(minimumRegionSamples > 0);
}

/// Raises the base capture ratio only when a visible client would otherwise
/// receive too few samples across its shortest dimension.
@internal
double liquidGlassAdaptiveCaptureRatio(
  LiquidGlassAdaptiveSampling sampling,
  Iterable<Rect> visibleRegions,
) {
  double shortest = double.infinity;
  for (final Rect region in visibleRegions) {
    if (region.isEmpty) continue;
    shortest = math.min(shortest, math.min(region.width, region.height));
  }
  if (!shortest.isFinite) return sampling.pixelRatio;
  final double required = sampling.minimumRegionSamples / shortest;
  return math.max(sampling.pixelRatio, required).clamp(0.0, 1.0);
}
