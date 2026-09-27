import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// LiquidGlassWarmUp is not part of the public API.
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_warm_up.dart';

import 'app_settings.dart';
import 'settings_page.dart';
import 'touch_page.dart';
import 'switch_page.dart';
import 'control_center_page.dart';
import 'fab_dialog_demo.dart';
import 'sheet_field_page.dart';
import 'lens_image_page.dart';
import 'shadow_page.dart';
import 'lite_page.dart';
import 'dialog_page.dart';
import 'scroll_edge_page.dart';
import 'motion_pill_page.dart';
import 'liquid_menu_page.dart';
import 'morph_page.dart';
import 'nav_jelly_tuner.dart';
import 'flex_tuner.dart';
import 'basic_controls_page.dart';
import 'batch_page.dart';
import 'slider_motion_tuner.dart';
import 'slider_page.dart';
import 'tab_bar_page.dart';
import 'adaptivity_page.dart';
import 'adaptivity_advanced_page.dart';
import 'adaptivity_controller_page.dart';
import 'device_preview_page.dart';
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
// The gear at the top right opens Settings: light/dark on a glass
// switch. Not persisted.
//
// Run it with:  flutter run -t lib/gallery.dart
// =============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One await compiles the lens and blender programs, so the first page a
  // demo opens — blender, morph, lens — is glass on its very first frame.
  await LiquidGlassShaders.ensureLoaded();
  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Notifiers rather than const flags so the Settings page's glass
    // switches can flip the whole app from anywhere. The lite-glass one is
    // listened to as well so every mounted lens rebuilds when it flips.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[darkMode, liteGlass]),
      builder: (BuildContext context, Widget? _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        // showPerformanceOverlay: true,
        theme: galleryTheme(Brightness.light),
        darkTheme: galleryTheme(Brightness.dark),
        themeMode: darkMode.value ? ThemeMode.dark : ThemeMode.light,
        // Nothing else to wire for the glass: adaptivity's last resort
        // is the app theme's brightness by default, so every surface
        // that cannot read its backdrop follows this themeMode.
        //
        // The warm-up compiles the glass GPU programs during launch, so
        // the first switch or slider touched on the Skia backend does
        // not stall the raster thread waiting for the driver. It paints
        // a few frames under the home page, then removes itself for
        // good. On Impeller it draws a lens and a blender once, so the
        // first page with a blender does not stall building its pipeline.
        home: const LiquidGlassWarmUp(child: HomePage()),
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
      title: 'Shadow',
      subtitle: 'The contact shadow that sets glass into a light page, '
          'on two draggable lenses',
      icon: Icons.tonality_outlined,
      gradient: const [Color(0xFF94A3B8), Color(0xFF1E293B)],
      builder: (_) => const ShadowPage(),
    ),
    _Destination(
      title: 'Lite glass',
      subtitle: 'The material without the shader: frost, tint and rim, '
          'no capture and no refraction',
      icon: Icons.blur_on_rounded,
      gradient: const [Color(0xFF67E8F9), Color(0xFF0E7490)],
      builder: (_) => const LitePage(),
    ),
    _Destination(
      title: 'Alert Dialog',
      subtitle: 'Three glass dialogs through showLiquidGlassDialog, in a '
          'LiquidGlassScaffold',
      icon: Icons.chat_bubble_outline_rounded,
      gradient: const [Color(0xFFFB7185), Color(0xFF9F1239)],
      builder: (_) => const DialogPage(),
    ),
    _Destination(
      title: 'Scroll Edge',
      subtitle: 'A tinted, blurred band over each end of a photo journal',
      icon: Icons.gradient_rounded,
      gradient: const [Color(0xFFFBBF24), Color(0xFF92400E)],
      builder: (_) => const ScrollEdgePage(),
    ),
    _Destination(
      title: 'Motion Pill',
      subtitle: "The slider's capsule thumb on its own, riding a rail",
      icon: Icons.touch_app_rounded,
      gradient: const [Color(0xFF818CF8), Color(0xFF312E81)],
      builder: (_) => const MotionPillPage(),
    ),
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
      title: 'Morph Component',
      subtitle: 'LiquidGlassMorph — glass that fits whatever you put in it, '
          'with the anchor switchable live',
      icon: Icons.widgets_rounded,
      gradient: const [Color(0xFF22D3EE), Color(0xFF0F766E)],
      builder: (_) => const LiquidGlassMorphExamplePage(),
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
      subtitle: 'One wide frosted capsule on a light page, with all three '
          'pill modes a chip apart',
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
      title: 'Sheets',
      subtitle: 'Glass sheets that hug, detent or sit on the bottom edge',
      icon: Icons.keyboard_double_arrow_up_rounded,
      gradient: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
      builder: (_) => const SheetFieldPage(),
    ),
    _Destination(
      title: 'Batch',
      subtitle: 'A field of floating glass cards on one shared backdrop read',
      icon: Icons.grid_view_rounded,
      gradient: const [Color(0xFF7C5CFF), Color(0xFF3B2E8C)],
      builder: (_) => const BatchPage(),
    ),
    _Destination(
      title: 'Adaptivity',
      subtitle: 'Every glass surface judges the photo behind ITSELF, so '
          'they can disagree',
      icon: Icons.travel_explore_rounded,
      gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      builder: (_) => const AdaptivityPage(),
    ),
    _Destination(
      title: 'Adaptivity — Advanced',
      subtitle: 'An area samples once and publishes on a link; the rest '
          'follow it',
      icon: Icons.link_rounded,
      gradient: const [Color(0xFF8E7BFF), Color(0xFF4B3BB8)],
      builder: (_) => const AdaptivityAdvancedPage(),
    ),
    _Destination(
      title: 'Adaptivity — Controller',
      subtitle: 'Palettes hold while scrolling, adaptOnce() when it settles',
      icon: Icons.pause_circle_outline_rounded,
      gradient: const [Color(0xFF136A8A), Color(0xFF267871)],
      builder: (_) => const AdaptivityControllerPage(),
    ),
    _Destination(
      title: 'Device preview',
      subtitle: 'The whole app scaled down into a phone frame: does the '
          'glass stay on its outline?',
      icon: Icons.phonelink_rounded,
      gradient: const [Color(0xFFF472B6), Color(0xFF9D174D)],
      builder: (_) => const DevicePreviewPage(),
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
    final Brightness brightness = Theme.of(context).brightness;
    final Color ink =
        brightness == Brightness.dark ? Colors.white : const Color(0xFF11131A);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: galleryBackground(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Liquid Glass Easy',
                      style: TextStyle(
                        color: ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                    icon: const Icon(Icons.settings_rounded),
                    color: ink.withValues(alpha: 0.7),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'A gallery of glass demos. Each opens on its own page.',
                style: TextStyle(
                  color: ink.withValues(alpha: 0.6),
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: (dark ? Colors.white : const Color(0xFF11131A))
            .withValues(alpha: 0.5),
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : const Color(0xFF11131A);

    return Material(
      color: Colors.white.withValues(alpha: dark ? 0.05 : 0.55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
            ),
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
                      style: TextStyle(
                        color: ink,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.subtitle,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: ink.withValues(alpha: 0.4), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
