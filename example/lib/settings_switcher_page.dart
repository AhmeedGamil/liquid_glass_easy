import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Settings switches — a titled list row that ends in a glass switch
//
//   flutter run -t lib/settings_switcher_page.dart   (standalone)
//   …or open it from the gallery.
//
// The row is a plain Material ListTile: title, description, and a
// LiquidGlassToggle as the trailing widget. Nothing here is glass except
// the switch, which is the point — a LiquidGlassToggle carries its own
// LiquidGlassView, so it refracts whatever it happens to be sitting on
// without the page arranging anything for it.
//
// The one thing the page does owe it is room. The swollen handle paints
// OUTSIDE the 63x28 track, so the group cards below are drawn with a
// decoration rather than a ClipRRect — a clipping ancestor would shear
// the swell off at the track's edge. Where clipping is unavoidable, the
// switch takes `reserveSwellRoom: true` instead and measures large
// enough to hold it.
// =============================================================

void main() {
  runApp(const _SettingsSwitcherApp());
}

class _SettingsSwitcherApp extends StatelessWidget {
  const _SettingsSwitcherApp();

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
      home: const SettingsSwitcherPage(),
    );
  }
}

/// A settings page whose every row ends in a glass switch.
class SettingsSwitcherPage extends StatefulWidget {
  const SettingsSwitcherPage({super.key});

  @override
  State<SettingsSwitcherPage> createState() => _SettingsSwitcherPageState();
}

class _SettingsSwitcherPageState extends State<SettingsSwitcherPage> {
  bool _faceId = true;
  bool _analytics = false;
  bool _haptics = true;
  bool _autoDark = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0B0A12),
              scheme.primary.withValues(alpha: 0.35),
              const Color(0xFF241543),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                'Settings',
                style: context.theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 26),
              const _GroupLabel('Security'),
              _Group(
                children: [
                  SettingSwitcher(
                    context: context,
                    title: 'Face ID',
                    description: 'Unlock the app with your face',
                    value: _faceId,
                    onChanged: (v) => setState(() => _faceId = v),
                  ),
                  SettingSwitcher(
                    context: context,
                    title: 'Share analytics',
                    description: 'Send anonymous usage data to help us improve',
                    value: _analytics,
                    onChanged: (v) => setState(() => _analytics = v),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _GroupLabel('Appearance & feedback'),
              _Group(
                children: [
                  SettingSwitcher(
                    context: context,
                    title: 'Haptics',
                    description: 'Answer every toggle with a small tap',
                    value: _haptics,
                    onChanged: (v) => setState(() => _haptics = v),
                  ),
                  SettingSwitcher(
                    context: context,
                    title: 'Auto dark mode',
                    description: 'Follow the system theme after sunset',
                    value: _autoDark,
                    onChanged: (v) => setState(() => _autoDark = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Tap a switch, or drag its handle across',
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.45),
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

/// One settings entry: a title, a line of explanation, and a glass switch.
class SettingSwitcher extends StatelessWidget {
  const SettingSwitcher({
    super.key,
    required this.context,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final BuildContext context;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        title: Text(
          title,
          style: context.theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          description,
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: LiquidGlassToggle(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// `context.theme` — the shorthand [SettingSwitcher] is written against.
extension SettingsThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
}

/// The heading above a run of rows.
class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// A card holding a run of rows. Decorated, never clipped — the switch
/// handle swells past the track and a clip would cut it off.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(children: children),
    );
  }
}
