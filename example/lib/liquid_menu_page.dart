import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Liquid action menu — a REAL UI use of the blend.
//
// A glass FAB sits over a wallpaper. Tap it and three action buttons grow
// straight out of it, staying liquid-connected by the metaball bridge as they
// emerge — then settle into separate buttons. Tap again (or the scrim) and they
// flow back in and merge into the single button. One LiquidGlassBlender fuses
// the main button + three actions (4 lenses, one shader pass).
//
//   flutter run -t lib/liquid_menu_page.dart   (standalone)
//   …or open it from the gallery.
// =============================================================

void main() {
  runApp(const _LiquidMenuApp());
}

class _LiquidMenuApp extends StatelessWidget {
  const _LiquidMenuApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LiquidMenuPage(),
    );
  }
}

/// One action in the expanding menu.
class _MenuAction {
  final IconData icon;
  final String label;
  final Color tint;
  const _MenuAction(this.icon, this.label, this.tint);
}

class LiquidMenuPage extends StatefulWidget {
  const LiquidMenuPage({super.key});

  @override
  State<LiquidMenuPage> createState() => _LiquidMenuPageState();
}

class _LiquidMenuPageState extends State<LiquidMenuPage>
    with SingleTickerProviderStateMixin {
  // A busy, colourful wallpaper so the glass has rich detail to refract.
  static const String _wallpaper =
      'https://images.unsplash.com/photo-1502790671504-542ad42d5189'
      '?auto=format&fit=crop&w=900&h=1600&q=80';

  static const List<_MenuAction> _actions = [
    _MenuAction(Icons.edit_rounded, 'Note', Color(0xFF5BC0FF)),
    _MenuAction(Icons.photo_rounded, 'Photo', Color(0xFF7C5CFF)),
    _MenuAction(Icons.mic_rounded, 'Voice', Color(0xFFFF5C8A)),
    _MenuAction(Icons.location_on_rounded, 'Place', Color(0xFF34D399)),
    _MenuAction(Icons.tag_rounded, 'Tag', Color(0xFFFFB020)),
  ];

  // The merged glass material: lightly frosted + tinted so the cluster reads as
  // one control over the busy wallpaper, with an optical rim and refraction.
  static const _groupStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(
      cornerRadius: 40,
      borderWidth: 1.5,
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x1FFFFFFF),
      saturation: 1.06,
      blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
    ),
    refraction: LiquidGlassRefraction(
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 22,
        depth: 0.4,
      ),
    ),
  );

  static const double _mainSize = 72;
  static const double _actionSize = 56;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack, // slight overshoot → liquid "pop"
    reverseCurve: Curves.easeInCubic,
  );

  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _controller.forward() : _controller.reverse();
  }

  void _onAction(_MenuAction action) {
    _toggle();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
        content: Text('${action.label} tapped'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Liquid menu'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Wallpaper(url: _wallpaper),
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final Size size = MediaQuery.sizeOf(context);
            final double t = _t.value.clamp(0.0, 1.0);

            // Main button in the centre; actions fan out around it on a circle.
            final Offset mainCenter = Offset(size.width / 2, size.height / 2);
            final double radius =
                (size.shortestSide * 0.34).clamp(104.0, 160.0);

            // A point for action [i] at distance [r] from the centre, lerped
            // from the centre by the (raw, unclamped) animation value so
            // easeOutBack's overshoot springs the blobs past open — the
            // metaball bridge stretches and snaps. First action starts at top.
            Offset radialPoint(int i, double r) {
              final double angle =
                  -math.pi / 2 + i * (2 * math.pi / _actions.length);
              final Offset open =
                  mainCenter + Offset(math.cos(angle), math.sin(angle)) * r;
              return Offset.lerp(mainCenter, open, _t.value)!;
            }

            Offset actionCenter(int i) => radialPoint(i, radius);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Tap-anywhere scrim to dismiss while open. ALWAYS in the tree
                // (just inert + transparent when closed) so the child list
                // length never changes — a conditional child here would shift
                // every sibling's index and REMOUNT the blender below, which
                // reloads its shader and flashes the glass for a frame.
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: t < 0.01,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggle,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // Action labels: a pill just outside each blob, centred on the
                // radial line so they ring the menu.
                for (int i = 0; i < _actions.length; i++)
                  Positioned(
                    left: radialPoint(i, radius + _actionSize / 2 + 18).dx,
                    top: radialPoint(i, radius + _actionSize / 2 + 18).dy,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: IgnorePointer(
                        ignoring: t < 0.6,
                        child: Opacity(
                          opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                          child: _LabelPill(_actions[i].label),
                        ),
                      ),
                    ),
                  ),

                // The merged glass cluster: main + 3 actions in one blender.
                Positioned.fill(
                  child: LiquidGlassBlender(
                    key: const ValueKey('liquid-menu-blender'),
                    smoothness: 46,
                    style: _groupStyle,
                    debugClipBounds: false,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (int i = 0; i < _actions.length; i++)
                          _lens(
                            center: actionCenter(i),
                            size: _actionSize,
                            cornerRadius: _actionSize / 2,
                            onTap: () => _onAction(_actions[i]),
                            child: Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Icon(_actions[i].icon,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        _lens(
                          center: mainCenter,
                          size: _mainSize,
                          cornerRadius: _mainSize / 2,
                          onTap: _toggle,
                          child: Transform.rotate(
                            angle: t * 0.785398, // + → ×  (45°)
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 34),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // A little hint at the top.
                const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: IgnorePointer(
                    child: Text(
                      'Tap the button — the actions flow out of the glass',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A single blender member: a glass lens positioned by its [center].
  Widget _lens({
    required Offset center,
    required double size,
    required double cornerRadius,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LiquidGlassLens(
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: cornerRadius,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// A frosted label chip shown beside an open action.
class _LabelPill extends StatelessWidget {
  final String text;
  const _LabelPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The refractable wallpaper captured by [LiquidGlassView].
class _Wallpaper extends StatelessWidget {
  final String url;
  const _Wallpaper({required this.url});

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF134E5E), Color(0xFF71B280), Color(0xFFF59E0B)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Stack(
              fit: StackFit.expand,
              children: [
                _fallback,
                Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0x55000000)],
            ),
          ),
        ),
      ],
    );
  }
}
