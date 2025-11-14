import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  runApp(const LiquidGlassExampleApp());
}

class LiquidGlassExampleApp extends StatelessWidget {
  const LiquidGlassExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LiquidGlassExample(),
    );
  }
}

class LiquidGlassExample extends StatefulWidget {
  const LiquidGlassExample({super.key});

  @override
  State<LiquidGlassExample> createState() => _LiquidGlassExampleState();
}

class _LiquidGlassExampleState extends State<LiquidGlassExample> {
  final viewController = LiquidGlassViewController();
  final lensController = LiquidGlassController();

  // Start with realtime capturing ON
  bool _realtime =
      true;

  // We cycle through three gradient backgrounds (no images required).
  int _bgIndex = 0;

  Widget _buildBackground() {
    final List<Image> images = [
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/flower.jpg",
        fit: BoxFit.fitWidth,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/rain.jpg",
        fit: BoxFit.fitHeight,
        width: double.infinity,
        height: 300,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/neon.png",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_1.png",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_2.jpg",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_3.jpg",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    ];

    return Stack(alignment: Alignment.center,
      children: [
        images[_bgIndex], // spread the list into widgets
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(
              'Liquid Glass Easy Example',
              style: TextStyle(
                fontSize: 26,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshSnapshot() async {
    lensController.hideLiquidGlass(animationTimeMillisecond: 280);
    await Future.delayed(const Duration(milliseconds: 340));
    await viewController.captureOnce();
    lensController.showLiquidGlass(animationTimeMillisecond: 280);
  }

  void _nextBackground() {
    setState(() {
      //lensController.resetLiquidGlassPosition();
      _bgIndex = (_bgIndex + 1) % 6;
      print(_bgIndex);
    });
    if (!_realtime) {
      viewController.captureOnce();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: LiquidGlassView(
          controller: viewController,
          backgroundWidget: _buildBackground(),
          pixelRatio: 1,
          useSync: true,
          realTimeCapture: _realtime,
          refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
          children: [
            if (_bgIndex == 0)
              LiquidGlass(
                controller: lensController,
                position:
                const LiquidGlassAlignPosition(alignment: Alignment.center),
                width: 100,
                height: 100,
                magnification: 1,
                enableInnerRadiusTransparent: false,
                diagonalFlip: 0,
                distortion: 0.225,
                distortionWidth: 50,
                draggable: true,
                outOfBoundaries: true,
                blur: LiquidGlassBlur(sigmaX: 0.75, sigmaY: 0.75),
                shape: RoundedRectangleShape(
                    //highDistortionOnCurves: true,
                    cornerRadius: 50,
                    borderWidth: 1,
                    borderSoftness: 2.5,
                    lightIntensity: 1.5,
                    lightDirection: 39.0),
              child:
                Container(
                  decoration:  BoxDecoration(borderRadius: BorderRadius.circular(50),),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                      child: Container(
                          height: 50,
                          width: 50,
                          child: Icon(
                            color: Colors.white,
                          Icons.pause,
                            size: 36,
                          ))),
                ),
              ),

            if (_bgIndex == 1)
              LiquidGlass(
                controller: lensController,
                position:
                const LiquidGlassAlignPosition(alignment: Alignment.center),
                width: 240 * 0.8,
                height: 312 * 0.8,
                magnification: 1,
                enableInnerRadiusTransparent: false,
                diagonalFlip: 0,
                distortion: 0.15,
                distortionWidth: 70,
                draggable: true,
                outOfBoundaries: true,
                color: Colors.grey.withAlpha(60),
                blur: LiquidGlassBlur(sigmaX: 0.5, sigmaY: 0.5),
                shape: RoundedRectangleShape(
                    cornerRadius: 70 * 0.8,
                    borderWidth: 1,
                    borderSoftness: 7.5,
                    lightIntensity: 1.5 * 0.6,
                    lightEffectIntensity: 0.4,
                    lightDirection: 39.0),
                visibility: true,
                child: Center(
                  child: WeatherWidget(
                    cityName: "City",
                    description: "Rainy",
                    temperature: 23.4,
                    minTemp: 22.0,
                    maxTemp: 30.5,
                    humidity: 58,
                    windSpeed: 14.3,
                    weatherIcon: Icons.water_drop_rounded,
                  ),
                ),
              ),
            if (_bgIndex == 2)
              LiquidGlass(
                  //controller: controller,
                  position:const LiquidGlassAlignPosition(alignment: Alignment.center),
                  width: 250,
                  height: 250,
                  magnification: 1,
                  enableInnerRadiusTransparent: false,
                  diagonalFlip: 0,
                  distortion: 0.175,
                  distortionWidth: 80,
                  draggable: true,
                  outOfBoundaries: true,
                  blur: LiquidGlassBlur(sigmaX: 0, sigmaY: 0),
                  shape: SuperellipseShape(
                      curveExponent: 3,
                      borderWidth: 1,
                      borderSoftness: 1,
                      lightIntensity: 1,
                      lightDirection: 0)
                  //child:GlassInputBar()
                  ),
            if (_bgIndex == 3)
              LiquidGlass(
                controller: lensController,
                width: 240,
                height: 200,
                magnification: 1,
                distortion: 0.5,
                draggable: true,
                distortionWidth: 70,
                position: LiquidGlassAlignPosition(alignment: Alignment.center),
                shape: RoundedRectangleShape(
                  lightDirection: 140,
                  lightIntensity: 1.5,
                  borderWidth: 2,
                  borderSoftness: 1.5,
                ),
                //child: const Center(
                //child: Icon(Icons.search, size: 42, color: Colors.white70),
                //),
              ),
            if (_bgIndex == 4)
              LiquidGlass(
                controller: lensController,
                width: 240,
                height: 200,
                magnification: 1,
                distortion: 0.2,
                draggable: true,
                outOfBoundaries: true,
                distortionWidth: 70,
                position: LiquidGlassAlignPosition(alignment: Alignment.center),
                shape: SuperellipseShape(
                    lightDirection: 140,
                    lightIntensity: 1.5,
                    borderWidth: 2,
                    borderSoftness: 1.5,
                    curveExponent: 4),
                // child: const Center(
                //   child: Icon(Icons.search, size: 42, color: Colors.white70),
                // ),
              ),
            if (_bgIndex == 5)
              LiquidGlass(
                controller: lensController,
                width: 150,
                height: 150,
                magnification: 1,
                distortion: 0.15,
                draggable: true,
                outOfBoundaries: true,
                distortionWidth: 50,
                position: LiquidGlassAlignPosition(alignment: Alignment.center),
                shape: RoundedRectangleShape(
                  highDistortionOnCurves: true,
                    lightDirection: 140,
                    lightIntensity: 1.5,
                    borderWidth: 2,
                    borderSoftness: 1.5,
                    cornerRadius: 75),
                // child: const Center(
                //   child: Icon(Icons.search, size: 42, color: Colors.white70),
                // ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false, // note: 'false' would break Dart; fix to false if needed.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refreshSnapshot,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Snapshot'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _nextBackground,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Next Background'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeatherWidget extends StatelessWidget {
  final String cityName;
  final String description;
  final double temperature;
  final double minTemp;
  final double maxTemp;
  final double humidity;
  final double windSpeed;
  final IconData weatherIcon;

  const WeatherWidget({
    super.key,
    required this.cityName,
    required this.description,
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.windSpeed,
    this.weatherIcon = Icons.wb_sunny_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300 * 0.8, // 198
      padding: const EdgeInsets.all(21 * 0.8), // ~14
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24 * 0.8), // ~16
        border: Border.all(color: Colors.white.withOpacity(0.0), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // City + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cityName,
                style: const TextStyle(
                  fontSize: 22 * 0.8, // 14.5
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                _formattedDate(),
                style: TextStyle(
                  fontSize: 14 * 0.8, // 9.2
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16 * 0.8), // 10.5

          // Icon + Temperature
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                weatherIcon,
                size: 44 * 0.8, // 31.5
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 12 * 0.8), // 7.9
              Text(
                "${temperature.toStringAsFixed(1)}°",
                style: const TextStyle(
                  fontSize: 52 * 0.8, // 37
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 0.9,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8 * 0.8), // 5.3

          // Weather description
          Text(
            description,
            style: const TextStyle(
              fontSize: 18 * 0.8, // 11.9
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 16 * 0.8), // 10.5

          // Min / Max temperatures
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tempInfo("Min", minTemp),
              const SizedBox(width: 16 * 0.8), // 10.5
              _tempInfo("Max", maxTemp),
            ],
          ),

          const SizedBox(height: 16 * 0.8), // 10.5

          // Extra info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _extraInfo(Icons.water_drop_rounded, "Humidity", "$humidity%"),
              _extraInfo(Icons.air_rounded, "Wind", "${windSpeed} km/h"),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    return "${now.day}/${now.month}/${now.year}";
  }

  Widget _tempInfo(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14 * 0.8, // 9.2
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Text(
          "${value.toStringAsFixed(1)}°",
          style: const TextStyle(
            fontSize: 16 * 0.8, // 10.6
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _extraInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon,
            color: Colors.white.withOpacity(0.9), size: 22 * 0.8), // 14.5
        const SizedBox(height: 4 * 0.8), // 2.6
        Text(
          label,
          style: TextStyle(
            fontSize: 12 * 0.8, // 7.9
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13 * 0.8, // 8.6
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
