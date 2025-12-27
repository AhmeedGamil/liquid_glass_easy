import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';

// Main container that renders LiquidGlass lenses on top of a background
class LiquidGlassView extends StatefulWidget {
  /// Controls the LiquidGlass rendering performance and synchronization pipeline.
  /// Manages how often background captures and shader updates occur to balance
  /// visual quality and frame rate performance.
  final LiquidGlassViewController? controller;

  /// The list of individual `LiquidGlass` lenses rendered in this view.
  /// Each lens defines its own shape, distortion, and behavior.
  final List<LiquidGlass> children;

  /// The device pixel ratio used when capturing and rendering the lens effects.
  /// Higher values enhance lens content quality and clarity but also significantly
  /// impact performance by increasing GPU memory usage and rendering cost.
  ///
  /// If the background widget covers the entire screen, this setting can cause a
  /// **high performance impact**. In such cases, it is recommended to keep the
  /// value **below 1.0** and rely on blur effects for smoother visuals instead of
  /// higher pixel density.
  ///
  /// A value of **0.0** uses the device’s default pixel ratio, while **1.0** is the
  /// maximum recommended value for maintaining a balance between visual quality
  /// and frame rate.
  final double pixelRatio;

  /// Enables or disables real-time background capture for the lenses.
  /// When `true`, the background beneath each lens is updated every frame,
  /// producing dynamic refraction.
  /// When `false`, a cached snapshot is reused for better efficiency.
  final bool realTimeCapture;

  /// Determines whether lens rendering is synchronized with Flutter’s frame callbacks.
  /// When `true`, updates are aligned with Flutter’s rendering pipeline, resulting in
  /// smoother animations and generally faster performance.
  ///
  /// When `false`, updates run asynchronously, which can provide higher throughput
  /// on powerful devices, but may introduce slight delays or
  /// less consistent frame timing.
  ///
  /// It is slower than synchronous mode, but it becomes very stable
  /// when the pixel ratio is low (e.g., around 0.5).
  final bool useSync;

  /// The widget tree drawn behind all LiquidGlass lenses.
  /// Typically a static or animated background (such as an `Image`, `Stack`, or
  /// complex layout) over which the lenses apply refraction and effects.
  final Widget backgroundWidget;

  /// Controls how frequently the background is re-captured while real-time updates are enabled.
  ///
  /// - [low] = ~10 FPS (energy saving)
  /// - [medium] = ~24 FPS (balanced)
  /// - [high] = ~60 FPS (smooth)
  /// - [deviceRefreshRate] = tries to match the display refresh rate
  final LiquidGlassRefreshRate refreshRate;

  const LiquidGlassView(
      {super.key,
      this.controller,
      required this.backgroundWidget,
      required this.children,
      this.pixelRatio = 1.0,
      this.realTimeCapture = true,
      this.useSync = true,
      this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate});

  @override
  State<LiquidGlassView> createState() => _LiquidGlassViewState();
}

