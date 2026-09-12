import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Sheets — the glass surface you pull up.
//
// Three buttons over a photo present LiquidGlassSheets, each a different
// shape of the same surface. The presenter is Flutter's own
// showModalBottomSheet with the glass where its Material used to be, so:
//   • the plain one hugs what is in it, the shape of an action sheet.
//   • the expandable one is a DraggableScrollableSheet with a bare
//     LiquidGlassSheet inside its builder — the glass has to be within
//     what resizes.
//   • the attached one is full width on the bottom edge, only its top
//     corners in frame.
//
// Inside a LiquidGlassScaffold, so the sheets join its capture on BOTH
// backends. Every glass on the page — the sheets, the buttons in them,
// the openers — is LITE glass with the `surface` rim: `liteGlass:
// LiquidGlassLitePickup.surface` on the style, no shader and no refraction, the rim blended over the
// tint and the content.
//
//   flutter run -t lib/sheet_field_page.dart   (standalone)
//   …or open it from the gallery.
// =============================================================

void main() {
  runApp(const _SheetFieldApp());
}

/// Every surface on the page is lite glass with the `surface` rim.
const LiquidGlassLitePickup _rim = LiquidGlassLitePickup.surface;

/// The sheets: the stock sheet glass, drawn lite.
final LiquidGlassStyle _sheetStyle =
    LiquidGlassSheet.defaultStyle.copyWith(liteGlass: _rim);

/// The buttons, on the page and in the sheets: the stock button glass,
/// drawn lite and with no frost — a surface-rim button reads best as a
/// flat tinted plate.
final LiquidGlassStyle _buttonStyle = LiquidGlassButton.defaultStyle.copyWith(
  liteGlass: _rim,
  appearance: LiquidGlassButton.defaultStyle.appearance
      .copyWith(blur: const LiquidGlassBlur()),
);

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

/// Glass sheets over a photo.
class SheetFieldPage extends StatefulWidget {
  const SheetFieldPage({super.key});

  @override
  State<SheetFieldPage> createState() => _SheetFieldPageState();
}

class _SheetFieldPageState extends State<SheetFieldPage> {
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  String _lastResult = '';

  @override
  Widget build(BuildContext context) {
    // A LiquidGlassScaffold rather than a bare view: a sheet presented
    // from a context inside one joins the scaffold's capture, so the
    // glass refracts the photo on every backend instead of falling back
    // to a frosted fill.
    return LiquidGlassScaffold(
      appBar: LiquidGlassAppBar(
        title: const Text('Sheets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _Background(url: _imageUrl),
          // A plain column, not a list: three buttons never need to scroll,
          // and glass that stays put refracts instead of riding the feed.
          Builder(
            builder: (BuildContext context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Label('Sheets'),
                  _SheetButton(
                    icon: Icons.tune_rounded,
                    label: 'Content sheet',
                    detail: 'As tall as what is in it',
                    onPressed: () => _showActionSheet(context),
                  ),
                  const SizedBox(height: 10),
                  _SheetButton(
                    icon: Icons.view_agenda_outlined,
                    label: 'Expandable sheet',
                    detail:
                        'Drag it between a half screen and nearly all of it',
                    onPressed: () => _showExpandableSheet(context),
                  ),
                  const SizedBox(height: 10),
                  _SheetButton(
                    icon: Icons.vertical_align_bottom_rounded,
                    label: 'Attached sheet',
                    detail: 'Full width on the bottom edge',
                    onPressed: () => _showAttachedSheet(context),
                  ),
                  if (_lastResult.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 22),
                    Text(
                      _lastResult,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── The three sheets ──────────────────────────────────────

  /// The plainest one: no detents named, so the sheet is exactly as tall
  /// as the column inside it.
  Future<void> _showActionSheet(BuildContext context) async {
    final String? choice = await showLiquidGlassSheet<String>(
      context: context,
      style: _sheetStyle,
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
              style: _buttonStyle,
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
  Future<void> _showExpandableSheet(BuildContext context) {
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
              style: _sheetStyle,
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

  /// Full width on the bottom edge: only the top corners are in frame,
  /// and the content clears the safe area on its own.
  Future<void> _showAttachedSheet(BuildContext context) async {
    final bool? removed = await showLiquidGlassSheet<bool>(
      context: context,
      style: _sheetStyle,
      anchor: LiquidGlassSheetAnchor.attached,
      header: const _SheetTitle('Remove download?'),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'It stays in your library and can be downloaded again '
              'whenever you like.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Keep',
                    style: _buttonStyle,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidGlassButton(
                    label: 'Remove',
                    style: _buttonStyle.copyWith(
                      appearance:
                          const LiquidGlassAppearance(color: Color(0x60FF3B30)),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (!mounted || removed == null) return;
    setState(() => _lastResult = removed
        ? 'Removed from the attached sheet.'
        : 'Kept from the attached sheet.');
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
      height: 72,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      style: _buttonStyle,
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
        colors: <Color>[
          Color(0xFF2E1065),
          Color(0xFF0EA5E9),
          Color(0xFFF59E0B)
        ],
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
          loadingBuilder:
              (BuildContext context, Widget child, ImageChunkEvent? progress) {
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
