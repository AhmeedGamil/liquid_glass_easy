import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Interactive showcase page for [LiquidGlassFab] and [LiquidGlassAlertDialog].
class FabAndDialogDemoPage extends StatefulWidget {
  const FabAndDialogDemoPage({super.key});

  @override
  State<FabAndDialogDemoPage> createState() => _FabAndDialogDemoPageState();
}

class _FabAndDialogDemoPageState extends State<FabAndDialogDemoPage> {
  bool _useExtendedFab = true;

  void _openAlertDialog() {
    showLiquidGlassDialog(
      context: context,
      builder: (context) => LiquidGlassAlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C5CFF), size: 36),
        title: const Text('Liquid Glass Dialog'),
        content: const Text(
          'This alert dialog is rendered using a refractive LiquidGlassLens floating over the vibrant background.',
        ),
        actions: [
          LiquidGlassButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          LiquidGlassButton(
            label: 'Confirm',
            style: LiquidGlassButton.defaultStyle.copyWith(
              appearance: const LiquidGlassAppearance(color: Color(0x607C5CFF)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action Confirmed!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openCustomDialog() {
    showLiquidGlassDialog(
      context: context,
      builder: (context) => LiquidGlassDialog(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_moon_rounded, size: 48, color: Color(0xFF5BC0FF)),
            const SizedBox(height: 12),
            const Text(
              'Custom Glass Modal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Compose any arbitrary Flutter widgets inside LiquidGlassDialog for custom glass popups.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            LiquidGlassButton(
              label: 'Close Modal',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  static const List<_CardData> _cards = [
    _CardData(
      title: 'Neon Aurora Glow',
      subtitle: 'Vibrant indigo & violet backdrop layers',
      icon: Icons.palette_rounded,
      gradient: [Color(0xFF7C5CFF), Color(0xFF4527A0)],
    ),
    _CardData(
      title: 'Emerald Prism',
      subtitle: 'Refracting deep teal & emerald light',
      icon: Icons.diamond_rounded,
      gradient: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
    ),
    _CardData(
      title: 'Sunset Crimson',
      subtitle: 'Warm rose & coral chromatic dispersion',
      icon: Icons.wb_sunny_rounded,
      gradient: [Color(0xFFFF5C8A), Color(0xFF9D174D)],
    ),
    _CardData(
      title: 'Electric Amber',
      subtitle: 'High contrast optical edge highlighting',
      icon: Icons.bolt_rounded,
      gradient: [Color(0xFFFFB020), Color(0xFFB45309)],
    ),
    _CardData(
      title: 'Oceanic Sapphire',
      subtitle: 'Deep azure refraction with caustics',
      icon: Icons.water_drop_rounded,
      gradient: [Color(0xFF4FB3FF), Color(0xFF1D4ED8)],
    ),
    _CardData(
      title: 'Cosmic Nebula',
      subtitle: 'Multi-layer metaball glass blending',
      icon: Icons.auto_awesome_rounded,
      gradient: [Color(0xFFC084FC), Color(0xFF6B21A8)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      appBar: LiquidGlassAppBar(
        title: const Text('FAB & Dialog Showcase'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Deep background gradient base
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0A12), Color(0xFF16112C), Color(0xFF2B1446)],
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x507C5CFF),
              ),
            ),
          ),
          Positioned(
            top: 300,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x50FF5C8A),
              ),
            ),
          ),
          // Scrollable content feed
          ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 160, 20, 140),
              children: [
                const Text(
                  'Scrollable Glass Feed',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scroll the content up and down. The floating FAB and dialog refract the colorful cards moving underneath in real time.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(180),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),

                // Control action bar
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    LiquidGlassButton(
                      label: _useExtendedFab ? 'Icon FAB' : 'Extended FAB',
                      icon: Icons.swap_horiz_rounded,
                      onPressed: () => setState(() => _useExtendedFab = !_useExtendedFab),
                    ),
                    LiquidGlassButton(
                      label: 'Alert Dialog',
                      icon: Icons.add_alert_rounded,
                      style: LiquidGlassButton.defaultStyle.copyWith(
                        appearance: const LiquidGlassAppearance(color: Color(0x407C5CFF)),
                      ),
                      onPressed: _openAlertDialog,
                    ),
                    LiquidGlassButton(
                      label: 'Custom Dialog',
                      icon: Icons.widgets_rounded,
                      style: LiquidGlassButton.defaultStyle.copyWith(
                        appearance: const LiquidGlassAppearance(color: Color(0x405BC0FF)),
                      ),
                      onPressed: _openCustomDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Vibrant scrollable cards
                for (final card in _cards) ...[
                  _VibrantCard(data: card),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _useExtendedFab
          ? LiquidGlassFab.extended(
              icon: Icons.add_rounded,
              label: const Text('New Action'),
              onPressed: _openAlertDialog,
            )
          : LiquidGlassFab(
              icon: Icons.add_rounded,
              onPressed: _openAlertDialog,
            ),
    );
  }
}

class _CardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  const _CardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _VibrantCard extends StatelessWidget {
  final _CardData data;

  const _VibrantCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.gradient.first.withAlpha(220),
            data.gradient.last.withAlpha(180),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: data.gradient.first.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withAlpha(40), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(data.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
        ],
      ),
    );
  }
}
