import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';

import '../controllers/liquid_glass_controller.dart';
import '../controllers/liquid_glass_view_controller.dart';
import '../helpers/slider_page_view.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/liquid_glass_view.dart';
import '../widgets/utils/liquid_glass_blur.dart';
import '../widgets/utils/liquid_glass_shape.dart';
import '../widgets/utils/liquid_glass_position.dart';

// Playground widget
class LiquidGlassPlayground extends StatefulWidget {
  final Widget backgroundWidget; // <-- Passable background

  const LiquidGlassPlayground({
    super.key,
    required this.backgroundWidget,
  });

  @override
  State<LiquidGlassPlayground> createState() => _LiquidGlassPlaygroundState();
}

class _LiquidGlassPlaygroundState extends State<LiquidGlassPlayground> {
  // Lens properties
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // all the state values
  bool shape=false;

  double lensWidth = 200;
  double lensHeight = 100;
  double cornerRadius = 50;
  double magnification = 1.0;
  double distortion = 0.2;
  double distortionWidth = 40;
  double backgroundTransparencyFadeIn = 0;
  double diagonalFlip = 0;
  double borderWidth = 1.0;
  double borderSoftness = 1.0;
  double lightIntensity =1.0;
  double lightEffectIntensity =0.0;

  double lightDirection = 0.0;
  double  curveExponent=3;
  double pixelRatio = 1.0;
  bool realTimeCapture = true;
  bool useSync = true;
  bool enableInnerRadiusTransparent = false;
  bool visibility = true;
  double blur=0;
  double refreshRate=3;
  LiquidGlassRefreshRate liquidGlassRefreshRate=LiquidGlassRefreshRate.deviceRefreshRate;
  final controller = LiquidGlassController();
  final viewController = LiquidGlassViewController();
  bool isVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () {
        if (isVisible = (!isVisible)) {
          viewController.startRealtimeCapture();
          controller.showLiquidGlass!();
        } else {
          controller.hideLiquidGlass!(
              onComplete: viewController.stopRealtimeCapture);
        }
      }, child: Text('Animation'),),
      appBar: AppBar(title: const Text("Liquid Glass Playground")),
      body: Column(
        children: [
          SizedBox(
      height: MediaQuery.of(context).size.height*0.5-kToolbarHeight-MediaQuery.of(context).padding.top,
            child: LiquidGlassView(
              controller: viewController,
              pixelRatio: pixelRatio,
              realTimeCapture: realTimeCapture,
              refreshRate: liquidGlassRefreshRate,

              useSync: useSync,
              children: [
                LiquidGlass(
                  controller: controller,
                  position: const LiquidGlassAlignPosition(
                      alignment: Alignment.center),
                  width: lensWidth,
                  height: lensHeight,
                  magnification: magnification,
                  distortion: distortion,
                  distortionWidth: distortionWidth,
                  draggable: true,
                  blur: LiquidGlassBlur(sigmaX:blur  , sigmaY:blur ),
                  shape: shape?SuperellipseShape(curveExponent: curveExponent,borderWidth:borderWidth, borderSoftness: borderSoftness,lightIntensity: lightIntensity,lightDirection: lightDirection,lightEffectIntensity:lightEffectIntensity )
                    :RoundedRectangleShape(cornerRadius: cornerRadius,borderWidth:borderWidth, borderSoftness: borderSoftness,lightIntensity: lightIntensity,lightDirection: lightDirection,lightEffectIntensity: lightEffectIntensity),
                  visibility: visibility,
                ),
              ],
              backgroundWidget: widget.backgroundWidget, // <-- passed in
            ),
          ),
          SlidersPageView(
            controller: _pageController,
            currentPage: _currentPage,
            shape: shape,
            lensWidth: lensWidth,
            lensHeight: lensHeight,
            cornerRadius: cornerRadius,
            magnification: magnification,
            distortion: distortion,
            distortionWidth: distortionWidth,
            diagonalFlip: diagonalFlip,
            borderWidth: borderWidth,
            borderSoftness: borderSoftness,
            curveExponent: curveExponent,
            lightDirection: lightDirection,
            lightIntensity: lightIntensity,
            lightEffectIntensity: lightEffectIntensity,
            blur: blur,
            refreshRate: refreshRate,
            pixelRatio: pixelRatio,
            realTimeCapture: realTimeCapture,
            useSync: useSync,
            enableInnerRadiusTransparent: enableInnerRadiusTransparent,
            // callbacks update state
            onPageChanged: (i) => setState(() => _currentPage = i),
            onShapeChanged: (i)=> setState(() => shape = i),
            onLensWidthChanged: (v) => setState(() => lensWidth = v),
            onLensHeightChanged: (v) => setState(() => lensHeight = v),
            onCornerRadiusChanged: (v) => setState(() => cornerRadius = v),
            onMagnificationChanged: (v) => setState(() => magnification = v),
            onDistortionChanged: (v) => setState(() => distortion = v),
            onDistortionWidthChanged: (v) =>
                setState(() => distortionWidth = v),
            onDiagonalFlipChanged: (v) => setState(() => diagonalFlip = v),
            onBorderWidthChanged: (v) => setState(() => borderWidth = v),
            onBorderSoftnessChanged:(v) => setState(() => borderSoftness = v),
            onCurveExponentChanged: (v) => setState(() => curveExponent = v),
            onLightIntensityChanged: (v) => setState(() => lightIntensity = v),
            onLightEffectIntensityChanged: (v) => setState(() => lightEffectIntensity = v),
            onLightDirectionChanged: (v) => setState(() => lightDirection = v),
            onBlurChanged: (v) => setState(() => blur = v),
            onRefreshRateChanged:(v) => setState(() {
              v==0?
              liquidGlassRefreshRate=LiquidGlassRefreshRate.low
                  :  v==1? liquidGlassRefreshRate=LiquidGlassRefreshRate.medium
                  :v==2? liquidGlassRefreshRate=LiquidGlassRefreshRate.high
                  :liquidGlassRefreshRate=LiquidGlassRefreshRate.deviceRefreshRate;
              refreshRate = v;
            }),

            onPixelRatioChanged: (v) => setState(() => pixelRatio = v),
            onRealTimeCaptureChanged: (v) =>
                setState(() => realTimeCapture = v),
            onUseSyncChanged: (v) => setState(() => useSync = v),
            onEnableInnerRadiusTransparent: (v) =>
                setState(() => enableInnerRadiusTransparent = v),
          ),
        ],
      ),
    );
  }
}
