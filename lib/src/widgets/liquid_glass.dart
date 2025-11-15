import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
import 'package:liquid_glass_easy/src/widgets/painters/liquid_glass_painter.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';


// Represents a single lens in the LiquidGlass system
class LiquidGlass {
  /// Controls the lens behavior programmatically, such as toggling visibility or
  /// updating properties dynamically at runtime.
  final LiquidGlassController? controller;

  /// The width of the lens in logical pixels.
  final double width;

  /// The height of the lens in logical pixels.
  final double height;

  /// Defines how much the lens magnifies (zooms in on) the distorted content.
  ///
  /// - `1.0` means no magnification.
  final double magnification;

  /// The bending strength of the distortion effect.
  ///
  /// Controls how much the refracted (bent) background is warped inside the
  /// distortion width area. Higher values increase compression within the
  /// distortion zone, creating a stronger bending effect. Lower values reduce
  /// compression and produce softer distortion.
  ///
  /// - **Range:** `0.0` (no distortion) to `1.0` (maximum distortion).
  final double distortion;


  /// The thickness of the distortion band around the lens perimeter.
  ///
  /// This defines how wide the bending/refraction zone is. Larger values create
  /// a thicker distortion border, affecting more of the background. Smaller values
  /// produce a thinner, tighter distortion edge.
  ///
  /// - **Unit:** logical pixels
  /// - **Typical range:** `0.0` (no distortion band) to around `50.0`+ depending
  ///   on the lens size and desired visual intensity.
  final double distortionWidth;

  /// Applies a diagonal mirroring or flip effect to the refraction direction.
  ///
  /// Used to create artistic or mirrored lens effects.
  final double diagonalFlip;

  /// Determines whether the lens can be dragged (moved) by the user.
  final bool draggable;

  /// Optional widget content displayed inside the lens area.
  ///
  /// Can be used to show overlays, icons, or custom visual elements.
  final Widget? child;

  /// The position of the lens on screen.
  ///
  /// Can be defined either as an absolute `Offset` or a relative `Alignment` value.
  final LiquidGlassPosition position;

  /// The geometric shape of the lens and its optional border.
  ///
  /// Common options include `superellipse`, `roundedRect`, etc.
  final LiquidGlassShape shape;

  /// The blur configuration for the lens background.
  ///
  /// Controls how the underlying content is blurred beneath the glass.
  final LiquidGlassBlur blur;

  /// Whether the inner, non-distorted region should be transparent.
  ///
  /// When enabled, the unaffected center area will reveal the background directly.
  final bool enableInnerRadiusTransparent;

  /// Whether the lens is currently visible or hidden in the view.
  final bool visibility;

  /// The base color tint of the lens.
  ///
  /// Can be semi-transparent to create colored glass effects.
  final Color color;

  /// Whether this lens is allowed to move outside the boundaries
  /// of its parent container.
  ///
  /// When set to `true`, the lens can partially or fully extend beyond
  /// the visible area of the parent, which can be useful for creative
  /// transitions or edge-based effects.
  ///
  /// When set to `false` (default), the lens position is automatically
  /// clamped to remain fully within the parent’s bounds.
  final bool outOfBoundaries;


  const LiquidGlass({
    this.controller,
    this.width = 200,
    this.height = 100,
    this.magnification = 1,
    this.distortion = 0.2,
    this.distortionWidth = 30,
    this.enableInnerRadiusTransparent = false,
    this.diagonalFlip = 0,
    this.draggable = false,
    this.child,
    required this.position,
    this.shape = const RoundedRectangleShape(),
    this.blur = const LiquidGlassBlur(),
    this.visibility = true,
    this.color = Colors.transparent,
    this.outOfBoundaries=false
  });
}

/// Lens widgets that uses the shared shader + image
class LiquidGlassWidget extends StatefulWidget {
  final Size parentSize;
  final LiquidGlass config;
  final ui.FragmentShader? sharedShader;
  final ui.FragmentShader? border;

  final ui.Image? sharedImage;

  const LiquidGlassWidget(
      {super.key,
      required this.parentSize,
      required this.config,
      this.sharedShader,
      this.sharedImage,
      this.border});

  @override
  State<LiquidGlassWidget> createState() => _LiquidGlassWidgetState();
}

