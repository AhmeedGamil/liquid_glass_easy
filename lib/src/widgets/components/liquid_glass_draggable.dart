import 'package:flutter/material.dart';

/// Wraps [child] so a pan gesture drags it, with the same smoothness as the
/// built-in drag — and without baking drag into the lens itself.
///
/// The drag offset lives in an internal [ValueNotifier], and only a
/// [Transform.translate] rebuilds on each pan; [child] stays a stable subtree,
/// so a wrapped [LiquidGlassLens] (or any glass) re-runs its shader/capture
/// pipeline once, not every frame. The lens keeps sampling the backdrop
/// correctly at its dragged position because the renderer resolves its screen
/// rect through the full layer transform.
///
/// ```dart
/// LiquidGlassDraggable(
///   child: LiquidGlassLens(
///     style: const LiquidGlassStyle(
///       shape: LiquidGlassShape.squircle(cornerRadius: 44),
///     ),
///     child: const Center(child: Text('drag me')),
///   ),
/// )
/// ```
class LiquidGlassDraggable extends StatefulWidget {
  /// The widget to make draggable (e.g. a `LiquidGlassLens`).
  final Widget child;

  /// Whether dragging is active. When `false` the [child] is returned as-is
  /// (no gesture, no transform).
  final bool enabled;

  /// The starting offset from the child's layout position.
  final Offset initialOffset;

  /// Called with the new offset whenever the drag moves.
  final ValueChanged<Offset>? onChanged;

  const LiquidGlassDraggable({
    super.key,
    required this.child,
    this.enabled = true,
    this.initialOffset = Offset.zero,
    this.onChanged,
  });

  @override
  State<LiquidGlassDraggable> createState() => _LiquidGlassDraggableState();
}

class _LiquidGlassDraggableState extends State<LiquidGlassDraggable> {
  late final ValueNotifier<Offset> _offset =
      ValueNotifier<Offset>(widget.initialOffset);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    // Stable subtree: gesture + child are built once and reused as the
    // ValueListenableBuilder's `child`, so only the Transform rebuilds per pan.
    final Widget stable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) {
        _offset.value += d.delta;
        widget.onChanged?.call(_offset.value);
      },
      child: widget.child,
    );

    return ValueListenableBuilder<Offset>(
      valueListenable: _offset,
      builder: (context, off, child) =>
          Transform.translate(offset: off, child: child),
      child: stable,
    );
  }
}
