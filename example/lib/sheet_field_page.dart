import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Sheets — the glass surface you pull up.
//
// The page itself holds plain Material TextFields on glass lenses over a
// photo — a plain one, a password, and a multi-line one — so there is
// something to scroll and something to type into. The glass is just the
// decoration; the field is Flutter's own.
//
// Three buttons present LiquidGlassSheets, each a different shape of
// the same surface. The presenter is Flutter's own showModalBottomSheet
// with the glass where its Material used to be, so:
//   • the plain one hugs what is in it, the shape of an action sheet.
//   • the expandable one is a DraggableScrollableSheet with a bare
//     LiquidGlassSheet inside its builder — the glass has to be within
//     what resizes.
//   • the attached one is full width on the bottom edge, with a field
//     inside, so the sheet rides the keyboard up.
//
// Wrapped in LiquidGlassView so it works on BOTH backends.
//
//   flutter run -t lib/sheet_field_page.dart   (standalone)
//   …or open it from the gallery.
// =============================================================

void main() {
  runApp(const _SheetFieldApp());
}

class _SheetFieldApp extends StatelessWidget {
  const _SheetFieldApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SheetFieldPage(),
    );
  }
}

/// Text fields on glass, and glass sheets over them.
class SheetFieldPage extends StatefulWidget {
  const SheetFieldPage({super.key});

  @override
  State<SheetFieldPage> createState() => _SheetFieldPageState();
}

class _SheetFieldPageState extends State<SheetFieldPage> {
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  /// How many times the field trio repeats down the page.
  static const int _fieldGroups = 5;

