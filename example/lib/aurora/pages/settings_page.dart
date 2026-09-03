import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../common.dart';
import '../theme.dart';

// =============================================================
// Settings — switches, chips and a sheet.
//
// `showLiquidGlassSheet` is Flutter's own `showModalBottomSheet` with
// the glass where its filled Material used to be, so the sheet down
// there drags, dismisses and stacks exactly like a framework one; only
// the surface changed.
//
// Each `LiquidGlassSwitch` runs its own capture pipeline, which is why
// there are two of them here and the rest of the choices are chips.
// =============================================================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _accent = Color(0xFFA9B8FF);

  bool _gapless = true;
  bool _crossfade = false;
  int _quality = 1;
  int _theme = 0;

  Future<void> _storageSheet() {
    return showLiquidGlassSheet<void>(
      context: context,
      style: auroraGlass(radius: 34, tint: const Color(0x24FFFFFF), blur: 10),
      foregroundColor: const Color(0xFFF4F3F8),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      // The sheet's own context is only good until it pops, so the
      // toast that follows is raised from the page's.
      builder: (BuildContext sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('STORAGE', style: kEyebrow.copyWith(color: _accent)),
          const SizedBox(height: 12),
          Text('412 MB on this device', style: kDisplay.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            'Downloads keep for 30 days after your last play, then clear '
            'themselves.',
            style: kBody,
          ),
          const SizedBox(height: 20),
          const _Bar(label: 'Music', value: 0.72, color: _accent),
          const SizedBox(height: 10),
          _Bar(
              label: 'Artwork',
              value: 0.17,
              color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          _Bar(
              label: 'Other',
              value: 0.06,
              color: Colors.white.withValues(alpha: 0.28)),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: LiquidGlassButton(
                  label: 'Keep',
                  height: 46,
                  foregroundColor: Colors.white,
                  style: auroraGlass(radius: 23, blur: 4),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiquidGlassButton(
                  label: 'Clear all',
                  height: 46,
                  foregroundColor: Colors.white,
                  style: auroraGlass(
                    radius: 23,
                    tint: const Color(0x52FF4D6D),
                    blur: 4,
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    showAuroraToast(context, 'Downloads cleared');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: const AuroraBackdrop(
          palette: AuroraPalette.slate, seed: 'settings-room'),
      lenses: <Widget>[
        AuroraList(
          bottom: 60,
          children: <Widget>[
            const SizedBox(height: 6),
            Text('Everything about how it sounds.', style: kEyebrow),
            const SizedBox(height: 10),
            Text('Settings', style: kDisplay.copyWith(fontSize: 34)),
            const SizedBox(height: 26),
            const SectionHeader('Playback', accent: _accent),
            FrostPanel(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
              child: Column(
                children: <Widget>[
                  _SwitchRow(
                    label: 'Gapless playback',
                    detail: 'No pause between tracks on an album',
                    value: _gapless,
                    accent: _accent,
                    onChanged: (bool v) => setState(() => _gapless = v),
                  ),
                  Divider(
                      height: 1, color: Colors.white.withValues(alpha: 0.07)),
                  _SwitchRow(
                    label: 'Crossfade',
                    detail: 'Overlap the last five seconds',
                    value: _crossfade,
                    accent: _accent,
                    onChanged: (bool v) => setState(() => _crossfade = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SectionHeader('Audio quality', accent: _accent),
            GlassPanel(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: <Widget>[
                      for (int i = 0; i < 3; i++)
                        AuroraChip(
                          label: const <String>[
                            'Normal',
                            'High',
                            'Lossless'
                          ][i],
                          accent: _accent,
                          selected: _quality == i,
                          onTap: () => setState(() => _quality = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    const <String>[
                      '128 kbps · about 60 MB an hour.',
                      '320 kbps · about 150 MB an hour.',
                      '24-bit · about 1 GB an hour, and worth it after dark.',
                    ][_quality],
                    style: kBody,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SectionHeader('Appearance', accent: _accent),
            FrostPanel(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    AuroraChip(
                      label: const <String>['Night', 'Dim', 'Auto'][i],
                      accent: _accent,
                      icon: const <IconData>[
                        Icons.nightlight_round,
                        Icons.contrast_rounded,
                        Icons.brightness_auto_rounded,
                      ][i],
                      selected: _theme == i,
                      onTap: () => setState(() => _theme = i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const SectionHeader('Storage', accent: _accent),
            FrostPanel(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              onTap: _storageSheet,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.sd_storage_rounded,
                      size: 19, color: Color(0xB3EDECF5)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Downloads', style: kTitle.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('412 MB · 6 albums',
                            style: kBody.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Text('Manage',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accent)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: Colors.white.withValues(alpha: 0.3)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Text('Aurora 4.2 · built on liquid_glass_easy',
                  style: kBody.copyWith(
                      fontSize: 11.5, color: const Color(0x66EDECF5))),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: pad.top + 66,
          child: const IgnorePointer(
            child: LiquidGlassScrollEdge(
              edge: LiquidGlassEdge.top,
              blur: 6,
              color: Color(0x9E07080B),
            ),
          ),
        ),
      ],
      appBar: LiquidGlassAppBar(
        width: (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 520.0),
        height: 52,
        centerTitle: true,
        style: auroraChrome(radius: 26),
        foregroundColor: const Color(0xFFF4F3F8),
        leading: Pressable(
          onTap: () => Navigator.of(context).maybePop(),
          scale: 0.88,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
          ),
        ),
        title: Text('SETTINGS', style: kEyebrow.copyWith(fontSize: 10)),
      ),
    );
  }
}

/// A row whose control is a real [LiquidGlassSwitch] — the glass thumb
/// morphs out of the solid rest pill as it travels.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(detail, style: kBody.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          LiquidGlassSwitch(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// One labelled proportion in the storage sheet.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 66,
          child: Text(label, style: kBody.copyWith(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('${(value * 412).round()} MB',
            style: kBody.copyWith(fontSize: 11.5)),
      ],
    );
  }
}
