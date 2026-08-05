import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass_style.dart';
import '../../liquid_glass_view.dart';
import 'liquid_glass_toggle_layout.dart';
import 'liquid_glass_toggle_motion.dart';
import 'liquid_glass_toggle_thumb.dart';
import 'liquid_glass_toggle_track.dart';

export 'liquid_glass_toggle_layout.dart';
export 'liquid_glass_toggle_motion.dart';
export 'liquid_glass_toggle_thumb.dart';
export 'liquid_glass_toggle_track.dart';

/// A drop-in liquid-glass toggle switch.
///
/// This is the **developer-facing** component: it owns its own
/// [LiquidGlassView], the colored track ([LiquidGlassToggleTrack]), the
/// moving glass handle ([buildLiquidGlassToggleThumb]) and the whole
/// press/drag simulation ([LiquidGlassToggleMotion]) — so you just give
/// it a [value] and an [onChanged] like a regular `Switch`.
///
/// At rest it shows a solid white pill in a tinted capsule. Press it and
/// the pill swells and turns to glass; you can either let go for a tap
/// toggle or **drag the handle across** and it will settle to whichever
/// end it was closest to. Throughout, the handle trails your finger
/// through a spring, squashes and stretches with its own momentum, and
/// the track recolors continuously as it travels.
///
/// ```dart
/// LiquidGlassToggle(
///   value: _on,
///   onChanged: (v) => setState(() => _on = v),
///   activeColor: const Color(0xFF34C759),
/// )
/// ```
///
/// ## Refraction & the overhang
/// The swollen handle grows larger than the track, so its overhang
/// samples the (transparent) area around the capsule. The shader honors
/// the captured texel's alpha (always on), so that overhang renders as
/// transparent passthrough instead of a black blob. On the Impeller
/// backdrop path the overhang refracts the live backdrop directly.
///
/// ## Sizing
/// The switch measures exactly [LiquidGlassToggleLayout.width] ×
/// `height` and lets the swollen handle paint outside it, so it takes no
/// more room in a row than its track. See [reserveSwellRoom] if an
/// ancestor clips.
class LiquidGlassToggle extends StatefulWidget {
  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when the user toggles the switch.
  final ValueChanged<bool> onChanged;

  /// Track tint when the switch is **on**.
  final Color activeColor;

  /// Track color when the switch is **off**.
  final Color inactiveColor;

  /// Size + handle geometry of the switch. Defaults to a 64×28 capsule.
  final LiquidGlassToggleLayout layout;

  /// Glass look of the moving handle (shape + appearance + refraction),
  /// the same [LiquidGlassStyle] vocabulary used across the library. When
  /// null, the tuned default capsule glass is used. A null
  /// [LiquidGlassStyle.shape] keeps the height-tracking capsule so the
  /// handle stays a clean pill as it swells.
  final LiquidGlassStyle? style;

  /// Whether to claim layout space for the handle's swell.
  ///
  /// By default the switch measures just its track and the swollen
  /// handle paints **outside** it. The trade-off is that a clipping
  /// ancestor (a `ClipRRect`, a `Card`, a scroll view with
  /// `clipBehavior` on) cuts the swell off at the track's edge. Set this
  /// to `true` in that case: the switch then measures large enough to
  /// contain the swell, at roughly 1.7× the width and 1.9× the height.
  final bool reserveSwellRoom;

  /// Capture resolution for the inner view. `1.0` is a good default; use
  /// less for cheaper captures, `0.0` for the device pixel ratio.
  final double pixelRatio;

  const LiquidGlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = const Color(0xFF34C759),
    this.inactiveColor = const Color(0x66808080),
    this.layout = const LiquidGlassToggleLayout(),
    this.style,
    this.reserveSwellRoom = false,
    this.pixelRatio = 1.0,
  });

  @override
  State<LiquidGlassToggle> createState() => _LiquidGlassToggleState();
}

