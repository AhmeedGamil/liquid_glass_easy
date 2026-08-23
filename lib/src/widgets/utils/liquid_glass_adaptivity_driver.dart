import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'liquid_glass_adaptivity.dart';

/// The single adaptivity verdict machine shared by every adaptive
/// widget (lens, scroll edge, nav bar, adaptive area).
///
/// It owns the whole state that used to be copy-pasted per widget:
/// verdict resolution in priority order (manual `permanentBrightness` →
/// followed link → sampled luminance with hysteresis → platform
/// brightness), first-verdict seeding, the animated palette flip, and
/// publishing to a [LiquidGlassAdaptivityLink] when one is attached.
///
/// The owning widget stays responsible for everything widget-shaped:
/// registering itself with a view's sampler (and forwarding samples via
/// [onLuminance]), calling [sync] every build, wrapping its adaptive
/// subtree in an `AnimatedBuilder` on [listenable], reading the frame's
/// colors through [glassColor]/[contentColor], and calling [dispose].
///
/// Behavior contract (pinned by test/adaptivity_behavior_test.dart):
///  • a first verdict resolved during [sync] (manual / platform /
///    re-enable — i.e. before anything wrong could paint) lands
///    instantly; a first verdict arriving asynchronously after frames
///    already painted (sampler, link) ANIMATES in, so the default
///    palette fades into the real one instead of snapping;
///  • before any verdict the palettes sit on the guess —
///    `initialBrightness`, else the platform brightness — so a
///    confirming first verdict causes no motion at all;
///  • a verdict resolved before the flip controller exists seeds the
///    controller on creation, so the first real flip still animates;
///  • disabling adaptivity resets all state, so a re-enable starts
///    fresh (instant first verdict, no stale animation);
///  • a disabled `LiquidGlassAdaptivityController` HOLDS: sampled and
///    linked verdicts are ignored (the palette freezes where it is),
///    while a manual `permanentBrightness` still applies; on resume
///    the next verdict animates in — even one resolved inside the
///    resync's build — and [onResync] asks the owner to rebuild so
///    sampling registration follows the switch;
///  • `adaptOnce()` on a disabled controller arms a ONE-SHOT: the
///    widget re-registers, exactly one delivered verdict (sample or
///    link — a dead-zone sample counts too) animates in and consumes
///    the request, then the hold resumes; a publisher whose one-shot
///    verdict came out unchanged re-delivers the link value so held
///    followers complete the same request; enable() voids a pending
///    one-shot, and a fresh driver never reads controller history as
///    a request;
///  • a driver-role link is published post-frame when mid-build, so
///    sibling followers are never notified during a build.
@internal
class LiquidGlassAdaptivityDriver {
  LiquidGlassAdaptivityDriver({required TickerProvider vsync}) : _vsync = vsync;

  final TickerProvider _vsync;

  // Hysteresis runs only on sampled background lightness: flip to "dark"
  // below darkBelow, back to "light" above lightAbove, and hold inside the
  // band. The signal is also smoothed and requires two confirming frames.

  /// Drives the palette flip: 0 = light-backdrop palette, 1 = dark.
  AnimationController? _ctrl;
  Brightness? _verdict;

  /// Drives the CONTINUOUS glass tint when
  /// `LiquidGlassAdaptivity.continuousGlassColor` is on: same 0..1
  /// meaning as [_ctrl], but tracking background lightness smoothly
  /// instead of snapping between the two palettes. Content colors never
  /// use it — they stay binary so text never lands on a half-tone.
  AnimationController? _glassCtrl;
  bool _glassSeeded = false;
  double? _glassTargetT;

  /// Jitter below this is not worth an animation: the sampler's mean
  /// wobbles slightly even over a still background.
  static const double _kGlassDelta = 0.03;

