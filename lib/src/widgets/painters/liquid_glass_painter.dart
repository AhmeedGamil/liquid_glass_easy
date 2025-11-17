import 'dart:ui' as ui;
import 'package:flutter/material.dart';


import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_shape.dart';

class LiquidGlassPainter extends CustomPainter {
  final LiquidGlassPosition position;
  final Offset? dragOffset;
  final double lensWidth;
  final double lensHeight;
  final double magnification;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final bool enableInnerRadiusTransparent;
  final bool draggable;
  final Size parentSize;
  final LiquidGlassShape? border;
  final double borderAlpha;
  final LiquidGlassBlur blur;
  final Color color;
  final ui.FragmentShader shader;
  final ui.FragmentShader? borderShader;

  final ui.Image image;

  LiquidGlassPainter({
    required this.position,
    required this.dragOffset,
    required this.lensWidth,
    required this.lensHeight,
    required this.magnification,
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.enableInnerRadiusTransparent,
    required this.draggable,
    required this.parentSize,
    required this.border,
    required this.borderAlpha,
    required this.blur,
    required this.color,
    required this.shader,
    this.borderShader,
    required this.image,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool useBlur=blur.sigmaX>0 || blur.sigmaY>0;
    final lensPosition = dragOffset!;
    final bool highDistortionOnCurves=border is RoundedRectangleShape? (border as RoundedRectangleShape).highDistortionOnCurves:false;
    int index=0;
    // Pass shader parameters (uniforms) for the GLSL shader
    shader.setFloat(index++, size.width);
    shader.setFloat(index++, size.height);
    shader.setFloat(index++, lensPosition.dx);
    shader.setFloat(index++, lensPosition.dy);

    shader.setFloat(index++, lensWidth);
    shader.setFloat(index++, lensHeight);
    shader.setFloat(index++, border is RoundedRectangleShape? 0:1);
    shader.setFloat(index++, border is RoundedRectangleShape? (border as RoundedRectangleShape).cornerRadius:0);
    shader.setFloat(index++, border is SuperellipseShape? (border as SuperellipseShape).curveExponent:0);

    shader.setFloat(index++, magnification);
    shader.setFloat(index++, distortion);
    shader.setFloat(index++, distortionWidth);

    shader.setFloat(index++, enableInnerRadiusTransparent ? 1.0 : 0.0);
    shader.setFloat(index++, diagonalFlip);

    shader.setFloat(index++,useBlur?0: border!.borderWidth);
    shader.setFloat(index++, border!.borderSoftness);

    shader.setFloat(index++, border!.borderColor?.r??0);
    shader.setFloat(index++,border!.borderColor?.g??0);
    shader.setFloat(index++,border!.borderColor?.b??0);
    shader.setFloat(index++, border!.borderColor?.a??0);
    shader.setFloat(index++,  borderAlpha);

    shader.setFloat(index++,  border!.lightIntensity);

    shader.setFloat(index++,  border!.lightColor.r);
    shader.setFloat(index++, border!.lightColor.g );
    shader.setFloat(index++,border!.lightColor.b );
    shader.setFloat(index++, border!.lightColor.a);

    shader.setFloat(index++,border!.shadowColor.r);
    shader.setFloat(index++,border!.shadowColor.g);
    shader.setFloat(index++,border!.shadowColor.b);
    shader.setFloat(index++,border!.shadowColor.a);

    shader.setFloat(index++,border!.lightDirection);
    shader.setFloat(index++,color.r);
    shader.setFloat(index++,color.b);
    shader.setFloat(index++,color.g);
    shader.setFloat(index++,color.a);
    shader.setFloat(index++,highDistortionOnCurves?1:0);
    shader.setFloat(index,border!.lightEffectIntensity);

    shader.setImageSampler(0, image);



    final borderExpand = border!.borderWidth / 2;
    final rectExpandedBorder = Rect.fromLTWH(
      lensPosition.dx - borderExpand,
      lensPosition.dy - borderExpand,
      lensWidth + 2 * borderExpand,
      lensHeight + 2 * borderExpand,
    );

    final rectRRect = RRect.fromRectAndRadius(
     rectExpandedBorder,
      Radius.circular(
        border is RoundedRectangleShape
            ? (border as RoundedRectangleShape).cornerRadius
            : 0,
      ),
    );

    //canvas.save();
    canvas.clipRRect(rectRRect);

    final lensPaint = Paint()
      ..shader = shader;

    if(useBlur) {
      lensPaint.imageFilter = ui.ImageFilter.blur(
    sigmaX: blur.sigmaX>3?3*borderAlpha:blur.sigmaX*borderAlpha,
    sigmaY: blur.sigmaY>3?3*borderAlpha:blur.sigmaX*borderAlpha,
    tileMode: ui.TileMode.clamp,
    );
    }
    canvas.drawRRect(rectRRect, lensPaint);
    //canvas.restore();

// --- PASS 2: BORDER SHADER (sharp, no blur) ---
    if (borderShader != null && useBlur) {
      index=0;
      borderShader!
        ..setFloat(index++, size.width)
        ..setFloat(index++, size.height)
        ..setFloat(index++, lensPosition.dx)
        ..setFloat(index++, lensPosition.dy)
        ..setFloat(index++, lensWidth)
        ..setFloat(index++, lensHeight)
        ..setFloat(index++, border is SuperellipseShape
            ? 1
            : 0)
        ..setFloat(index++, border is RoundedRectangleShape
            ? (border as RoundedRectangleShape).cornerRadius
            : 0)
        ..setFloat(index++, border is SuperellipseShape
            ? (border as SuperellipseShape).curveExponent
            : 0)
        ..setFloat(index++, border!.borderWidth)
        ..setFloat(index++, border!.borderSoftness)
        ..setFloat(index++, border!.borderColor?.r ?? 0)
        ..setFloat(index++, border!.borderColor?.g ?? 0)
        ..setFloat(index++, border!.borderColor?.b ?? 0)
        ..setFloat(index++, border!.borderColor?.a ?? 0)
        ..setFloat(index++, borderAlpha)
        ..setFloat(index++, border!.lightIntensity)
        ..setFloat(index++, border!.lightColor.r)
        ..setFloat(index++, border!.lightColor.g)
        ..setFloat(index++, border!.lightColor.b)
        ..setFloat(index++, border!.lightColor.a)
        ..setFloat(index++, border!.shadowColor.r)
        ..setFloat(index++, border!.shadowColor.g)
        ..setFloat(index++, border!.shadowColor.b)
        ..setFloat(index++, border!.shadowColor.a)
        ..setFloat(index++, border!.lightDirection)
        ..setFloat(index, border!.lightEffectIntensity);



      final borderPaint = Paint()..shader = borderShader;

      // Draw the sharp border directly on top
      canvas.drawRRect(rectRRect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) {
    return (oldDelegate.image != image) || (borderAlpha>0 && borderAlpha<1);
  }
}