class _LiquidGlassWidgetState extends State<LiquidGlassWidget>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<Offset> _touchNotifier;
  late AnimationController _animController;
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.config.visibility ? 0 : 1, // initial value
    );
    // only attach trigger if controller exists
    // Attach controller if provided
    widget.config.controller?.attach(
      showLiquidGlass: _showLiquidGlass,
      hideLiquidGlass: _hideLiquidGlass,
      resetLiquidGlassPosition: _resetLiquidGlassPosition
    ); // Resolve initial position
    final _initialPosition = widget.config.position.resolve(
      widget.parentSize,
      Size(widget.config.width, widget.config.height),
    );
    _touchNotifier = ValueNotifier<Offset>(_initialPosition);
  }

  void setPosition()
  {
    final _initialPosition = widget.config.position.resolve(
      widget.parentSize,
      Size(widget.config.width, widget.config.height),
    );
    _touchNotifier.value = _initialPosition;
  }



  void _hideLiquidGlass(
      {int? animationTimeMillisecond, VoidCallback? onComplete}) {
    final duration = Duration(milliseconds: animationTimeMillisecond ?? 600);

    if (duration.inMilliseconds == 0) {
      // Jump instantly
      _animController.value = 1.0;
      if (onComplete != null) onComplete();
    } else {
      _animController.value = 0.0;
      _animController
          .animateTo(
        1,
        duration: duration,
        curve: Curves.easeInOut,
      )
          .whenComplete(() {
        if (onComplete != null) onComplete();
      });
    }
  }

  void _showLiquidGlass(
      {int? animationTimeMillisecond, VoidCallback? onComplete}) {
    final duration = Duration(milliseconds: animationTimeMillisecond ?? 600);

    if (duration.inMilliseconds == 0) {
      // Jump instantly
      _animController.value = 0.0;
      if (onComplete != null) onComplete();
    } else {
      _animController.value = 1.0;
      _animController
          .animateTo(
        0,
        duration: duration,
        curve: Curves.easeInOut,
      )
          .whenComplete(() {
        if (onComplete != null) onComplete();
      });
    }
  }

  void _resetLiquidGlassPosition() {
    setPosition();
  }



  @override
  void didUpdateWidget(covariant LiquidGlassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If config changes and no animation is running → update instantly
    if (!_animController.isAnimating &&
        widget.config.visibility != oldWidget.config.visibility) {
      if (widget.config.visibility) {
        if (_animController.isAnimating) _animController.stop();
        _animController.value = 0;
      } else {
        if (_animController.isAnimating) _animController.stop();
        _animController.value = 1;
      }
    }


    // --- Handle parent size / layout changes
    final parentSize = widget.parentSize;
    final oldParentSize = oldWidget.parentSize;
    final config = widget.config;
    if (parentSize.width != oldParentSize.width ||
        parentSize.height != oldParentSize.height ||
        config.width != oldWidget.config.width ||
        config.height != oldWidget.config.height || config.position!=oldWidget.config.position
    ) {
        // Compute old and new resolved centers
        final oldResolvedPosition = oldWidget.config.position.resolve(
          oldParentSize,
          Size(oldWidget.config.width, oldWidget.config.height),
        );
        final resolvedPosition = config.position.resolve(
          parentSize,
          Size(config.width, config.height),
        );

        // Calculate proportional scaling factors
        // final scaleX = parentSize.width / oldParentSize.width;
        // final scaleY = parentSize.height / oldParentSize.height;

        // Maintain the same relative touch offset ratio inside the parent
        final Offset oldTouch = _touchNotifier.value;
        final Offset relative = Offset(
          (oldTouch.dx - oldResolvedPosition.dx) / oldParentSize.width,
          (oldTouch.dy - oldResolvedPosition.dy) / oldParentSize.height,
        );

        // Apply scaling and update position proportionally
        Offset newTouch = Offset(
          resolvedPosition.dx + relative.dx * parentSize.width,
          resolvedPosition.dy + relative.dy * parentSize.height,
        );

        // Clamp lens inside parent bounds
        final double maxX = parentSize.width - config.width;
        final double maxY = parentSize.height - config.height;

        newTouch = Offset(
          newTouch.dx.clamp(0.0, maxX),
          newTouch.dy.clamp(0.0, maxY),
        );

        _touchNotifier.value = newTouch;
      }

    if (!widget.config.outOfBoundaries) {
      // --- clamp comes here, completely outside the condition ---
      final double maxX = parentSize.width - config.width;
      final double maxY = parentSize.height - config.height;

      _touchNotifier.value = Offset(
        _touchNotifier.value.dx.clamp(0.0, maxX),
        _touchNotifier.value.dy.clamp(0.0, maxY),
      );
    }
  }

  @override
  void dispose() {
    widget.config.controller?.detach();
    _touchNotifier.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return (_animController.value < 1)
        ? Stack(
            children: [
              // Shader layer
              IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: widget.parentSize.width,
                  height: widget.parentSize.height,
                  child: CustomPaint(
                    painter: (widget.sharedShader != null &&
                            widget.sharedImage != null)
                        ? LiquidGlassPainter(
                            dragOffset: _touchNotifier.value,
                            position: widget.config.position,
                            lensWidth: widget.config.width,
                            lensHeight: widget.config.height,
                            magnification: widget.config.magnification,
                            distortion: widget.config.distortion,
                            distortionWidth: (widget.config.distortionWidth -
                                _animController.value *
                                    widget.config.distortionWidth),
                            diagonalFlip: widget.config.diagonalFlip,
                            enableInnerRadiusTransparent:
                                widget.config.enableInnerRadiusTransparent,
                            draggable: widget.config.draggable,
                            parentSize: widget.parentSize,
                            border: widget.config.shape,
                            borderAlpha: (1 - _animController.value),
                            blur: widget.config.blur,
                            color: widget.config.color,
                            shader: widget.sharedShader!,
                            image: widget.sharedImage!,
                            borderShader: widget.border)
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              // Draggable lens
              ValueListenableBuilder<Offset>(
                valueListenable: _touchNotifier,
                builder: (context, offset, child) {
                  return Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    width: widget.config.width,
                    height: widget.config.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque, // ensures full area receives gestures
                      onPanUpdate: widget.config.draggable
                          ? (details) {
                        _touchNotifier.value += details.delta;
                      }
                          : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          widget.config.shape is RoundedRectangleShape
                              ? (widget.config.shape as RoundedRectangleShape).cornerRadius
                              : 0,
                        ),
                        child: widget.config.child ??
                            Container(
                              color: Colors.transparent,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ],
          )
        : SizedBox.shrink();
  }
}
