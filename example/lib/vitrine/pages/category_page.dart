import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'product_page.dart';

// =============================================================
// One shelf.
//
// A filter row that actually filters, and a switch between the two ways
// to look at a shop: big plates, or a list you can scan. The toggle is
// paper, not glass — it is pressed constantly, and a lens that flickers
// under a finger is worse than no lens.
// =============================================================

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.category,
    required this.kind,
    required this.hue,
  });

  final String category;
  final ObjectKind kind;
  final double hue;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

enum _Sort { newest, low, high }

class _CategoryPageState extends State<CategoryPage> {
  _Sort _sort = _Sort.newest;
  bool _grid = true;

  List<Product> get _shown {
    final List<Product> found = productsIn(widget.category);
    // Nothing on a shelf is worse than an empty one; the shelves this
    // catalogue is too small to fill borrow from the whole shop.
    final List<Product> list = found.length >= 2
        ? found
        : <Product>{
            ...found,
            ...kCatalogue.where((Product p) => p.kind == widget.kind),
          }.toList();

    switch (_sort) {
      case _Sort.newest:
        return list;
      case _Sort.low:
        return list..sort((Product a, Product b) => a.price.compareTo(b.price));
      case _Sort.high:
        return list..sort((Product a, Product b) => b.price.compareTo(a.price));
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlateTone tone = PlateTone.of(widget.hue);
    final Size screen = MediaQuery.sizeOf(context);
    final List<Product> shown = _shown;

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: Stack(
        children: <Widget>[
          VitrineRoom(tone: tone, seed: widget.category),
          VitrineList(
            bottom: 60,
            children: <Widget>[
              Reveal(
                child: SizedBox(
                  height: 172,
                  child: ProductPlate(
                    tone: tone,
                    kind: widget.kind,
                    seed: widget.category,
                    radius: 22,
                    scale: 0.78,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.category,
                          style: kDisplay.copyWith(
                              fontSize: 30, color: tone.onPlate),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Sort, and how to look ────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final (_Sort s, String label)
                            in const <(_Sort, String)>[
                          (_Sort.newest, 'Newest'),
                          (_Sort.low, 'Price ↑'),
                          (_Sort.high, 'Price ↓'),
                        ])
                          VitrineChip(
                            label: label,
                            selected: _sort == s,
                            onTap: () => setState(() => _sort = s),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    scale: 0.86,
                    onTap: () => setState(() => _grid = !_grid),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x261A1714)),
                      ),
                      child: Icon(
                        _grid
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_rounded,
                        size: 17,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ── The shelf ────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _grid
                    ? GridView.count(
                        key: const ValueKey<bool>(true),
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 26,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.63,
                        children: <Widget>[
                          for (final Product p in shown)
                            ProductCard(
                              product: p,
                              onTap: () => Navigator.of(context).push(
                                  vitrineRoute<void>(ProductPage(product: p))),
                            ),
                        ],
                      )
                    : Column(
                        key: const ValueKey<bool>(false),
                        children: <Widget>[
                          for (final Product p in shown)
                            ProductRow(
                              product: p,
                              plate: 78,
                              onTap: () => Navigator.of(context).push(
                                  vitrineRoute<void>(ProductPage(product: p))),
                            ),
                        ],
                      ),
              ),

              const SizedBox(height: 30),
              Center(
                child: Text('${shown.length} of ${kCatalogue.length} shown',
                    style: kBody.copyWith(fontSize: 12, color: kInkFaint)),
              ),
            ],
          ),
        ],
      ),
      appBar: LiquidGlassAppBar(
        width: (screen.width - 32).clamp(280.0, 520.0),
        height: 52,
        centerTitle: true,
        style: vitrineChrome(radius: 26),
        foregroundColor: kInk,
        leading: Pressable(
          onTap: () => Navigator.of(context).maybePop(),
          scale: 0.86,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
        ),
        title: Text(widget.category.toUpperCase(),
            style: kEyebrow.copyWith(fontSize: 9.5, color: kInk)),
      ),
    );
  }
}
