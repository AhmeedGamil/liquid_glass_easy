import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../common.dart';
import '../data.dart';
import '../theme.dart';
import 'album_page.dart';

// =============================================================
// Search — where the glass IS the field.
//
// A plain Material `TextField` on a `LiquidGlassLens`: the lens is the
// decoration, with no `InputDecoration` of its own. Everything under it
// is plain, so the field is the only glass on the page.
// =============================================================

class SearchTab extends AuroraTab {
  const SearchTab();

  @override
  String get title => 'Search';

  @override
  String get label => 'Search';

  @override
  IconData get icon => Icons.search_rounded;

  @override
  AuroraPalette get palette => AuroraPalette.deep;

  @override
  Widget content(BuildContext context) => const _SearchContent();
}

class _SearchContent extends StatefulWidget {
  const _SearchContent();

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  static const Color _accent = Color(0xFF6FD9FF);

  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Album> get _results {
    final String q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return const <Album>[];
    return kAlbums
        .where((Album a) =>
            a.title.toLowerCase().contains(q) ||
            a.artist.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.text.trim().isNotEmpty;
    final List<Album> results = _results;

    return AuroraList(
      // No mini player on this tab, so the content can run lower.
      bottom: 120,
      children: <Widget>[
        const SizedBox(height: 6),
        _GlassField(
          controller: _query,
          hintText: 'Artists, records, moods',
          prefix: const Icon(Icons.search_rounded),
          clearButton: true,
          height: 54,
          fontSize: 15.5,
          foregroundColor: const Color(0xFFF4F3F8),
          hintColor: const Color(0x73EDECF5),
          cursorColor: _accent,
          textInputAction: TextInputAction.search,
          style: auroraGlass(radius: 27, blur: 6, distortion: 0.09),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        if (!searching) ...<Widget>[
          const SectionHeader('Recent',
              eyebrow: 'You looked for', accent: _accent),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: <Widget>[
              for (final String s in kSuggestions)
                AuroraChip(
                  label: s,
                  accent: _accent,
                  icon: Icons.history_rounded,
                  onTap: () {
                    _query.text = s;
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 30),
          const SectionHeader('Everything',
              eyebrow: 'The whole shelf', accent: _accent),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
            children: <Widget>[
              for (final Album a in kAlbums)
                Pressable(
                  onTap: () => Navigator.of(context)
                      .push(auroraRoute<void>(AlbumPage(album: a))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: CoverArt(seed: a.seed, radius: 20),
                      ),
                      const SizedBox(height: 9),
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kTitle.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(a.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kBody.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
            ],
          ),
        ] else ...<Widget>[
          Text('${results.length} result${results.length == 1 ? '' : 's'}',
              style: kEyebrow),
          const SizedBox(height: 14),
          if (results.isEmpty)
            FrostPanel(
              radius: 24,
              padding: const EdgeInsets.symmetric(vertical: 34),
              child: Column(
                children: <Widget>[
                  Icon(Icons.search_off_rounded,
                      size: 28, color: Colors.white.withValues(alpha: 0.35)),
                  const SizedBox(height: 12),
                  Text('Nothing under that name',
                      style: kTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 5),
                  Text('Try an artist, or a mood.', style: kBody),
                ],
              ),
            )
          else
            for (final Album a in results) ...<Widget>[
              AlbumRow(
                album: a,
                onTap: () => Navigator.of(context)
                    .push(auroraRoute<void>(AlbumPage(album: a))),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ],
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
    this.style,
    this.foregroundColor,
    this.hintColor,
    this.cursorColor,
    this.height = 52,
    this.fontSize = 15,
    this.textInputAction,
    this.clearButton = false,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefix;
  final LiquidGlassStyle? style;
  final Color? foregroundColor;
  final Color? hintColor;
  final Color? cursorColor;
  final double height;
  final double fontSize;
  final TextInputAction? textInputAction;
  final bool clearButton;
  final ValueChanged<String>? onChanged;

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
    final Color fg = foregroundColor ?? Colors.white;
    final TextEditingController? c = controller;
    return LiquidGlassLens(
      style: style ?? _defaultStyle,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
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
                  controller: c,
                  textInputAction: textInputAction,
                  cursorColor: cursorColor ?? fg,
                  style: TextStyle(color: fg, fontSize: fontSize),
                  decoration: InputDecoration.collapsed(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: hintColor ?? fg.withValues(alpha: 0.5),
                      fontSize: fontSize,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              if (clearButton && c != null && c.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: fg.withValues(alpha: 0.7),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    c.clear();
                    onChanged?.call('');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
