import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';
import 'package:liquid_glass_easy/src/helpers/slider_page_view.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass_view.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';


// Playground widget
class LiquidGlassShowcase extends StatefulWidget {

  const LiquidGlassShowcase({
    super.key,
  });

  @override
  State<LiquidGlassShowcase> createState() => _LiquidGlassShowcaseState();
}

class _LiquidGlassShowcaseState extends State<LiquidGlassShowcase> {
  // Lens properties
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // all the state values
  bool shape=false;
  double lensWidth = 280;
  double lensHeight = 60;
  double cornerRadius = 30;
  double magnification = 1.0;
  double distortion = 1;
  double distortionWidth = 30;
  double backgroundTransparencyFadeIn = 0;
  double diagonalFlip = 0;
  double borderWidth = 2.0;
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
  bool isVisible = true;
  final controller = LiquidGlassController();
  final viewController = LiquidGlassViewController();
  late Future<void> _initializeVideoPlayerFuture;

  void toggleLiquidGlassAnimation() {
    // Toggle the direction flag
    if (isVisible = (!isVisible)) {
      viewController.startRealtimeCapture();
      controller.showLiquidGlass!();
    } else {
      controller.hideLiquidGlass!(
          onComplete: viewController.stopRealtimeCapture);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed:toggleLiquidGlassAnimation,child: Text("Animation"),),
        appBar: const _FrostedAppBar(title: "Gallery"),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height*0.5-70-MediaQuery.of(context).padding.top,

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
                      alignment: Alignment.bottomLeft,margin: EdgeInsets.only(top: 20,bottom: 20,left: 20)),
                  width: lensWidth,
                  height: lensHeight,
                  magnification: magnification,
                  enableInnerRadiusTransparent: enableInnerRadiusTransparent,
                  diagonalFlip: diagonalFlip,
                  distortion: distortion,
                  distortionWidth: distortionWidth,
                  draggable: true,
                  blur: LiquidGlassBlur(sigmaX:blur  , sigmaY:blur ),
                  shape: shape?SuperellipseShape(curveExponent: curveExponent,borderWidth:borderWidth, borderSoftness: borderSoftness,lightIntensity: lightIntensity,
                      lightEffectIntensity: lightEffectIntensity,
                      lightDirection: lightDirection)
                      :RoundedRectangleShape(cornerRadius: cornerRadius,
                      borderWidth:borderWidth, borderSoftness: borderSoftness,lightIntensity: lightIntensity,
                      lightEffectIntensity: lightEffectIntensity,
                      lightDirection: lightDirection),                    visibility: visibility,
                  //child:_GlassInputBar()
                ),
              ],
              backgroundWidget:_GalleryCardsPage(),
            ),
          ), SlidersPageView(
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

class _GalleryCardsPage extends StatelessWidget {
  const _GalleryCardsPage({super.key});

  static const imageUrls = [
    'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1000&q=80',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1000&q=80',
    'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1000&q=80',
    'https://images.unsplash.com/photo-1508921912186-1d1a45ebb3c1?auto=format&fit=crop&w=1000&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.vertical, //
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12), // vertical spacing
        itemBuilder: (context, index) {
          return _GalleryCard(
            url: imageUrls[index],
            title: "Beautiful Shot #${index + 1}",
            description: "A stunning view captured for inspiration.",
          );
        },
      ),
    );
  }
}


class _GalleryCard extends StatelessWidget {
  final String url;
  final String title;
  final String description;

  const _GalleryCard({
    required this.url,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    )),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {},
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ImagePreviewPage extends StatelessWidget {
  final String url;
  const _ImagePreviewPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }}

class _GlassInputBar extends StatelessWidget {
  final String hintText;
  final VoidCallback? onMicPressed;
  final VoidCallback? onStopPressed;
  final ValueChanged<String>? onSubmitted;

  const _GlassInputBar({
    super.key,
    this.hintText = "Ask anything",
    this.onMicPressed,
    this.onStopPressed,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
     // margin: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        //color: Colors.white.withOpacity(0.4),
        //borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          // Plus button
          IconButton(
            icon: const Icon(Icons.upload, color: Colors.black),
            onPressed: () {},
          ),
          // Input field
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.black),
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.black,fontSize: 16,fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
            ),
          ),

          // Mic button
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.black),
            onPressed: onMicPressed,
          ),
          // Stop recording button
          // IconButton(
          //   icon: const Icon(Icons.stop, color: Colors.black),
          //   onPressed: onStopPressed,
          // ),
        ],
      ),
    );
  }
}


class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        //color: Colors.white.withOpacity(0.4),
        //borderRadius: BorderRadius.circular(13),
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.black, size: 24),
        onPressed: () {
        },
      ),
    );
  }
}



class _FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  final List<Widget>? actions;

  final double blurSigma;

  final Color backgroundColor;

  const _FrostedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.blurSigma = 10.0,
    this.backgroundColor = const Color.fromRGBO(0, 0, 0, 0.9),
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AppBar(
          elevation: 0,
          backgroundColor: backgroundColor,
          centerTitle: true,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.tealAccent, Colors.blueAccent],
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          actions: actions ??
              [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage:
                    NetworkImage("https://i.pravatar.cc/150?img=8"),
                  ),
                ),
              ],
        ),
      ),
    );
  }
}
