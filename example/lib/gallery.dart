import 'package:flutter/material.dart';

import 'blended_nav_page.dart';
import 'control_center_page.dart';
import 'corner_style_page.dart';
import 'lens_image_page.dart';
import 'liquid_menu_page.dart';
import 'nav_jelly_tuner.dart';
import 'elasticity_tuner.dart';
import 'scaffold_demo.dart';
import 'scaffold_svg_demo.dart';
import 'slider_jelly_tuner.dart';
import 'slider_toggle_page.dart';

// =============================================================
// Liquid Glass Easy - example gallery.
//
// A home menu that opens each demo as its OWN route, so only one glass
// capture pipeline is live at a time (kind to the Impeller multi-lens
// ceiling). The tuner pages write to a shared, in-memory store
// (TuningStore) whose values flow into the polished demos - tune a
// control, then record a clean GIF in the real demo. Values are not
// persisted; they reset to the shipped defaults on restart.
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
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
      title: 'Scaffold + Glass Nav',
      subtitle: 'Floating glass bottom nav over a music feed',
      icon: Icons.dashboard_rounded,
      gradient: const [Color(0xFF7C5CFF), Color(0xFF4B2D7A)],
      builder: (_) => const ScaffoldDemo(),
    ),
    _Destination(
      title: 'Scaffold + SVG Nav',
      subtitle: 'The same bar, but every tab glyph is an SVG asset',
      icon: Icons.image_rounded,
      gradient: const [Color(0xFF4FB3FF), Color(0xFF7C5CFF)],
      builder: (_) => const ScaffoldSvgDemo(),
    ),
    _Destination(
      title: 'Blended List + Elasticity',
      subtitle: 'A glass list panel that stretches until it fuses with a button',
      icon: Icons.blur_circular_rounded,
      gradient: const [Color(0xFF0E7C8C), Color(0xFF3A1E7A)],
      builder: (_) => const BlendedNavPage(),
    ),
    _Destination(
      title: 'Slider & Toggle',
      subtitle: 'Live glass sliders + switches',
      icon: Icons.toggle_on_rounded,
      gradient: const [Color(0xFF2DD4BF), Color(0xFF0E8C7E)],
      builder: (_) => const SliderTogglePage(),
    ),
    _Destination(
      title: 'Corner Styles',
      subtitle: 'rounded, squircle, continuous - compared',
      icon: Icons.rounded_corner_rounded,
      gradient: const [Color(0xFFFF5C8A), Color(0xFFB12A57)],
      builder: (_) => const CornerStylePage(),
    ),
  ];

  static final List<_Destination> _tuners = [
    _Destination(
      title: 'Nav Jelly Tuner',
      subtitle: 'Tune the nav pill jelly + bar look -> Scaffold demo',
      icon: Icons.science_rounded,
      gradient: const [Color(0xFFFFB020), Color(0xFFD97A06)],
      builder: (_) => const NavJellyTunerPage(),
    ),
    _Destination(
      title: 'Slider Jelly Tuner',
      subtitle: 'Tune the slider thumb jelly -> Slider & Toggle',
      icon: Icons.biotech_rounded,
      gradient: const [Color(0xFFB79CFF), Color(0xFF6E4DD8)],
      builder: (_) => const SliderJellyTunerPage(),
    ),
    _Destination(
      title: 'Elasticity Tuner',
      subtitle: 'Touch-deform a lens that never moves',
      icon: Icons.touch_app_rounded,
      gradient: const [Color(0xFF2DD4BF), Color(0xFF1E69DE)],
      builder: (_) => const ElasticityTunerPage(),
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