class _LiquidGlassToggleState extends State<LiquidGlassToggle>
    with SingleTickerProviderStateMixin {
  final LiquidGlassViewController _viewController = LiquidGlassViewController();
  late final LiquidGlassToggleMotion _motion;

  /// Raw drag fraction, `0`..`1`. The motion's value springs toward
  /// this; on release we snap it to whichever end it is nearer.
  late double _fraction;

  /// Whether the finger actually moved the handle this gesture. A
  /// gesture that never moved is a tap, which flips the switch instead
  /// of settling where it was left.
  bool _didDrag = false;

  @override
  void initState() {
    super.initState();
    _fraction = widget.value ? 1.0 : 0.0;
    _motion = LiquidGlassToggleMotion(
      vsync: this,
      initialValue: _fraction,
      pressedScale: widget.layout.pressedScale,
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    // Keep the capture pipeline warm from startup rather than spinning
    // it up on the first touch, which showed as a first-tap stall.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewController.startRealtimeCapture();
    });
  }

  @override
  void didUpdateWidget(LiquidGlassToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A value change from outside runs the full press/travel/relax
    // cycle. When the change came from our own gesture, `_fraction` is
    // already there and this is a no-op.
    final target = widget.value ? 1.0 : 0.0;
    if (target != _fraction) {
      _fraction = target;
      _motion.animateToValue(target);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  /// Tapping the track (anywhere off the handle) moves to [next].
  void _handleTap(bool next) {
    if (next == widget.value) return;
    _fraction = next ? 1.0 : 0.0;
    _viewController.startRealtimeCapture();
    _motion.animateToValue(_fraction);
    widget.onChanged(next);
  }

  void _handleDragDown() {
    _didDrag = false;
    _viewController.startRealtimeCapture();
    _motion.press();
  }

  void _handleDragUpdate(double dx) {
    final travel = widget.layout.travel;
    if (travel <= 0) return;
    if (dx != 0) _didDrag = true;
    _fraction = (_fraction + dx / travel).clamp(0.0, 1.0);
    _motion.updateValue(_fraction);
  }

  void _handleDragEnd() {
    // Dragged: settle to the end the handle was heading for. Never
    // moved: it was a tap on the handle, so flip.
    _fraction = _didDrag
        ? (_motion.targetValue >= 0.5 ? 1.0 : 0.0)
        : (widget.value ? 0.0 : 1.0);
    _didDrag = false;
    _motion.updateValue(_fraction);
    _motion.release();

    final next = _fraction >= 0.5;
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;

    // Room around the track for the swollen handle, so it is never
    // clipped by the inner view bounds. The swell is sprung and picks up
    // extra size from momentum, so budget headroom past `pressedScale`
    // for both.
    const springOvershoot = 1.12;
    const momentumStretch = 1.25;
    final maxScale = layout.pressedScale * springOvershoot * momentumStretch;
    final maxPillW = layout.thumbWidth * maxScale;
    final maxPillH = layout.thumbHeight * maxScale;
    final travel = layout.travel;
    final rightExtent =
        layout.padding + travel + layout.thumbWidth / 2 + maxPillW / 2;
    final leftExtent = layout.padding + layout.thumbWidth / 2 - maxPillW / 2;
    final padX = math.max(
          math.max(0.0, rightExtent - layout.width),
          math.max(0.0, -leftExtent),
        ) +
        2.0;
    final padY = math.max(0.0, maxPillH / 2 - layout.height / 2) + 2.0;

    final viewWidth = layout.width + padX * 2;
    final viewHeight = layout.height + padY * 2;

    final pressProgress = _motion.pressProgress.clamp(0.0, 1.0);
    // Snap the lens rect to the device pixel grid. ImageFilter.blur
    // aligns its downsample to the filter's bounds, so a rect drifting
    // by fractions of a pixel — which the springs do every frame —
    // re-phases that grid and the blurred backdrop visibly shifts
    // underneath. The shader refracts that shift straight into the pill.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // One source of truth for the handle footprint: the lens is built at
    // this size and the track cuts its hole to match.
    final pillSize = liquidGlassToggleThumbSize(
      layout: layout,
      scaleX: _motion.scaleX,
      scaleY: _motion.scaleY,
      devicePixelRatio: dpr,
    );
    // The lens view has to be big enough to hold the swollen handle, but
    // that room doesn't have to be claimed from the parent: by default
    // the switch measures just its track and lets the view paint outside
    // it, so it occupies no more space in a row than the track does.
    Widget sized(Widget view) {
      final box = SizedBox(width: viewWidth, height: viewHeight, child: view);
      if (widget.reserveSwellRoom) return box;
      return SizedBox(
        width: layout.width,
        height: layout.height,
        child: OverflowBox(
          minWidth: viewWidth,
          maxWidth: viewWidth,
          minHeight: viewHeight,
          maxHeight: viewHeight,
          child: box,
        ),
      );
    }

    return sized(
      LiquidGlassView.withPositionedLenses(
        controller: _viewController,
        // The track is captured with authored transparency; honor it on
        // Skia so the glass handle shows the real screen through the track.
        honorBackdropAlpha: true,
        pixelRatio: widget.pixelRatio,
        realTimeCapture: true,
        useSync: false,
        backgroundWidget: Stack(
          children: [
            Positioned(
              left: padX,
              top: padY,
              child: LiquidGlassToggleTrack(
                value: widget.value,
                onChanged: _handleTap,
                tint: widget.activeColor,
                offColor: widget.inactiveColor,
                layout: layout,
                // The white rest handle is rendered INSIDE the glass
                // lens (as its child) so it sits ON TOP of the glass
                // pill — never here in the background, which lenses
                // always cover.
                showRestThumb: false,
                // The hole opens with the press, follows the handle, and
                // is cut to the size the lens actually rendered.
                pinchFraction: pressProgress,
                travelFraction: _motion.value,
                pillWidth: pillSize.width,
                pillHeight: pillSize.height,
                // Recolor with the handle, not with `value`.
                fraction: _motion.value,
              ),
            ),
          ],
        ),
        children: [
          // The glass handle is ALWAYS mounted. At rest it is exactly
          // the size of the rest pill and sits UNDER the white one,
          // which is rendered as the lens's child — on top of the glass.
          // On touch-down the white pill fades and the glass (already
          // rendered all along) swells and travels, so nothing new is
          // created at first touch. The child also carries the handle's
          // gesture surface, since the lens sits above the track and
          // would otherwise block it.
          buildLiquidGlassToggleThumb(
            layout: layout,
            trackLeft: padX,
            trackBottom: padY,
            travelFraction: _motion.value,
            scaleX: _motion.scaleX,
            scaleY: _motion.scaleY,
            devicePixelRatio: dpr,
            style: widget.style,
            // Grabbing the handle must OWN the gesture: a drag on it
            // adjusts the switch and never scrolls an ancestor list. A
            // plain GestureDetector loses that contest — a parent
            // Scrollable wins the arena the moment the finger moves
            // vertically and the drag is cancelled mid-swell. So this
            // claims the pointer the instant it lands, beating any
            // ancestor. A pan (not horizontal-only) recognizer also
            // keeps the grab alive under vertical movement; the value
            // still tracks horizontal x only.
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _EagerPanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        _EagerPanGestureRecognizer>(
                  () => _EagerPanGestureRecognizer(debugOwner: this),
                  (instance) {
                    instance
                      // Fire onStart at touch-down (not after slop) so
                      // the handle swells the instant it is grabbed.
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = (_) {
                        _handleDragDown();
                      }
                      ..onUpdate = (d) {
                        _handleDragUpdate(d.delta.dx);
                      }
                      ..onEnd = (_) {
                        _handleDragEnd();
                      }
                      ..onCancel = _handleDragEnd;
                  },
                ),
              },
              // Solid handle, drawn over the glass. It dissolves as the
              // press takes hold, uncovering the glass beneath, and
              // stays hit-testable throughout.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 1 - pressProgress),
                  borderRadius: BorderRadius.circular(pillSize.height / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [PanGestureRecognizer] that wins the gesture arena the instant a
/// pointer lands on it, instead of waiting to accumulate drag slop.
///
/// This is what lets the toggle handle beat an ancestor [Scrollable]:
/// normally both join the arena and the scrollable wins as soon as the
/// finger moves vertically, stealing the drag. By resolving
/// [GestureDisposition.accepted] in [addAllowedPointer], the handle
/// claims the pointer immediately — so once you grab the pill, moving in
/// any direction keeps controlling the switch and the page never
/// scrolls.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