  final TextEditingController _name = TextEditingController();
  String _lastResult = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sheets & fields'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _imageUrl),
        child: SafeArea(
          child: LiquidGlassBatch(
            enabled: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 84, 20, 40),
              itemCount: _fieldGroups + 2,
              itemBuilder: _buildRow,
            ),
          ),
        ),
      ),
    );
  }

  /// The list is three stretches laid end to end: the label, one row per
  /// group of fields, then the sheet buttons — so a row is built when it
  /// scrolls in rather than all of them up front.
  Widget _buildRow(BuildContext context, int index) {
    if (index == 0) return const _Label('Fields');
    // Only the first name field is driven from the page's controller.
    if (index <= _fieldGroups) {
      return _FieldGroup(controller: index == 1 ? _name : null);
    }
    return _sheetsSection();
  }

  /// The last row: the three buttons, and whatever the last sheet gave back.
  Widget _sheetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        const _Label('Sheets'),
        _SheetButton(
          icon: Icons.tune_rounded,
          label: 'Content sheet',
          detail: 'As tall as what is in it',
          onPressed: _showActionSheet,
        ),
        const SizedBox(height: 10),
        _SheetButton(
          icon: Icons.view_agenda_outlined,
          label: 'Expandable sheet',
          detail: 'Drag it between a half screen and nearly all of it',
          onPressed: _showExpandableSheet,
        ),
        const SizedBox(height: 10),
        _SheetButton(
          icon: Icons.edit_note_rounded,
          label: 'Attached sheet',
          detail: 'On the bottom edge, riding the keyboard',
          onPressed: _showComposeSheet,
        ),
        if (_lastResult.isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          Text(
            _lastResult,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ],
    );
  }

  // ── The three sheets ──────────────────────────────────────

  /// The plainest one: no detents named, so the sheet is exactly as tall
  /// as the column inside it.
  Future<void> _showActionSheet() async {
    final String? choice = await showLiquidGlassSheet<String>(
      context: context,
      header: const _SheetTitle('Share'),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (IconData icon, String label) in <(IconData, String)>[
              (Icons.link_rounded, 'Copy link'),
              (Icons.ios_share_rounded, 'Share sheet'),
              (Icons.bookmark_add_outlined, 'Save for later'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: Colors.white),
                title: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.of(context).pop(label),
              ),
            const SizedBox(height: 6),
            LiquidGlassButton(
              label: 'Cancel',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
    if (!mounted || choice == null) return;
    setState(() => _lastResult = 'Chose "$choice" from the content sheet.');
  }

  /// The expandable case, which is Flutter's `DraggableScrollableSheet`
  /// with a bare [LiquidGlassSheet] inside its builder — the glass sits
  /// within what resizes, so it grows and shrinks with the drag.
  Future<void> _showExpandableSheet() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.94,
          snap: true,
          snapSizes: const <double>[0.5, 0.94],
          builder: (BuildContext context, ScrollController scrollController) {
            return LiquidGlassSheet(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              header: const _SheetTitle('Nearby'),
              // Android's stretch overscroll isolates the list into its
              // own layer; switching it off keeps the drag handover to
              // the sheet clean.
              child: ScrollConfiguration(
                behavior:
                    const MaterialScrollBehavior().copyWith(overscroll: false),
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: 30,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white24),
                  itemBuilder: (BuildContext context, int i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                    title: Text('Result ${i + 1}',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: const Text(
                        'Drag the list — the sheet comes with it',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Full width on the bottom edge, with a field in it: the sheet lifts
  /// as the keyboard comes up.
  Future<void> _showComposeSheet() async {
    final TextEditingController message = TextEditingController();
    final String? sent = await showLiquidGlassSheet<String>(
      context: context,
      anchor: LiquidGlassSheetAnchor.attached,
      header: const _SheetTitle('New message'),
      // A sheet that has to grow past nine sixteenths of the screen —
      // which is what the keyboard lift needs room for.
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _GlassField(
              controller: message,
              hintText: 'Message',
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (String value) =>
                  Navigator.of(context).pop(value.trim()),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Discard',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Send',
                    style: LiquidGlassButton.defaultStyle.copyWith(
                      appearance:
                          const LiquidGlassAppearance(color: Color(0x660A84FF)),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(message.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    message.dispose();
    if (!mounted || sent == null || sent.isEmpty) return;
    setState(() => _lastResult = 'Sent "$sent" from the attached sheet.');
  }
}

/// One repeat of the field trio the page stacks up: a plain field, a
/// password, and one that grows as you type.
class _FieldGroup extends StatelessWidget {
  const _FieldGroup({this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: <Widget>[
          _GlassField(
            controller: controller,
            hintText: 'Your name',
            prefix: const Icon(Icons.person_outline_rounded),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          const _GlassField(
            hintText: 'Password',
            prefix: Icon(Icons.lock_outline_rounded),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          const _GlassField(
            hintText: 'Say something…',
            maxLines: 4,
            minLines: 3,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}

/// A plain Material [TextField] on a [LiquidGlassLens]: the glass is the
/// decoration, the field itself is Flutter's.
class _GlassField extends StatelessWidget {
  const _GlassField({
    this.controller,
    this.hintText,
    this.prefix,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefix;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onSubmitted;

  static LiquidGlassStyle get _defaultStyle => LiquidGlassStyle(
        shape: LiquidGlassShape.roundedRectangle(
          cornerRadius: 26,
          borderWidth: 1.2,
        ),
        appearance: const LiquidGlassAppearance(
          color: Color(0x22FFFFFF),
          blur: LiquidGlassBlur(sigmaX: 6, sigmaY: 6),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const Color fg = Colors.white;
    return LiquidGlassLens(
      style: _defaultStyle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: <Widget>[
              if (prefix != null) ...<Widget>[
                IconTheme(
                  data: IconThemeData(
                      color: fg.withValues(alpha: 0.8), size: 20),
                  child: prefix!,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  obscureText: obscureText,
                  maxLines: maxLines,
                  minLines: minLines,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  cursorColor: fg,
                  style: const TextStyle(color: fg, fontSize: 15),
                  decoration: InputDecoration.collapsed(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: fg.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                  ),
                  onSubmitted: onSubmitted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section label on the page.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// The title row every sheet on this page puts in its `header` slot —
/// which is full width, so it brings its own padding.
class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

/// One of the three buttons that open a sheet.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassButton(
      height: 62,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      onPressed: onPressed,
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
          const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
        ],
      ),
    );
  }
}

/// The photo behind the glass, with a gradient to fall back on.
class _Background extends StatelessWidget {
  const _Background({required this.url});

  final String url;

  static const DecoratedBox _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent? progress) {
            if (progress == null) return child;
            return _fallback;
          },
        ),
        // A light scrim so white text reads over the brightest stretches
        // of the photo without touching what the glass refracts.
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0x33000000)),
        ),
      ],
    );
  }
}
