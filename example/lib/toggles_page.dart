import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tuner_widgets.dart';

// =============================================================
// Toggles-only showcase — a page of LiquidGlassSwitch switches.
//
//   flutter run -t lib/toggles_page.dart   (standalone)
//   …or push TogglesPage() from your menu.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _TogglesApp());
}

class _TogglesApp extends StatelessWidget {
  const _TogglesApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const TogglesPage(),
    );
  }
}

/// A showcase page of glass toggles only.
class TogglesPage extends StatefulWidget {
  const TogglesPage({super.key});

  @override
  State<TogglesPage> createState() => _TogglesPageState();
}

class _TogglesPageState extends State<TogglesPage> {
  bool _wifi = true;
  bool _bluetooth = false;
  bool _airplane = false;
  bool _silent = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toggles'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: TunerGradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TunerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TunerPanelTitle('Toggles'),
                    const SizedBox(height: 6),
                    _ToggleRow(Icons.wifi_rounded, 'Wi-Fi', _wifi,
                        (v) => setState(() => _wifi = v)),
                    _ToggleRow(Icons.bluetooth_rounded, 'Bluetooth', _bluetooth,
                        (v) => setState(() => _bluetooth = v)),
                    _ToggleRow(Icons.airplanemode_active_rounded, 'Airplane mode',
                        _airplane, (v) => setState(() => _airplane = v)),
                    _ToggleRow(Icons.nightlight_round, 'Silent mode', _silent,
                        (v) => setState(() => _silent = v),
                        activeColor: kTunerAccent),
                    _ToggleRow(Icons.dark_mode_rounded, 'Dark mode', _darkMode,
                        (v) => setState(() => _darkMode = v)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Flip the switches',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _ToggleRow(this.icon, this.label, this.value, this.onChanged,
      {this.activeColor = const Color(0xFF34C759)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 14.5, color: Colors.white)),
          const Spacer(),
          LiquidGlassSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }
}