  // Perceptual background lightness is filtered before the Schmitt trigger.
  // A real verdict switch also needs two consecutive outside-band samples;
  // first verdicts and explicit adaptOnce() requests still resolve at once.
  static const double _currentSampleWeight = 0.65;
  static const int _samplesBeforeSwitch = 2;
  double? _smoothedLightness;
  Brightness? _pendingSampleVerdict;
  int _pendingSampleCount = 0;

  /// The first verdict lands instantly (no flash on mount); later flips
  /// animate over the adaptivity's duration.
  bool _seeded = false;

  /// The link this driver follows (a consumer given a link, or a widget
  /// inside a `LiquidGlassAdaptiveArea`). Null when not following.
  LiquidGlassAdaptivityLink? _followedLink;

  /// The adaptivity's pause/resume switch, subscribed like the link.
  LiquidGlassAdaptivityController? _controller;

  /// Set by the owning widget: called when the controller flips so the
  /// owner rebuilds (re-running registration and [sync]).
  VoidCallback? onResync;

  /// True from a disabled→enabled flip until the next verdict lands.
  /// The held palette has been on screen, so that verdict must animate
  /// even when it resolves inside the resync's [sync].
  bool _resumed = false;

  /// One-shot bookkeeping (see `LiquidGlassAdaptivityController.
  /// adaptOnce`): the request generation this driver last served, and
  /// whether it still owes the current request one delivered verdict.
  int _seenGeneration = 0;
  bool _oneShotPending = false;

  /// Adaptivity from the last [sync] — the link/sampler callbacks read
  /// it so they always see the current palettes and duration.
  LiquidGlassAdaptivity? _adaptivity;

  /// The link this driver publishes verdicts/luminance to (the
  /// `LiquidGlassAdaptiveArea` role). Null on consumers.
  LiquidGlassAdaptivityLink? _publishLink;

  /// True while [sync] runs. A first verdict resolved inside sync (i.e.
  /// during build, before anything wrong painted) seeds instantly; one
  /// arriving asynchronously (sampler / link callbacks, after frames
  /// already showed the default palette) animates in instead.
  bool _inSync = false;

  bool _disposed = false;

  /// The current verdict, if any (`Brightness.dark` = dark backdrop).
  Brightness? get verdict => _verdict;

  /// Animation position of the binary palette flip (0 = light, 1 =
  /// dark).
  double get flipT => _ctrl?.value ?? 0.0;

  /// What the owning widget's `AnimatedBuilder` listens to. Non-null
  /// once [sync] ran with a non-null adaptivity.
  Listenable? get listenable => _glassCtrl == null
      ? _ctrl
      : Listenable.merge(<Listenable?>[_ctrl, _glassCtrl]);

  /// The continuous tint position, or the binary flip when the glide is
  /// off or has no sample yet.
  double get _glassT =>
      _glassSeeded && _glassCtrl != null ? _glassCtrl!.value : flipT;

  /// Whether the owning widget should register with a view's sampler
  /// this build — the ONE home for the decision every consumer (lens,
  /// scroll edge, adaptive content, area, animated bar) used to compute
  /// inline: adaptivity present, no manual override, not [following] a
  /// link, a sampling source reachable ([canRegister]), and adaptation
  /// live (an enabled controller, or none).
  bool samplingWanted(
    LiquidGlassAdaptivity? adaptivity, {
    required bool following,
    required bool canRegister,
  }) {
    if (adaptivity == null || adaptivity.permanentBrightness != null) {
      return false;
    }
    if (following || !canRegister) return false;
    // A pending one-shot keeps the widget registered while held, until
    // its single sample is delivered — this is what lets the sampler's
    // busy-skip and idle-gate retries converge instead of firing once.
    return (adaptivity.controller?.enabled ?? true) || _oneShotPending;
  }

