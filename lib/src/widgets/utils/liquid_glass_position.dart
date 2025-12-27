// Abstract class representing a general position of a LiquidGlass lens
import 'package:flutter/material.dart';

abstract class LiquidGlassPosition {
  const LiquidGlassPosition();

  // Resolves the actual Offset of the lens based on parent and lens sizes
  Offset resolve(Size parentSize, Size lensSize);
}

// Concrete position using a fixed Offset (x, y) in the parent widgets
class LiquidGlassOffsetPosition extends LiquidGlassPosition {
  /// The distance between the lens and the **left** edge of its parent container.
  ///
  final double? left;

  /// The distance between the lens and the **top** edge of its parent container.
  ///
  final double? top;

  /// The distance between the lens and the **right** edge of its parent container.
  ///
  final double? right;

  /// The distance between the lens and the **bottom** edge of its parent container.
  ///
  final double? bottom;

  const LiquidGlassOffsetPosition({
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  @override
  Offset resolve(Size parentSize, Size lensSize) {
    final double dx;
    final double dy;

    // X position: prefer left, otherwise compute from right
    if (left != null) {
      dx = left!;
    } else if (right != null) {
      dx = parentSize.width - lensSize.width - right!;
    } else {
      dx = 0.0;
    }

    // Y position: prefer top, otherwise compute from bottom
    if (top != null) {
      dy = top!;
    } else if (bottom != null) {
      dy = parentSize.height - lensSize.height - bottom!;
    } else {
      dy = 0.0;
    }

    return Offset(dx, dy);
  }
}

// Concrete position using Alignment (-1 to 1 on x/y) within parent
class LiquidGlassAlignPosition extends LiquidGlassPosition {
  /// Defines the alignment of the lens **within its parent widget**.
  ///
  /// Examples:
  /// - `Alignment.center` places the lens at the center.
  /// - `Alignment.topLeft` aligns it to the top-left corner.
  /// - `Alignment.bottomRight` aligns it to the bottom-right corner.
  final Alignment alignment;

  /// The outer margin (spacing) around the lens.
  ///
  /// This margin is applied outside the lens boundaries, creating space
  /// between the lens and surrounding UI elements.
  final EdgeInsets margin;

  const LiquidGlassAlignPosition({
    required this.alignment,
    this.margin = EdgeInsets.zero, // default no margin
  });

  @override
  Offset resolve(Size parentSize, Size lensSize) {
    // Available space after subtracting margins
    final double availableWidth =
        parentSize.width - lensSize.width - margin.left - margin.right;
    final double availableHeight =
        parentSize.height - lensSize.height - margin.top - margin.bottom;

    // Convert alignment (-1..1) to pixel Offset inside available area
    final double dx = margin.left + (alignment.x + 1) / 2 * availableWidth;
    final double dy = margin.top + (alignment.y + 1) / 2 * availableHeight;

    return Offset(dx, dy);
  }
}
