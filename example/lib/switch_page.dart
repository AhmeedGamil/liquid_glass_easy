import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Switch showcase — LiquidGlassSwitch, the sliding-thumb switch,
// standalone so nothing in the gallery changes.
//
//   flutter run -t lib/switch_page.dart
//
// The same glass thumb carried along a track instead of between two
// rest positions — see `slider_page.dart`.
//
// What to try, in the order the behaviour gets interesting:
//   • Tap one. It toggles at once and the thumb glides across.
//   • Press and DRAG the thumb. It rides your finger 1:1, and past a
//     resting position it rubber-bands by sqrt(overrun).
//   • Drag toward the far side and stop 5 px short. It flips early,
//     under your held finger, and the track colour cross-fades there.
//     Drag back and it flips again.
//   • Press, hold a moment without moving, release. It still toggles.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SwitchApp());
}

class _SwitchApp extends StatelessWidget {
  const _SwitchApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const SwitchPage(),
    );
  }
}

class SwitchPage extends StatefulWidget {
  const SwitchPage({super.key});

  @override
  State<SwitchPage> createState() => _SwitchPageState();
}

class _SwitchPageState extends State<SwitchPage> {
  bool _wifi = true;
  bool _bluetooth = false;
  bool _airdrop = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A flat off-white behind the glass — dimmed rather than pure
          // white, so the thumb's rim and shadow still have something to
          // sit against.
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFE9E9EC)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
              children: [
                const Text(
                  'Sliding switch',
                  style: TextStyle(
                    color: Color(0xFF11131A),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Drag the thumb, do not just tap it.',
                  style: TextStyle(color: Color(0x9911131A), fontSize: 14),
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
                ]),
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
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
        color: Colors.black.withValues(alpha: 0.07),
      );

  Widget _row(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    Color? activeTrackColor,
    LiquidGlassSwitchLayout layout = const LiquidGlassSwitchLayout(),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 21, color: Colors.black.withValues(alpha: 0.75)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF11131A),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Everything but the track colour is the shipped default now:
          // the clear unblurred thumb, its inset contact shadow and the
          // pinched slice behind the glass all come from
          // LiquidGlassSwitch.defaultStyle / LiquidGlassSwitchLayout.
          LiquidGlassSwitch(
            value: value,
            onChanged: onChanged,
            layout: layout,
            activeColor: activeTrackColor ?? const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }
}
