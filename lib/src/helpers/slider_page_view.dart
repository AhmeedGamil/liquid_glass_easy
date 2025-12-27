import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_light_mode.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';

import '../widgets/utils/liquid_glass_refraction_mode.dart';

class SlidersPageView extends StatelessWidget {
  final PageController controller;
  final int currentPage;

  // values + callbacks
  final bool shape;

  final double lensWidth;
  final double lensHeight;
  final double cornerRadius;
  final double magnification;
  final bool refractionMode;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final double borderWidth;
  final double borderSoftness;
  final double lightIntensity;
  final double oneSideLightIntensity;
  final double lightDirection;
  final bool lightMode;
  final double chromaticAberration;
  final double saturation;
  final double curveExponent;
  final double pixelRatio;
  final double blur;
  final double refreshRate;
  final bool realTimeCapture;
  final bool useSync;
  final bool enableInnerRadiusTransparent;

  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onShapeChanged;

  final ValueChanged<double> onLensWidthChanged;
  final ValueChanged<double> onLensHeightChanged;
  final ValueChanged<double> onCornerRadiusChanged;
  final ValueChanged<double> onMagnificationChanged;
  final ValueChanged<bool> onRefractionModeChanged;
  final ValueChanged<double> onDistortionChanged;
  final ValueChanged<double> onDistortionWidthChanged;
  final ValueChanged<double> onDiagonalFlipChanged;
  final ValueChanged<double> onBorderWidthChanged;
  final ValueChanged<double> onBorderSoftnessChanged;
  final ValueChanged<double> onLightIntensityChanged;
  final ValueChanged<double> onOneSideLightIntensityChanged;

  final ValueChanged<double> onLightDirectionChanged;
  final ValueChanged<bool> onLightModeChanged;
  final ValueChanged<double> onChromaticAberrationChanged;
  final ValueChanged<double> onSaturationChanged;


  final ValueChanged<double> onCurveExponentChanged;
  final ValueChanged<double> onBlurChanged;
  final ValueChanged<double> onRefreshRateChanged;
  final ValueChanged<double> onPixelRatioChanged;
  final ValueChanged<bool> onRealTimeCaptureChanged;
  final ValueChanged<bool> onUseSyncChanged;
  final ValueChanged<bool> onEnableInnerRadiusTransparent;

  const SlidersPageView({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.shape,
    required this.lensWidth,
    required this.lensHeight,
    required this.cornerRadius,
    required this.magnification,
    required this.refractionMode,
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.borderWidth,
    required this.borderSoftness,
    required this.lightIntensity,
    required this.oneSideLightIntensity,
    required this.lightDirection,
    required this.lightMode,
    required this.chromaticAberration,
    required this.saturation,
    required this.curveExponent,
    required this.pixelRatio,
    required this.blur,
    required this.refreshRate,
    required this.realTimeCapture,
    required this.useSync,
    required this.enableInnerRadiusTransparent,
    required this.onPageChanged,
    required this.onShapeChanged,
    required this.onLensWidthChanged,
    required this.onLensHeightChanged,
    required this.onCornerRadiusChanged,
    required this.onMagnificationChanged,
    required this.onRefractionModeChanged,
    required this.onDistortionChanged,
    required this.onDistortionWidthChanged,
    required this.onEnableInnerRadiusTransparent,
    required this.onDiagonalFlipChanged,
    required this.onBorderWidthChanged,
    required this.onBorderSoftnessChanged,
    required this.onLightIntensityChanged,
    required this.onOneSideLightIntensityChanged,
    required this.onLightDirectionChanged,
    required this.onLightModeChanged,
    required this.onChromaticAberrationChanged,
    required this.onSaturationChanged,
    required this.onCurveExponentChanged,
    required this.onBlurChanged,
    required this.onRefreshRateChanged,
    required this.onPixelRatioChanged,
    required this.onRealTimeCaptureChanged,
    required this.onUseSyncChanged,
  });

