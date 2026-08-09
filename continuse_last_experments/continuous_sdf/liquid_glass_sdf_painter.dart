// ─────────────────────────────────────────────────────────────────────────
// EXPERIMENTAL — painter for the SDF-driven continuous-curvature glass.
//
// Binds the captured background ([content]) + a baked SDF ([baked]) into
// liquid_glass_sdf.frag, which runs the same refraction pipeline as the main
// liquid_glass.frag. Fully separate from LiquidGlassPainter — deleting
// `continuous_sdf/` and the shader asset removes it.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'continuous_corner_path.dart';
import 'liquid_glass_sdf_baker.dart';

class LiquidGlassSdfPainter extends CustomPainter {
  LiquidGlassSdfPainter({
    required this.shader,
    required this.content,
    required this.baked,
    required this.lensTopLeft,
    required this.lensSize,
    required this.cornerRadius,
    required this.magnification,
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.saturation,
    required this.chromaticAberration,
  });

  final ui.FragmentShader shader;
  final ui.Image content;
  final BakedSdf baked;
  final Offset lensTopLeft;
  final Size lensSize;
  final double cornerRadius;
  final double magnification;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final double saturation;
  final double chromaticAberration;

  @override
  void paint(Canvas canvas, Size size) {
    int i = 0;
    shader.setFloat(i++, size.width);
    shader.setFloat(i++, size.height);
    shader.setFloat(i++, lensTopLeft.dx);
    shader.setFloat(i++, lensTopLeft.dy);
    shader.setFloat(i++, lensSize.width);
    shader.setFloat(i++, lensSize.height);
    shader.setFloat(i++, baked.textureLogicalSize.width);
    shader.setFloat(i++, baked.textureLogicalSize.height);
    shader.setFloat(i++, baked.padding);
    shader.setFloat(i++, baked.maxDistance);
    shader.setFloat(i++, magnification);
    shader.setFloat(i++, distortion);
    shader.setFloat(i++, distortionWidth);
    shader.setFloat(i++, diagonalFlip);
    shader.setFloat(i++, saturation);
    shader.setFloat(i++, chromaticAberration);

    shader.setImageSampler(0, content);
    shader.setImageSampler(1, baked.image);

    // Clip to the squircle so the lens edge is crisp.
    final path = continuousRoundedRectanglePath(lensSize, cornerRadius)
        .shift(lensTopLeft);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiquidGlassSdfPainter old) {
    return old.shader != shader ||
        old.content != content ||
        old.baked != baked ||
        old.lensTopLeft != lensTopLeft ||
        old.lensSize != lensSize ||
        old.cornerRadius != cornerRadius ||
        old.magnification != magnification ||
        old.distortion != distortion ||
        old.distortionWidth != distortionWidth ||
        old.diagonalFlip != diagonalFlip ||
        old.saturation != saturation ||
        old.chromaticAberration != chromaticAberration;
  }
}
