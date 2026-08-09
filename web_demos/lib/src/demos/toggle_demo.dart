import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Toggle** — the switch, and the three things you will change about it.
///
/// [LiquidGlassToggle] is self-contained like the slider: its own background,
/// its own refracted track, no [LiquidGlassView] and no capture. Colour is
/// `activeColor` / `inactiveColor`, geometry is [LiquidGlassToggleLayout], and
/// everything else is the glass vocabulary the rest of the package uses.
///
/// ## The handle is not a picture of glass
///
/// At rest the thumb is a solid pill. Press it and the solid dissolves as the
/// lens underneath comes up — frost falls away, refraction and the rim ramp in
/// together — so the glass arrives *as* a state change instead of sitting
/// there pretending. Hold one down and watch the track bend through it.
class ToggleDemo extends StatefulWidget {
  const ToggleDemo({super.key});

  @override
  State<ToggleDemo> createState() => _ToggleDemoState();
}

enum _Size {
  small('small', LiquidGlassToggleLayout(
    width: 50,
    height: 22,
    thumbWidth: 31,
    thumbHeight: 19,
  )),
  standard('default', LiquidGlassToggleLayout()),
  large('large', LiquidGlassToggleLayout(
    width: 84,
    height: 38,
    thumbWidth: 53,
    thumbHeight: 33,
  ));

  const _Size(this.label, this.layout);
  final String label;
  final LiquidGlassToggleLayout layout;
}

class _ToggleDemoState extends State<ToggleDemo> {
  _Size _size = _Size.standard;

  bool _wifi = true;
  bool _bluetooth = false;
  bool _airplane = false;
  bool _hotspot = true;

  /// Airplane mode owns the radios, so switching it on turns them off and
  /// locks them. A demo where nothing affects anything teaches nothing.
  void _setAirplane(bool v) => setState(() {
        _airplane = v;
        if (v) {
          _wifi = false;
          _bluetooth = false;
          _hotspot = false;
        }
      });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackdrop.ember(),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            children: [
              Text(
                _airplane ? 'AIRPLANE MODE' : 'CONNECTIONS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 18),

              _Card(children: [
                _ToggleRow(
                  icon: Icons.airplanemode_active_rounded,
                  label: 'Airplane mode',
                  note: _airplane ? 'Radios off' : 'Off',
                  value: _airplane,
                  layout: _size.layout,
                  activeColor: const Color(0xFFFFB020),
                  onChanged: _setAirplane,
                ),
              ]),
              const SizedBox(height: 14),

              _Card(children: [
                _ToggleRow(
                  icon: Icons.wifi_rounded,
                  label: 'Wi-Fi',
                  note: _wifi ? 'Sonder 5G' : 'Off',
                  value: _wifi,
                  layout: _size.layout,
                  enabled: !_airplane,
                  onChanged: (v) => setState(() => _wifi = v),
                ),
                _ToggleRow(
                  icon: Icons.bluetooth_rounded,
                  label: 'Bluetooth',
                  note: _bluetooth ? 'Two devices' : 'Off',
                  value: _bluetooth,
                  layout: _size.layout,
                  enabled: !_airplane,
                  activeColor: const Color(0xFF4FB3FF),
                  onChanged: (v) => setState(() => _bluetooth = v),
                ),
                _ToggleRow(
                  icon: Icons.wifi_tethering_rounded,
                  label: 'Hotspot',
                  note: _hotspot ? 'Discoverable' : 'Off',
                  value: _hotspot,
                  layout: _size.layout,
                  enabled: !_airplane && _wifi,
                  activeColor: const Color(0xFF7C5CFF),
                  onChanged: (v) => setState(() => _hotspot = v),
                ),
              ]),

              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in _Size.values)
                      DemoChip(
                        label: s.label,
                        selected: _size == s,
                        onTap: () => setState(() => _size = s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const DemoHint(
                'Press and hold a thumb: the solid pill dissolves into glass, '
                'and the track bends through it',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String note;
  final bool value;
  final bool enabled;
  final Color? activeColor;
  final LiquidGlassToggleLayout layout;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.note,
    required this.value,
    required this.layout,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.4,
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(note,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IgnorePointer(
              ignoring: !enabled,
              child: LiquidGlassToggle(
                value: value,
                onChanged: onChanged,
                layout: layout,
                activeColor: activeColor ?? const Color(0xFF34C759),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