  /// Keeps the link subscription and the verdict source in sync with
  /// the widget's configuration. Call on every build — it is a no-op
  /// unless something actually changed.
  ///
  /// [follow] is the link this driver mirrors (a consumer's role): its
  /// verdict wins over sampling. [publish] is the link this driver
  /// broadcasts to (the `LiquidGlassAdaptiveArea` role). [canSample] is
  /// whether the widget has a working sampling source (it registered
  /// with a view's sampler); with none, and no manual or linked
  /// verdict, [platformBrightness] is the last resort.
  void sync(
    LiquidGlassAdaptivity? adaptivity, {
    required bool canSample,
    required Brightness platformBrightness,
    LiquidGlassAdaptivityLink? follow,
    LiquidGlassAdaptivityLink? publish,
  }) {
    _inSync = true;
    try {
      _sync(adaptivity,
          canSample: canSample,
          platformBrightness: platformBrightness,
          follow: follow,
          publish: publish);
    } finally {
      _inSync = false;
    }
  }

  void _sync(
    LiquidGlassAdaptivity? adaptivity, {
    required bool canSample,
    required Brightness platformBrightness,
    LiquidGlassAdaptivityLink? follow,
    LiquidGlassAdaptivityLink? publish,
  }) {
    _adaptivity = adaptivity;
    _publishLink = adaptivity == null ? null : publish;

    // Keep the pause/resume subscription in step with the config.
    final LiquidGlassAdaptivityController? controller = adaptivity?.controller;
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onControllerChanged);
      _controller = controller;
      _controller?.addListener(_onControllerChanged);
      // A swap voids any old debt, and the new controller's history is
      // not a request — only generations bumped from here on count.
      _seenGeneration = controller?.refreshGeneration ?? 0;
      _oneShotPending = false;
    }

    // Follower mode: mirror the link instead of resolving a verdict.
    // (A manual verdict still wins over the link.)
    final bool follower = adaptivity != null &&
        adaptivity.permanentBrightness == null &&
        follow != null;
    final bool wantSampling = adaptivity != null &&
        adaptivity.permanentBrightness == null &&
        !follower &&
        canSample;

    final LiquidGlassAdaptivityLink? linkToFollow = follower ? follow : null;
    if (!identical(linkToFollow, _followedLink)) {
      _followedLink?.removeListener(_onLinkChanged);
      _followedLink?.lightness.removeListener(_onLinkLightness);
      _followedLink = linkToFollow;
      _followedLink?.addListener(_onLinkChanged);
      _followedLink?.lightness.addListener(_onLinkLightness);
    }

    if (adaptivity == null) {
      // Feature turned off: forget the verdict so a later re-enable
      // starts fresh (instant first verdict, no stale animation).
      _verdict = null;
      _seeded = false;
      _resumed = false;
      _oneShotPending = false;
      _resetSampleFilter();
      return;
    }

    if (!wantSampling && !_oneShotPending) _resetSampleFilter();

    // Manual override wins, then the followed link; platform brightness
    // is the last resort when sampling is impossible. A disabled
    // controller HOLDS: only the manual override may move the verdict.
    final bool enabled = controller?.enabled ?? true;
    if (adaptivity.permanentBrightness != null) {
      _oneShotPending = false; // manual override: nothing to look at
      _setVerdict(adaptivity.permanentBrightness!, adaptivity);
    } else if (!enabled) {
      // Held — keep the current verdict (or the pre-verdict guess). A
      // pending one-shot resolves through the sampler or link delivery;
      // with neither reachable the platform brightness IS the one look.
      if (_oneShotPending && !follower && !canSample) {
        _oneShotPending = false;
        _setVerdict(platformBrightness, adaptivity);
      }
    } else if (follower) {
      final Brightness? linked = linkToFollow!.value;
      if (linked != null) _setVerdict(linked, adaptivity);
    } else if (!wantSampling) {
      _setVerdict(platformBrightness, adaptivity);
    }

    // Pre-verdict palette: the developer's guess, else the platform
    // brightness (dark-mode users get the dark palette from the very
    // first frame). A confirming first verdict then causes no motion at
    // all; a differing one animates in.
    final Brightness guess = adaptivity.initialBrightness ?? platformBrightness;
    final double guessT = guess == Brightness.dark ? 1.0 : 0.0;
    if (_ctrl == null) {
      _ctrl = AnimationController(
        vsync: _vsync,
        duration: adaptivity.duration,
        value: _verdict == Brightness.dark
            ? 1.0
            : (_verdict != null ? 0.0 : guessT),
      );
      // A verdict resolved before the controller existed (manual /
      // platform verdicts land during the first build) is the seed the
      // controller just started on — mark it so the first real flip
      // animates instead of jumping.
      _seeded = _verdict != null;
    }
    // The glide controller exists only while the feature is on; it
    // starts wherever the flip is, so switching the flag mid-life does
    // not jump the tint.
    if (adaptivity.continuousGlassColor && _glassCtrl == null) {
      _glassCtrl = AnimationController(
        vsync: _vsync,
        duration: adaptivity.duration,
        value: _ctrl?.value ?? guessT,
      );
    } else if (!adaptivity.continuousGlassColor && _glassCtrl != null) {
      _glassCtrl!.dispose();
      _glassCtrl = null;
      _glassSeeded = false;
      _glassTargetT = null;
    } else if (!_seeded && _verdict == null && !_ctrl!.isAnimating) {
      // Still guessing (e.g. adaptivity re-enabled before any verdict):
      // keep the controller on the current guess.
      if (_ctrl!.value != guessT) _ctrl!.value = guessT;
    }
  }

  /// Classifies the background from its mean perceptual CIE L* lightness.
  /// Glass/content colors do not participate in this decision.
  void onBackdropSample(LiquidGlassBackdropSample sample) {
    if (_disposed) return;
    final LiquidGlassAdaptivity? adaptivity = _adaptivity;
    if (adaptivity == null || adaptivity.permanentBrightness != null) return;
    final bool enabled = adaptivity.controller?.enabled ?? true;
    if (!enabled && !_oneShotPending) return;

    final double rawLightness = sample.meanLightness;
    final double lightness;
    if (_smoothedLightness == null || _oneShotPending || _verdict == null) {
      lightness = rawLightness;
    } else {
      lightness = _smoothedLightness! +
          (rawLightness - _smoothedLightness!) * _currentSampleWeight;
    }
    _smoothedLightness = lightness;
    // The glide reads the SMOOTHED signal, same as the verdict, so the
    // tint and the flip can never disagree about the background.
    _setGlassLightness(lightness, adaptivity);
    final Brightness? publishedBefore = _publishLink?.value;
    _applyBackgroundLightness(
      lightness,
      adaptivity,
      requirePersistence: !_oneShotPending,
    );
    _finishOneShotIfNeeded(enabled, publishedBefore);
  }

  /// Legacy scalar entry point retained for direct/internal callers. New
  /// sampler clients use [onBackdropSample], which preserves the luminance
  /// distribution and supplies perceptual background lightness.
  void onLuminance(double luminance, {double? lightFraction}) {
    if (_disposed) return;
    final LiquidGlassAdaptivity? adaptivity = _adaptivity;
    if (adaptivity == null || adaptivity.permanentBrightness != null) return;
    final bool enabled = adaptivity.controller?.enabled ?? true;
    if (!enabled && !_oneShotPending) return;
    final Brightness? publishedBefore = _publishLink?.value;
    _applyBackgroundLightness(lightFraction ?? luminance, adaptivity,
        requirePersistence: false);
    _finishOneShotIfNeeded(enabled, publishedBefore);
  }

  void _applyBackgroundLightness(
    double lightness,
    LiquidGlassAdaptivity adaptivity, {
    required bool requirePersistence,
  }) {
    Brightness? verdict;
    if (lightness < adaptivity.darkBelow) {
      verdict = Brightness.dark;
    } else if (lightness > adaptivity.lightAbove) {
      verdict = Brightness.light;
    } else if (_verdict == null) {
      verdict = lightness < (adaptivity.darkBelow + adaptivity.lightAbove) / 2
          ? Brightness.dark
          : Brightness.light;
    }

    if (verdict == null || verdict == _verdict) {
      _pendingSampleVerdict = null;
      _pendingSampleCount = 0;
      if (verdict != null) _setVerdict(verdict, adaptivity);
      return;
    }
    if (!requirePersistence || _verdict == null) {
      _pendingSampleVerdict = null;
      _pendingSampleCount = 0;
      _setVerdict(verdict, adaptivity);
      return;
    }

    if (_pendingSampleVerdict == verdict) {
      _pendingSampleCount++;
    } else {
      _pendingSampleVerdict = verdict;
      _pendingSampleCount = 1;
    }
    if (_pendingSampleCount >= _samplesBeforeSwitch) {
      _pendingSampleVerdict = null;
      _pendingSampleCount = 0;
      _setVerdict(verdict, adaptivity);
    }
  }

  void _finishOneShotIfNeeded(bool enabled, Brightness? publishedBefore) {
    if (!enabled && _oneShotPending) {
      _completeOneShot(linkNotified: _publishLink?.value != publishedBefore);
    }
  }

  void _resetSampleFilter() {
    _smoothedLightness = null;
    _pendingSampleVerdict = null;
    _pendingSampleCount = 0;
    // The glide re-seeds on the next sample, so a re-enable lands on
    // the real tint instead of animating up from a stale one.
    _glassSeeded = false;
    _glassTargetT = null;
  }

  /// Glides the continuous tint toward [lightness], and publishes it for
  /// followers when this driver is the publisher.
  ///
  /// The first value lands instantly (nothing correct was on screen to
  /// animate from); later ones animate, and jitter under [_kGlassDelta]
  /// is dropped so a still background never schedules a frame.
  void _setGlassLightness(double lightness, LiquidGlassAdaptivity adaptivity) {
    _publishLink?.lightness.value = lightness;
    if (!adaptivity.continuousGlassColor) return;
    final AnimationController? ctrl = _glassCtrl;
    if (ctrl == null) return;
    // Lightness runs light→dark, the tint runs dark→light, hence the
    // inversion: the floor is the fully dark palette.
    const double floor = LiquidGlassAdaptivity.kContinuousFloor;
    const double ceiling = LiquidGlassAdaptivity.kContinuousCeiling;
    final double t =
        1.0 - ((lightness - floor) / (ceiling - floor)).clamp(0.0, 1.0);
    if (!_glassSeeded) {
      _glassSeeded = true;
      _glassTargetT = t;
      ctrl.value = t;
      return;
    }
    if ((t - (_glassTargetT ?? ctrl.value)).abs() < _kGlassDelta) return;
    _glassTargetT = t;
    ctrl.animateTo(t, duration: adaptivity.duration, curve: Curves.easeOut);
  }

  /// Ends a one-shot look: back to holding, and the owner rebuilds so
  /// sampling registration drops again. When the verdict came out
  /// UNCHANGED nothing was broadcast, so a publisher re-delivers the
  /// link value — held followers waiting on the same request complete
  /// theirs. (Sample delivery is async, never mid-build, so notifying
  /// the link directly is safe here.)
  void _completeOneShot({required bool linkNotified}) {
    _oneShotPending = false;
    final LiquidGlassAdaptivityLink? publish = _publishLink;
    if (publish != null && !linkNotified) {
      if (_verdict != null && publish.value != _verdict) {
        publish.value = _verdict; // e.g. a link attached after the verdict
      } else {
        publish.republish();
      }
    }
    onResync?.call();
  }

  /// Resolves this frame's glass tint from [adaptivity]'s palettes at
  /// the binary flip position.
  Color glassColor(LiquidGlassAdaptivity adaptivity) => Color.lerp(
      adaptivity.glassColorOnLight,
      adaptivity.glassColorOnDark,
      adaptivity.continuousGlassColor ? _glassT : flipT)!;

  /// Resolves this frame's content (icons/text) color — always the
  /// binary flip.
  Color contentColor(LiquidGlassAdaptivity adaptivity) => Color.lerp(
      adaptivity.contentColorOnLight, adaptivity.contentColorOnDark, flipT)!;

  void dispose() {
    _disposed = true;
    _followedLink?.removeListener(_onLinkChanged);
    _followedLink?.lightness.removeListener(_onLinkLightness);
    _followedLink = null;
    _controller?.removeListener(_onControllerChanged);
    _controller = null;
    _ctrl?.dispose();
    _glassCtrl?.dispose();
  }

  void _onControllerChanged() {
    if (_disposed) return;
    _resetSampleFilter();
    final LiquidGlassAdaptivityController? ctrl = _controller;
    if (ctrl != null && ctrl.refreshGeneration != _seenGeneration) {
      // adaptOnce() while held: owe the request exactly one delivered
      // verdict. The held palette has been on screen, so that verdict
      // must animate in (the _resumed path).
      _seenGeneration = ctrl.refreshGeneration;
      if (!ctrl.enabled) {
        _oneShotPending = true;
        _resumed = true;
      }
    }
    if (ctrl?.enabled ?? false) {
      // Resuming: the held palette has been on screen for a while, so
      // the catch-up verdict must animate even though it resolves
      // inside the resync's build. Continuous adaptation supersedes any
      // pending one-shot.
      _resumed = true;
      _oneShotPending = false;
    }
    onResync?.call();
  }

  /// A followed publisher sampled: glide to the same lightness so the
  /// group's tints move together, not just their verdicts.
  void _onLinkLightness() {
    if (_disposed) return;
    final LiquidGlassAdaptivity? adaptivity = _adaptivity;
    final double? lightness = _followedLink?.lightness.value;
    if (adaptivity == null || lightness == null) return;
    if (!adaptivity.continuousGlassColor) return;
    final bool enabled = adaptivity.controller?.enabled ?? true;
    if (!enabled && !_oneShotPending) return;
    _setGlassLightness(lightness, adaptivity);
  }

  void _onLinkChanged() {
    if (_disposed) return;
    final LiquidGlassAdaptivity? adaptivity = _adaptivity;
    final LiquidGlassAdaptivityLink? link = _followedLink;
    if (adaptivity == null || link == null) return;
    final bool enabled = adaptivity.controller?.enabled ?? true;
    // Held — unless a pending adaptOnce() look is waiting for the
    // group's next delivery (a change, or a publisher's re-delivery of
    // an unchanged verdict).
    if (!enabled && !_oneShotPending) return;
    final Brightness? verdict = link.value;
    if (verdict != null) _setVerdict(verdict, adaptivity);
    // Any delivery answers the one look: the follower's verdict is
    // whatever the group decided.
    if (!enabled && verdict != null) _oneShotPending = false;
  }

  void _setVerdict(Brightness verdict, LiquidGlassAdaptivity adaptivity) {
    if (_verdict == verdict) return;
    _verdict = verdict;
    final double target = verdict == Brightness.dark ? 1.0 : 0.0;
    // Publisher role: broadcast so followers flip on the same tick
    // (deferred to post-frame if mid-build — followers may be siblings).
    final LiquidGlassAdaptivityLink? publish = _publishLink;
    if (publish != null && publish.value != verdict) {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        publish.value = verdict;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) publish.value = verdict;
        });
      }
    }
    final AnimationController? ctrl = _ctrl;
    if (ctrl == null) return;
    if (!_seeded) {
      _seeded = true;
      if (_inSync && !_resumed) {
        // Resolved during build — nothing wrong ever painted, land
        // instantly (no flash on mount).
        ctrl.value = target;
      } else {
        // Arrived asynchronously (sampler / link) after frames already
        // showed the default palette — or resolved in the resync right
        // after a controller resume, with the held guess on screen —
        // animate into the real one instead of snapping.
        ctrl.animateTo(target,
            duration: adaptivity.duration, curve: Curves.easeInOut);
      }
      _resumed = false;
    } else {
      ctrl.animateTo(target,
          duration: adaptivity.duration, curve: Curves.easeInOut);
    }
  }
}