  static const int totalPages = 4;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    return SizedBox(
      height: MediaQuery.of(context).size.height*0.5,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentPage > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () {
                    controller.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                )
              else
                const SizedBox(width: 48),
              Text(
                "Page ${currentPage + 1} / $totalPages",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (currentPage < totalPages - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () {
                    controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                )
              else
                const SizedBox(width: 48),
            ],
          ),
    Expanded(
            child: PageView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: onPageChanged,
              children: [
                // --- Page 1: Lens Settings ---
                _buildSliderPage(
                  context,
                  title: "Lens Settings",
                  icon: Icons.center_focus_strong,
                  copyButton:
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy values",style: TextStyle(fontSize: 12,color: Colors.black),),
                    style: ElevatedButton.styleFrom(
                      //backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final code = _generateLiquidGlassCode();
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Copied LiquidGlass code with sliders values to clipboard"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  sliders: [

              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text("Rounded Rectangle - Superellipse"),
                ),
                Switch(
                  value: shape,
                  onChanged: onShapeChanged,
                ),
              ],
            ),
                    SliderWidget(
                      label: "Width",
                      value: lensWidth,
                      min: 50,
                      max: 400,
                      devision: 350,
                      onChanged: onLensWidthChanged,
                    ),
                    SliderWidget(
                      label: "Height",
                      value: lensHeight,
                      min: 50,
                      max: 400,
                      devision: 350,
                      onChanged: onLensHeightChanged,
                    ),
                    SliderWidget(
                      label: "Corner Radius (Rounded Rectangle)",
                      value: cornerRadius,
                      min: 0,
                      max: 100,
                      devision: 100,
                      onChanged: onCornerRadiusChanged,
                    ),
                    SliderWidget(
                      label: "Curve Exponent (Superellipse)",
                      value: curveExponent,
                      min: 0.1,
                      max: 7.0,
                      devision: 100,
                      onChanged: onCurveExponentChanged,
                    ),
                  ],
                ),

                // --- Page 2: Effects & Distortion ---
                _buildSliderPage(
                  context,
                  title: "Effects & Distortion",
                  icon: Icons.blur_on,
                  sliders: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Shape Refraction - Radial Refraction"),
                        ),
                        Switch(
                          value: refractionMode,
                          onChanged: onRefractionModeChanged,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Distortion",
                      value: distortion,
                      min: 0,
                      max: 1,
                      devision: 100,
                      onChanged: onDistortionChanged,
                    ),

                    SliderWidget(
                      label: "Distortion Width",
                      value: distortionWidth,
                      min: 0,
                      max: 100,
                      devision: 100,
                      onChanged: onDistortionWidthChanged,
                    ),

