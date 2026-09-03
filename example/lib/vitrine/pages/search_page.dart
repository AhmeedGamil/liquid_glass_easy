import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'product_page.dart';

// =============================================================
// Search — where the glass IS the field.
//
// A plain Material `TextField` on a `LiquidGlassLens`: the lens is the
// decoration, with no `InputDecoration` of its own. It is the page's
// third lens, which is exactly the budget, so nothing else here is
// glass at all.
// =============================================================

class SearchTab extends VitrineTab {
  const SearchTab();

  @override
  String get title => 'Search';

  @override
  String get label => 'Search';

  @override
  IconData get icon => Icons.search_rounded;

  @override
  PlateTone get tone => PlateTone.of(150);

  @override
  Widget content(BuildContext context) => const _SearchContent();
}

class _SearchContent extends StatefulWidget {
  const _SearchContent();

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Matches the name, the maker, the shelf and the one-liner — a shop
  /// where "brass" finds nothing is a shop that looks broken.
  List<Product> get _results {
    final String q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return const <Product>[];
    if (q == 'under £100' || q == 'under 100') {
      return kCatalogue.where((Product p) => p.price < 10000).toList();
    }
    if (q == 'made to order') {
      return kCatalogue.where((Product p) => p.madeToOrder).toList();
    }
    return kCatalogue.where((Product p) {
      return p.name.toLowerCase().contains(q) ||
          p.maker.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.line.toLowerCase().contains(q) ||
          p.spec.any((r) => r.$2.toLowerCase().contains(q)) ||
          p.colourways.any((Colourway c) => c.name.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.text.trim().isNotEmpty;
    final List<Product> results = _results;

    return VitrineList(
      children: <Widget>[
        _GlassField(
          controller: _query,
          hintText: 'Objects, makers, materials',
          prefix: const Icon(Icons.search_rounded),
          clearButton: true,
          height: 54,
          fontSize: 15,
          foregroundColor: kInk,
          hintColor: kInkFaint,
          cursorColor: kInk,
          textInputAction: TextInputAction.search,
          style: vitrineGlass(
              radius: 27, tint: const Color(0x66FFFFFF), blur: 8),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 26),

        if (!searching) ...<Widget>[
          Text('YOU LOOKED FOR', style: kEyebrow),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: <Widget>[
              for (final String s in kSearchSuggestions)
                VitrineChip(
                  label: s,
                  icon: Icons.history_rounded,
                  onTap: () {
                    _query.text = s;
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionHead('The whole shelf', eyebrow: 'Or just look'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 26,
            crossAxisSpacing: 16,
            childAspectRatio: 0.63,
            children: <Widget>[
              for (final Product p in kCatalogue)
                ProductCard(
                  product: p,
                  onTap: () => Navigator.of(context)
                      .push(vitrineRoute<void>(ProductPage(product: p))),
                ),
            ],
          ),
        ] else ...<Widget>[
          Text(
            '${results.length} RESULT${results.length == 1 ? '' : 'S'}',
            style: kEyebrow,
          ),
          const SizedBox(height: 8),
          if (results.isEmpty)
            _Empty(query: _query.text.trim())
          else
            for (final Product p in results)
              ProductRow(
                product: p,
                onTap: () => Navigator.of(context)
                    .push(vitrineRoute<void>(ProductPage(product: p))),
              ),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(
        children: <Widget>[
          ProductPlate(
            tone: PlateTone.of(query.hashCode.abs() % 360.0),
            kind: ObjectKind.bowl,
            seed: query,
            size: 132,
            radius: 24,
          ),
          const SizedBox(height: 22),
          Text('Nothing under that name',
              style: kTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 7),
          Text('Try a maker, a material, or a room.',
              style: kBody.copyWith(fontSize: 13)),
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
