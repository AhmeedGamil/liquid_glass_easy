import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Alert Dialog — LiquidGlassAlertDialog through showLiquidGlassDialog.
//
//   flutter run -t lib/dialog_page.dart
//
// The page is a LiquidGlassScaffold, and that is the important part: a
// dialog opened from a context inside one joins the scaffold's capture.
// Every glass here — the panels, their actions, the openers — is LITE
// glass with the `surface` rim: `liteGlass: LiquidGlassLitePickup.surface` on the style, no shader
// and no refraction, the rim blended over the tint and the content. Three
// dialogs: a plain confirm, a destructive one with a tinted action, and a
// long one that scrolls. Each pops with a value, printed on the page.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DialogApp());
}

class _DialogApp extends StatelessWidget {
  const _DialogApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DialogPage(),
    );
  }
}

class DialogPage extends StatefulWidget {
  const DialogPage({super.key});

  @override
  State<DialogPage> createState() => _DialogPageState();
}

class _DialogPageState extends State<DialogPage> {
  String _result = 'No answer yet';
  bool _dismissible = true;

  /// Every surface on the page is lite glass with the `surface` rim.
  static const LiquidGlassLitePickup _rim = LiquidGlassLitePickup.surface;

  /// The panels: the stock dialog glass, drawn lite.
  static final LiquidGlassStyle _panel = LiquidGlassDialog.defaultStyle
      .copyWith(liteGlass: _rim);

  /// The openers on the page: the stock button glass, drawn lite and with
  /// no frost — a surface-rim button reads best as a flat tinted plate.
  static final LiquidGlassStyle _button =
      LiquidGlassButton.defaultStyle.copyWith(
    liteGlass: _rim,
    appearance: LiquidGlassButton.defaultStyle.appearance
        .copyWith(blur: const LiquidGlassBlur()),
  );

  /// The dialog actions: the same button with a blue tint and no blur —
  /// `copyWith(appearance:)` replaces the whole appearance, so the
  /// default's blur goes with it.
  static final LiquidGlassStyle _accent = _button.copyWith(
    appearance: const LiquidGlassAppearance(color: Color(0x660A84FF)),
  );

  /// The destructive action: same glass, red instead of blue.
  static final LiquidGlassStyle _danger = _button.copyWith(
    appearance: const LiquidGlassAppearance(color: Color(0x80EF4444)),
  );

  Future<void> _open(
    BuildContext context,
    String name,
    WidgetBuilder builder,
  ) async {
    final String? answer = await showLiquidGlassDialog<String>(
      context: context,
      barrierDismissible: _dismissible,
      builder: builder,
    );
    if (!mounted) return;
    setState(() => _result = '$name  →  ${answer ?? 'dismissed'}');
  }

  void _confirm(BuildContext context) => _open(
        context,
        'Confirm',
        (BuildContext context) => LiquidGlassAlertDialog(
          style: _panel,
          icon: const Icon(Icons.auto_awesome_rounded),
          title: const Text('Enable sync?'),
          content: const Text(
            'Your library will be kept in step across devices.',
          ),
          actions: <Widget>[
            LiquidGlassButton(
              label: 'Not now',
              style: _accent,
              onPressed: () => Navigator.of(context).pop('not now'),
            ),
            LiquidGlassButton(
              label: 'Enable',
              style: _accent,
              onPressed: () => Navigator.of(context).pop('enabled'),
            ),
          ],
        ),
      );

  void _destructive(BuildContext context) => _open(
        context,
        'Delete',
        (BuildContext context) => LiquidGlassAlertDialog(
          style: _panel,
          icon: const Icon(Icons.delete_outline_rounded),
          iconColor: const Color(0xFFFCA5A5),
          title: const Text('Delete 12 photos?'),
          content: const Text('They go to Recently Deleted for 30 days.'),
          actions: <Widget>[
            LiquidGlassButton(
              label: 'Cancel',
              style: _accent,
              onPressed: () => Navigator.of(context).pop('cancel'),
            ),
            LiquidGlassButton(
              label: 'Delete',
              // Same glass as the blue ones, red instead.
              style: _danger,
              onPressed: () => Navigator.of(context).pop('deleted'),
            ),
          ],
        ),
      );

  void _long(BuildContext context) => _open(
        context,
        'Terms',
        (BuildContext context) => LiquidGlassAlertDialog(
          style: _panel,
          title: const Text('Terms'),
          // Long content scrolls inside the panel instead of growing it
          // past the screen.
          scrollable: true,
          content: Text(
            List<String>.generate(
              14,
              (int i) => 'Clause ${i + 1}. The glass panel keeps its '
                  'height and lets this text scroll under the title.',
            ).join('\n\n'),
          ),
          actions: <Widget>[
            LiquidGlassButton(
              label: 'Agree',
              style: _accent,
              onPressed: () => Navigator.of(context).pop('agreed'),
            ),
          ],
        ),
      );

  Widget _opener(
    BuildContext context,
    IconData icon,
    String label,
    String detail,
    void Function(BuildContext) open,
  ) {
    return LiquidGlassButton(
      height: 62,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      style: _button,
      onPressed: () => open(context),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          const Icon(Icons.open_in_full_rounded, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      batch: true,
      appBar: const DemoHeader(title: 'Alert Dialog'),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DemoPhoto('rain.jpg', seed: 2),
          // A Builder so the dialogs open from a context under the
          // scaffold — that is what hands them its capture.
          Builder(
            builder: (BuildContext context) => ScrollConfiguration(
              // Stretch overscroll OFF for this list, to compare.
              behavior:
                  const MaterialScrollBehavior().copyWith(overscroll: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 200),
                children: <Widget>[
                  Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _opener(context, Icons.help_outline_rounded, 'Confirm',
                      'Two actions, each popping a value', _confirm),
                  const SizedBox(height: 10),
                  _opener(context, Icons.delete_outline_rounded, 'Destructive',
                      'A tinted action on the same style', _destructive),
                  const SizedBox(height: 10),
                  _opener(context, Icons.article_outlined, 'Long, scrollable',
                      'Content scrolls inside the panel', _long),
                ],
              ),
            ),
          ),
          DemoPanel(
            title: 'showLiquidGlassDialog',
            children: <Widget>[
              DemoChips<bool>(
                values: const <bool>[true, false],
                selected: _dismissible,
                label: (bool v) => v ? 'barrier dismisses' : 'barrier locked',
                onChanged: (bool v) => setState(() => _dismissible = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
