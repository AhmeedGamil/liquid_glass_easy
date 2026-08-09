import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/experimental/liquid_glass_switch_experimental.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Experimental Switch showcase — LiquidGlassSwitchExperimental, the
// sliding-thumb switch, standalone so nothing in the gallery changes.
//
//   flutter run -t lib/experimental_switch_page.dart
//
// What to try, in the order the behaviour gets interesting:
//   • Tap one. It toggles at once and the thumb glides across.
//   • Press and DRAG the thumb. It rides your finger 1:1, and past a
//     resting position it rubber-bands by sqrt(overrun).
//   • Drag toward the far side and stop 5 px short. It flips early,
//     under your held finger, and the track colour cross-fades there.
//     Drag back and it flips again.
//   • Press, hold a moment without moving, release. It still toggles.
//   • The bottom row is driven from code — a programmatic change glides
//     the thumb without ever expanding it.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ExperimentalSwitchApp());
}

class _ExperimentalSwitchApp extends StatelessWidget {
  const _ExperimentalSwitchApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const ExperimentalSwitchPage(),
    );
  }
}

class ExperimentalSwitchPage extends StatefulWidget {
  const ExperimentalSwitchPage({super.key});

  @override
  State<ExperimentalSwitchPage> createState() => _ExperimentalSwitchPageState();
}

class _ExperimentalSwitchPageState extends State<ExperimentalSwitchPage> {
  bool _wifi = true;
  bool _bluetooth = false;
  bool _airdrop = true;
  bool _hotspot = false;

  /// The row nothing touches directly — flipped from the button below,
  /// so the calm programmatic path can be seen on its own.
  bool _remote = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A photo behind the glass: the thumb has to have something
          // worth refracting, or the effect reads as a grey pill.
          Image.asset('assets/background.jpeg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x59000000)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              children: [
                const Text(
                  'Sliding switch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Drag the thumb, do not just tap it.',
                  style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
                ),
                const SizedBox(height: 26),
                _card([
                  _row(Icons.wifi_rounded, 'Wi-Fi', _wifi,
                      (v) => setState(() => _wifi = v)),
                  _divider(),
                  _row(Icons.bluetooth_rounded, 'Bluetooth', _bluetooth,
                      (v) => setState(() => _bluetooth = v)),
                  _divider(),
                  _row(Icons.share_rounded, 'AirDrop', _airdrop,
                      (v) => setState(() => _airdrop = v)),
                  _divider(),
                  _row(Icons.wifi_tethering_rounded, 'Hotspot', _hotspot,
                      (v) => setState(() => _hotspot = v)),
                ]),
                const SizedBox(height: 26),

                // ── the tinted variants ───────────────────────────────
                const _SectionLabel('Track colours'),
                const SizedBox(height: 12),
                _card([
                  _row(Icons.dark_mode_rounded, 'Indigo', _bluetooth,
                      (v) => setState(() => _bluetooth = v),
                      activeTrackColor: const Color(0xFF5E5CE6)),
                  _divider(),
                  _row(Icons.local_fire_department_rounded, 'Orange', _hotspot,
                      (v) => setState(() => _hotspot = v),
                      activeTrackColor: const Color(0xFFFF9F0A)),
                  _divider(),
                  _row(Icons.favorite_rounded, 'Pink', _airdrop,
                      (v) => setState(() => _airdrop = v),
                      activeTrackColor: const Color(0xFFFF375F)),
                ]),
                const SizedBox(height: 26),

                // ── the programmatic path ─────────────────────────────
                const _SectionLabel('Changed from code'),
                const SizedBox(height: 12),
                _card([
                  _row(Icons.settings_remote_rounded, 'Remote', _remote,
                      (v) => setState(() => _remote = v)),
                ]),
                const SizedBox(height: 14),
                Center(
                  child: FilledButton.tonal(
                    onPressed: () => setState(() => _remote = !_remote),
                    child: Text(_remote ? 'Turn it off' : 'Turn it on'),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'The thumb glides across without expanding —\n'
                    'no touch, so nothing is lifted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0x8CFFFFFF), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.08),
      );

  Widget _row(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    Color? activeTrackColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 21, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          LiquidGlassSwitchExperimental(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeTrackColor ?? const Color(0xFF34C759),
            // Arrives with the glass: the solid rest pill casts nothing,
            // and the shadow fades up as the thumb is lifted. Inset so the
            // glass overhangs its own shadow — at this size a full-width
            // halo reads as a glow rather than contact.
            shadow: const LiquidGlassShadow(inset: 3),
            // No blur on the moving glass thumb — the refraction reads
            // sharper over a photo.
            style: const LiquidGlassStyle(
              appearance: LiquidGlassAppearance(
                color: Color(0x1CFFFFFF),
                blur: LiquidGlassBlur(sigmaX: 0.5, sigmaY: 0.5),
              ),
              refraction: LiquidGlassRefraction(
                distortion: 0.12,
                distortionWidth: 14,
                chromaticAberration: 0.002,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0x8CFFFFFF),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}
