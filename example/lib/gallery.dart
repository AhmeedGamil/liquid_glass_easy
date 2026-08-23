import 'package:flutter/material.dart';

import 'debug_flags.dart';
import 'touch_page.dart';
import 'switch_page.dart';
import 'control_center_page.dart';
import 'fab_dialog_demo.dart';
import 'lens_image_page.dart';
import 'liquid_menu_page.dart';
import 'nav_jelly_tuner.dart';
import 'flex_tuner.dart';
import 'basic_controls_page.dart';
import 'slider_motion_tuner.dart';
import 'slider_page.dart';
import 'tab_bar_page.dart';
import 'trip_page.dart';
import 'trip_settle_page.dart';
import 'white_page.dart';
import 'showcases/photos_library_page.dart';

// =============================================================
// Liquid Glass Easy - example gallery.
//
// A home menu that opens each demo as its OWN route, so only one glass
// capture pipeline is live at a time (kind to the Impeller multi-lens
// ceiling). The tuner pages write to a shared, in-memory store
// (TuningStore) and preview the result on a live control of their own.
// Values are not persisted; they reset to the shipped defaults on
// restart.
//
// Run it with:  flutter run -t lib/gallery.dart
// =============================================================

void main() {
  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The perf overlay is rebuilt from a notifier rather than a const
    // flag so a page can hide it while judging how the glass LOOKS —
    // the graphs sit right over the chrome most demos put at the top.
    return ValueListenableBuilder<bool>(
      valueListenable: showPerfOverlay,
      builder: (BuildContext context, bool perf, Widget? _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: perf,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C5CFF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

/// One destination on the home menu.
class _Destination {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final WidgetBuilder builder;

  const _Destination({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.builder,
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final List<_Destination> _demos = [
    _Destination(
      title: 'Blending Liquid Glasses',
      subtitle: 'Drag glass shapes together to fuse, over a photo',
      icon: Icons.blur_on_rounded,
      gradient: const [Color(0xFF34D399), Color(0xFF0F766E)],
      builder: (_) => const LensImagePage(),
    ),
    _Destination(
      title: 'Liquid Action Menu',
      subtitle: 'A glass FAB whose actions flow out of it, still connected',
      icon: Icons.bubble_chart_rounded,
      gradient: const [Color(0xFF5BC0FF), Color(0xFF7C5CFF)],
      builder: (_) => const LiquidMenuPage(),
    ),
    _Destination(
      title: 'Control Center',
      subtitle: 'iOS-style control centre, all lens-anywhere glass',
      icon: Icons.tune_rounded,
      gradient: const [Color(0xFF4FB3FF), Color(0xFF1E69DE)],
      builder: (_) => const ControlCenterPage(),
    ),
    _Destination(
      title: 'Tab Bar',
      subtitle: 'The same bar on a light page: one wide frosted capsule '
          'with a squashing glass pill',
      icon: Icons.view_carousel_rounded,
      gradient: const [Color(0xFFFF6B5A), Color(0xFFB3241A)],
      builder: (_) => const TabBarPage(),
    ),
    _Destination(
      title: 'Touch',
      subtitle: 'Press and drag a glass list — it deforms without moving',
      icon: Icons.touch_app_rounded,
      gradient: const [Color(0xFF0E7C8C), Color(0xFF3A1E7A)],
      builder: (_) => const TouchPage(),
    ),
    _Destination(
      title: 'Switch',
      subtitle: 'Three glass switches whose thumb rides your finger',
      icon: Icons.toggle_on_rounded,
      gradient: const [Color(0xFF34C759), Color(0xFF1B7A38)],
      builder: (_) => const SwitchPage(),
    ),
    _Destination(
      title: 'Slider',
      subtitle: 'Blue glass sliders — the same thumb, carried along a track',
      icon: Icons.tune_rounded,
      gradient: const [Color(0xFF0A84FF), Color(0xFF0B3E8C)],
      builder: (_) => const SliderPage(),
    ),
    _Destination(
      title: 'Basic Controls',
      subtitle: 'A single switch and a single slider, on a bare page',
      icon: Icons.tune_rounded,
      gradient: const [Color(0xFF8E8E93), Color(0xFF3A3A3C)],
      builder: (_) => const BasicControlsPage(),
    ),
    _Destination(
      title: 'FAB & Alert Dialog',
      subtitle: 'Liquid glass FABs and animated glass alert dialogs',
      icon: Icons.add_alert_rounded,
      gradient: const [Color(0xFFFF7A00), Color(0xFFFF0055)],
      builder: (_) => const FabAndDialogDemoPage(),
    ),
    _Destination(
      title: 'Thailand Trip',
      subtitle: 'Photo header, glass nav bar + action — adaptive end to end',
      icon: Icons.travel_explore_rounded,
      gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      builder: (_) => const TripPage(),
    ),
    _Destination(
      title: 'Thailand — Settle',
      subtitle: 'Palettes hold while scrolling, adaptOnce() when it settles',
      icon: Icons.pause_circle_outline_rounded,
      gradient: const [Color(0xFF136A8A), Color(0xFF267871)],
      builder: (_) => const TripSettlePage(),
    ),
    _Destination(
      title: 'White Room',
      subtitle: 'The same glass chrome over a blank white page',
      icon: Icons.crop_din_rounded,
      gradient: const [Color(0xFFE8E8E8), Color(0xFF9E9E9E)],
      builder: (_) => const WhitePage(),
    ),
  ];

  /// Whole app screens, rebuilt with the components. Each file under
  /// `lib/showcases/` is a complete page with its own `main()`, so it
  /// also runs standalone.
  static final List<_Destination> _showcases = [
    _Destination(
      title: 'Photo Library',
      subtitle: 'Edge-to-edge photo grid under a glass title bar and a '
          'split bottom bar',
      icon: Icons.photo_library_rounded,
      gradient: const [Color(0xFF0A84FF), Color(0xFF0B3E8C)],
      builder: (_) => const PhotosLibraryPage(),
    ),
  ];

  static final List<_Destination> _tuners = [
    _Destination(
      title: 'Nav Motion Tuner',
      subtitle: 'Tune the nav pill motion + bar look on a live bar',
      icon: Icons.science_rounded,
      gradient: const [Color(0xFFFFB020), Color(0xFFD97A06)],
      builder: (_) => const NavJellyTunerPage(),
    ),
    _Destination(
      title: 'Slider Motion Tuner',
      subtitle: 'Tune the slider thumb jelly on a live slider',
      icon: Icons.biotech_rounded,
      gradient: const [Color(0xFFB79CFF), Color(0xFF6E4DD8)],
      builder: (_) => const SliderMotionTunerPage(),
    ),
    _Destination(
      title: 'Flex Tuner',
      subtitle: 'Touch-deform a lens that never moves',
      icon: Icons.touch_app_rounded,
      gradient: const [Color(0xFF2DD4BF), Color(0xFF1E69DE)],
      builder: (_) => const FlexTunerPage(),
    ),
  ];

  void _open(BuildContext context, _Destination d) {
    Navigator.of(context).push(MaterialPageRoute(builder: d.builder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0A12), Color(0xFF17112E), Color(0xFF241543)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              const Text(
                'Liquid Glass Easy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A gallery of glass demos. Each opens on its own page.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 26),
              _SectionLabel('Showcases'),
              const SizedBox(height: 12),
              for (final d in _showcases) ...[
                _DestinationCard(d: d, onTap: () => _open(context, d)),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 14),
              _SectionLabel('Demos'),
              const SizedBox(height: 12),
              for (final d in _demos) ...[
                _DestinationCard(d: d, onTap: () => _open(context, d)),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 14),
              _SectionLabel('Fine-tuners'),
              const SizedBox(height: 12),
              for (final d in _tuners) ...[
                _DestinationCard(d: d, onTap: () => _open(context, d)),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final _Destination d;
  final VoidCallback onTap;

  const _DestinationCard({required this.d, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: d.gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: d.gradient.last.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(d.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