class _LiquidGlassViewState extends State<LiquidGlassView>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _image;
  ui.FragmentProgram? _mainProgram;
  ui.FragmentProgram? _borderProgram;
  Map<String, dynamic> _shaders = {};
  late final AnimationController _controller;
  bool _realtimeCaptureEnabled = false;
  bool isWeb = kIsWeb;

  @override
  void initState() {
    super.initState();
    _realtimeCaptureEnabled = widget.realTimeCapture;

    DateTime lastCaptureTime = DateTime.now();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 2),
    )..addListener(() async {
        if (!_realtimeCaptureEnabled) return;
        final interval = _refreshInterval;
        // If deviceRefreshRate → capture every frame
        if (interval == null) {
          await _captureWidgetSafe();
          return;
        }
        // Otherwise throttle based on selected refresh rate
        final now = DateTime.now();
        if (now.difference(lastCaptureTime) >= interval) {
          lastCaptureTime = now;
          await _captureWidgetSafe();
        }
      });
    widget.controller?.attach(
      captureOnce: _captureOnce,
      startRealtime: _startRealtimeCapture,
      stopRealtime: _stopRealtimeCapture,
    );

    _loadShaders().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _captureWidgetSafe();
        setState(() {});
      });
      _controller.forward();
    });
  }

  Duration? get _refreshInterval {
    switch (widget.refreshRate) {
      case LiquidGlassRefreshRate.low:
        return const Duration(milliseconds: 100); // ~10 FPS
      case LiquidGlassRefreshRate.medium:
        return const Duration(milliseconds: 42); // ~24 FPS
      case LiquidGlassRefreshRate.high:
        return const Duration(milliseconds: 16); // ~60 FPS
      case LiquidGlassRefreshRate.deviceRefreshRate:
        return null; // no throttling → capture every frame
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If config changes and no animation is running → update instantly

    if (isWeb && widget.children.length != oldWidget.children.length) {
      _recreateWebShaders(widget.children.length);
    }
    if (widget.realTimeCapture != oldWidget.realTimeCapture) {
      _realtimeCaptureEnabled = widget.realTimeCapture;
    }
  }

  Size get captureSize {
    final renderBox =
        _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }

  // Future<void> _loadShaders() async {
  //   final liquidGlassProgram = await ui.FragmentProgram.fromAsset(
  //       'packages/liquid_glass_easy/lib/assets/shaders/liquid_glass.frag');
  //   final borderProgram = await ui.FragmentProgram.fromAsset(
  //       'packages/liquid_glass_easy/lib/assets/shaders/liquid_glass_border.frag');
  //
  //   _shaders = {
  //     'liquid_glass': liquidGlassProgram.fragmentShader(),
  //     'liquid_glass_border':borderProgram.fragmentShader(),
  //   };
  // }

  Future<void> _loadProgramsOnce() async {
    _mainProgram ??= await ui.FragmentProgram.fromAsset(
        'packages/liquid_glass_easy/lib/assets/shaders/liquid_glass.frag');
    _borderProgram ??= await ui.FragmentProgram.fromAsset(
        'packages/liquid_glass_easy/lib/assets/shaders/liquid_glass_border.frag');
  }

  List<ui.FragmentShader> _createShaderList(
    ui.FragmentProgram program,
    int count,
  ) {
    return List.generate(count, (_) => program.fragmentShader());
  }

  Future<void> _loadShaders() async {
    await _loadProgramsOnce();

    final main = _mainProgram!;
    final border = _borderProgram!;

    if (isWeb) {
      final count = widget.children.length;

      _shaders = {
        'liquid_glass_list': _createShaderList(main, count),
        'liquid_glass_border_list': _createShaderList(border, count),
      };
    } else {
      _shaders = {
        'liquid_glass': main.fragmentShader(),
        'liquid_glass_border': border.fragmentShader(),
      };
    }
  }

  Future<void> _recreateWebShaders(int newCount) async {
    if (!isWeb) return;

    final main = _mainProgram!;
    final border = _borderProgram!;

    setState(() {
      _shaders['liquid_glass_list'] = _createShaderList(main, newCount);
      _shaders['liquid_glass_border_list'] =
          _createShaderList(border, newCount);
    });
  }

  Future<void> _captureWidgetSafe() async {
    try {
      final context = _repaintKey.currentContext;
      if (context == null) return;

      final boundary = context.findRenderObject();
      if (boundary is RenderRepaintBoundary && boundary.attached) {
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) {
             double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
             double pixelRatio =
             widget.pixelRatio <= 0 ? devicePixelRatio : widget.pixelRatio;
             if (pixelRatio > devicePixelRatio) {
               pixelRatio = devicePixelRatio;
             }
             if (widget.useSync) {
               _image = boundary.toImageSync(
               pixelRatio: pixelRatio,
               );
             }
             else {
              _image = await boundary.toImage(
              pixelRatio: pixelRatio,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _captureOnce() async {
    await _captureWidgetSafe();
    if (mounted) setState(() {});
  }

  void _startRealtimeCapture() {
    setState(() {
      _realtimeCaptureEnabled = true;
    });
  }

  void _stopRealtimeCapture() {
    setState(() {
      _realtimeCaptureEnabled = false;
    });
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: widget.backgroundWidget,
        ),
        AnimatedBuilder(
            animation: _controller,
            builder: (context, s) {
              return Stack(children: [
                ...widget.children.asMap().entries.map((entry) {
                  if (_shaders.length > 1 && _image != null) {
                    final index = entry.key;
                    final child = entry.value;

                    return LiquidGlassWidget(
                      config: child,
                      parentSize: captureSize,
                      sharedShader: isWeb
                          ? (_shaders['liquid_glass_list']
                              as List<ui.FragmentShader>)[index]
                          : _shaders['liquid_glass'],
                      border: isWeb
                          ? (_shaders['liquid_glass_border_list']
                              as List<ui.FragmentShader>)[index]
                          : _shaders['liquid_glass_border'],
                      sharedImage: _image!,
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
              ]);
            })
      ],
    );
  }
}
