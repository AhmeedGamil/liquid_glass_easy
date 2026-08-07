import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Settings — two wide glass buttons fused into one surface
//
//   flutter run -t lib/settings_glass_page.dart   (standalone)
//   …or open it from the gallery.
//
// A settings screen over a radial gradient. Each row is a full-width
// LiquidGlassButton — tappable, with a subtle flex so the glass answers the
// finger. A LiquidGlassButton is a LiquidGlassLens underneath, so the
// LiquidGlassBlender wrapping them picks both up as members: at smoothness
// 20 the 12px gutter between them closes and the pair reads as one liquid
// surface with a single shared rim. Widen the margins and the bridge snaps.
//
// While blended, each button keeps its own SHAPE (that is its blob) but the
// material comes from the group's style — so the milky tint and the 8px
// blur are set once, on the blender.
//
// The whole thing sits in a LiquidGlassView, so the gradient behind it is
// captured and refracted on Skia and Web too, not just Impeller.
// =============================================================

void main() {
  runApp(const _SettingsGlassApp());
}

class _SettingsGlassApp extends StatelessWidget {
  const _SettingsGlassApp();

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
      home: const SettingsGlassPage(),
    );
  }
}

/// A settings page whose cards are blended glass.
class SettingsGlassPage extends StatefulWidget {
  const SettingsGlassPage({super.key});

  @override
  State<SettingsGlassPage> createState() => _SettingsGlassPageState();
}

class _SettingsGlassPageState extends State<SettingsGlassPage> {
  /// Which button was last pressed — the page has to answer the tap with
  /// something, so it answers with this.
  String? _tapped;

  /// Shown at the bottom, the way an app stamps its build. Hard-coded here;
  /// a real app would read it from `package_info_plus`.
  static const String _version = '3.5.0';

  /// The merged material. No shape corner radius is set here — each button
  /// brings its own; what the group's shape contributes is the RIM that the
  /// fused silhouette is drawn with.
  static const _cardsStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      borderWidth: 1.2,
      lightDirection: 39,
    ),
    appearance: LiquidGlassAppearance(
      blur: LiquidGlassBlur(sigmaX: 8, sigmaY: 8),
      // withAlpha(100) — a milky white, thick enough to read as frosted.
      color: Color(0x64FFFFFF),
    ),
  );

  void _tap(String name) => setState(() => _tapped = name);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomLeft,
              radius: 1.34,
              colors: [
                scheme.primary,
                scheme.primary,
                Theme.of(context).cardColor,
              ],
              // The flat field is the point: the cards carry the look, the
              // background only lights them.
              stops: const [0.0, 0.9999, 1.0],
            ),
          ),
        ),
        child: LiquidGlassBlender(
          smoothness: 20,
          style: _cardsStyle,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'v$_version',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                      _WideGlassButton(
                        margin: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                        icon: Icons.person_rounded,
                        tint: const Color(0xFF0A84FF),
                        label: 'Account',
                        value: 'Signed in',
                        onPressed: () => _tap('Account'),
                      ),
                      _WideGlassButton(
                        margin: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                        icon: Icons.palette_rounded,
                        tint: const Color(0xFF5E5CE6),
                        label: 'Appearance',
                        value: 'Dark',
                        onPressed: () => _tap('Appearance'),
                      ),
                      SizedBox(
                        height: 26,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _tapped == null ? 0 : 1,
                            duration: const Duration(milliseconds: 160),
                            child: Text(
                              '${_tapped ?? ''} tapped',
                              style: TextStyle(
                                color: scheme.onPrimary.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The content sitting on the frosted buttons. Their material is a fixed
/// milky white whatever the theme is, so the ink on it is fixed too.
const Color _ink = Color(0xFF16161C);
const Color _inkFaint = Color(0x8C16161C);

/// The rounded tile every row leads with.
class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color tint;

  const _RowIcon({required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

/// One settings entry: a full-width [LiquidGlassButton].
///
/// A button is a lens, so inside the [LiquidGlassBlender] this registers as
/// a member and stops painting its own glass — its shape is its blob, and
/// the group's style paints the merged result. That is also why the shape is
/// set here and the tint is not: drop the [LiquidGlassStyle] entirely and
/// the button falls back to its own default pill, `height / 2`.
///
/// `foregroundColor` is the ink for bare `Icon`/`Text` inside [child]: the
/// merged surface is a milky white, so it has to be dark. Anything carrying
/// its own color (the tinted icon tile) keeps it.
class _WideGlassButton extends StatelessWidget {
  final EdgeInsets margin;
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final VoidCallback onPressed;

  const _WideGlassButton({
    required this.margin,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: LiquidGlassButton.custom(
        width: 320,
        height: 68,
        onPressed: onPressed,
        foregroundColor: _ink,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        style: LiquidGlassButton.defaultStyle.copyWith(
          shape: const LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: 28,
          ),
        ),
        // Barely-there: the tuned default flex is sized for a small pill and
        // would wobble a 320-wide surface like rubber.
        touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
        child: Row(
          children: [
            _RowIcon(icon: icon, tint: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: _inkFaint,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: _inkFaint),
          ],
        ),
      ),
    );
  }
}