                    SliderWidget(
                      label: "Magnification",
                      value: magnification,
                      min: 0,
                      max: 5.0,
                      devision: 100,
                      onChanged: onMagnificationChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Enable Transparency"),
                        ),
                        Switch(
                          value: enableInnerRadiusTransparent,
                          onChanged: onEnableInnerRadiusTransparent,
                        ),
                      ],
                    ),

                    SliderWidget(
                      label: "Diagonal Flip",
                      value: diagonalFlip,
                      min: 0,
                      max: 1,
                      devision: 100,
                      onChanged: onDiagonalFlipChanged,
                    ),
                    SliderWidget(
                      label: "Blur",
                      value: blur,
                      min: 0,
                      max: 3,
                      devision: 30,
                      onChanged: onBlurChanged,
                    ),

                    SliderWidget(
                      label: "Chromatic Aberration",
                      value: chromaticAberration,
                      min: 0,
                      max: 0.25,
                      devision: 100,
                      onChanged: onChromaticAberrationChanged,
                    ),

                    SliderWidget(
                      label: "Saturation",
                      value: saturation,
                      min: 0,
                      max: 3,
                      devision: 30,
                      onChanged: onSaturationChanged,
                    ),
                  ],
                ),

                // --- Page 3: Border Settings (NEW) ---
                _buildSliderPage(
                  context,
                  title: "Border Settings",
                  icon: Icons.border_style,
                  sliders: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text("Edge light Mode - Radial Light Mode"),
                        ),
                        Switch(
                          value: lightMode,
                          onChanged: onLightModeChanged,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Border Width",
                      value: borderWidth,
                      min: 0,
                      max: 20,
                      devision: 100,
                      onChanged: onBorderWidthChanged,
                    ),
                    SliderWidget(
                      label: "Border Softness",
                      value: borderSoftness,
                      min: 0,
                      max: 50,
                      devision: 100,
                      onChanged: onBorderSoftnessChanged,
                    ),
                    SliderWidget(
                      label: "Light Intensity",
                      value: lightIntensity,
                      min: 0,
                      max: 5,
                      devision: 100,
                      onChanged: onLightIntensityChanged,
                    ),
                    SliderWidget(
                      label: "One Side Light Intensity",
                      value: oneSideLightIntensity,
                      min: 0,
                      max: 5,
                      devision: 100,
                      onChanged: onOneSideLightIntensityChanged,
                    ),
                    SliderWidget(
                      label: "Light Direction",
                      value: lightDirection,
                      min: 0,
                      max: 360,
                      devision: 360,
                      onChanged: onLightDirectionChanged,
                    ),
                  ],
                ),

                // --- Page 4: Performance ---
                _buildSliderPage(
                  context,
                  title: "Performance",
                  icon: Icons.speed,
                  sliders: [
                    const SizedBox(height: 8),
                    SliderWidget(
                      label: "Pixel Ratio",
                      value: pixelRatio,
                      min: 0,
                      max: 3.0,
                      devision: 30,
                      onChanged: onPixelRatioChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Real Time Capture"),
                        Switch(
                          value: realTimeCapture,
                          onChanged: onRealTimeCaptureChanged,
                        ),
                      ],
                    ),
                    SliderWidget(
                      label: "Refresh Rate",
                      value: refreshRate,
                      min: 0,
                      max: 3,
                      devision: 3,
                      onChanged: onRefreshRateChanged,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      Text("Low"),
                      Text("Medium"),
                      Text("High"),
                      Text("Device Refresh Rate"),
                    ],),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Use Sync"),
                        Switch(
                          value: useSync,
                          onChanged: onUseSyncChanged,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(4),
                width: currentPage == index ? 20 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: currentPage == index ? accent : Colors.grey.shade400,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _generateLiquidGlassCode() {

    final refractionModeCode=refractionMode?
    '''${LiquidGlassRefractionMode.radialRefraction}'''
        :
    '''${LiquidGlassRefractionMode.shapeRefraction}''';
    final lightModeCode=lightMode?
    '''${LiquidGlassLightMode.radial}'''
        :
        '''${LiquidGlassLightMode.edge}''';

    final shapeCode = shape
        ? '''
SuperellipseShape(
  oneSideLightIntensity: $oneSideLightIntensity,
  curveExponent: $curveExponent,
  borderWidth: $borderWidth,
  borderSoftness: $borderSoftness,
  lightIntensity: $lightIntensity,
  lightDirection: $lightDirection,
  lightMode: $lightModeCode
)
'''
        : '''
RoundedRectangleShape(
  oneSideLightIntensity: $oneSideLightIntensity,
  cornerRadius: $cornerRadius,
  borderWidth: $borderWidth,
  borderSoftness: $borderSoftness,
  lightIntensity: $lightIntensity,
  lightDirection: $lightDirection,
  lightMode: $lightModeCode
)
''';

    return '''
LiquidGlassView(
  controller: viewController,
  pixelRatio: $pixelRatio,
  realTimeCapture: $realTimeCapture,
  refreshRate: ${
        refreshRate==0?
        LiquidGlassRefreshRate.low
            :  refreshRate==1? LiquidGlassRefreshRate.medium
            :refreshRate==2? LiquidGlassRefreshRate.high
            :LiquidGlassRefreshRate.deviceRefreshRate
    },
  useSync: $useSync,
  backgroundWidget: YourBackgroundWidget(),
  children: [
    LiquidGlass(
      controller: controller,
      position: const LiquidGlassAlignPosition(
        alignment: Alignment.center,
      ),
      width: $lensWidth,
      height: $lensHeight,
      magnification: $magnification,
      refractionMode:$refractionModeCode,
      enableInnerRadiusTransparent: $enableInnerRadiusTransparent,
      diagonalFlip: $diagonalFlip,
      distortion: $distortion,
      distortionWidth: $distortionWidth,
      draggable: true,
      blur: LiquidGlassBlur(sigmaX: $blur, sigmaY: $blur),
      shape: $shapeCode,
      chromaticAberration:$chromaticAberration,
      saturation:$saturation
    ),
  ],
);
''';
  }

  Widget _buildSliderPage(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> sliders,
        Widget copyButton= const SizedBox.shrink(),
  }) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
        clipBehavior: Clip.antiAlias,
        child: _ScrollableWithHint(
          title: title,
          icon: icon,
          sliders: sliders,
          copyButton: copyButton,
        ),
      ),
    );
  }
}

class _ScrollableWithHint extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> sliders;
  final Widget copyButton;

  const _ScrollableWithHint({
    required this.title,
    required this.icon,
    required this.sliders,
    this.copyButton = const SizedBox.shrink(),
  });

  @override
  State<_ScrollableWithHint> createState() => _ScrollableWithHintState();
}

class _ScrollableWithHintState extends State<_ScrollableWithHint> {
  bool _showHint = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(widget.icon,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  widget.copyButton,
                ],
              ),
              const Divider(),

              // Scrollable sliders
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels > 10 && _showHint) {
                      setState(() => _showHint = false);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(children: widget.sliders),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 👇 Show animated arrow only if _showHint = true
        if (_showHint)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: _ScrollHintArrow(),
          ),
      ],
    );
  }
}

class _ScrollHintArrow extends StatefulWidget {
  @override
  State<_ScrollHintArrow> createState() => _ScrollHintArrowState();
}

class _ScrollHintArrowState extends State<_ScrollHintArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _offset = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: Icon(
            Icons.keyboard_arrow_down,
            size: 28,
            color: Colors.black.withAlpha(229),
          ),
        );
      },
    );
  }
}

class SliderWidget extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? devision;
  final ValueChanged<double> onChanged;

  const SliderWidget({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.devision,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                value.toStringAsFixed(2), // Show value here
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),

          // Slider
          Slider(
            activeColor: accent,
            inactiveColor: accent.withAlpha(76),
            value: value,
            min: min,
            max: max,
            divisions: devision,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
