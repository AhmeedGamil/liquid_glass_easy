import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'category_page.dart';
import 'product_page.dart';

// =============================================================
// Browse — the shelves.
//
// Seven category plates, each with a glass capsule lying on it, and a
// grid of everything underneath. Fourteen rims on one screen, and not
// one of them reads the backdrop: as lenses this page would need a
// `LiquidGlassBatch` and would still be over budget on a phone.
// =============================================================

class BrowseTab extends VitrineTab {
  const BrowseTab();

  @override
  String get title => 'Browse';

  @override
  String get label => 'Browse';

  @override
  IconData get icon => Icons.grid_view_rounded;

  @override
  PlateTone get tone => PlateTone.of(200);

  @override
  List<Widget> actions(BuildContext context) => <Widget>[
        Pressable(
          scale: 0.85,
          onTap: () => showVitrineToast(context, 'Sorted by newest'),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.swap_vert_rounded, size: 20),
          ),
        ),
      ];

  @override
  Widget content(BuildContext context) => const _BrowseContent();
}

class _BrowseContent extends StatelessWidget {
  const _BrowseContent();

  @override
  Widget build(BuildContext context) {
    return VitrineList(
      children: <Widget>[
        Reveal(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('EVERYTHING WE HAVE', style: kEyebrow),
          ),
        ),
        Reveal(
          index: 1,
          child: Text('Seven shelves,\nsixty-one objects.',
              style: kDisplay.copyWith(fontSize: 33)),
        ),
        const SizedBox(height: 28),

        // ── The shelves ──────────────────────────────────────
        // A staggered pair of columns: the plates are not all the same
        // height, so the page reads as a wall rather than a table.
        Reveal(
          index: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < kCategories.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ShelfPlate(
                          entry: kCategories[i],
                          height: i.isEven ? 168 : 138,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: <Widget>[
                    // The right column starts lower, which is the whole
                    // trick — two columns of identical plates read as a
                    // spreadsheet.
                    const SizedBox(height: 34),
                    for (int i = 1; i < kCategories.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ShelfPlate(
                          entry: kCategories[i],
                          height: i.isOdd ? 150 : 178,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),
        const SectionHead('Under £100', eyebrow: 'Small things'),
        for (final Product p in kCatalogue.where((Product p) => p.price < 10000))
          ProductRow(
            product: p,
            onTap: () => Navigator.of(context)
                .push(vitrineRoute<void>(ProductPage(product: p))),
          ),

        const SizedBox(height: 30),
        const SectionHead('Made to order', eyebrow: 'Worth the wait'),
        for (final Product p in kCatalogue.where((Product p) => p.madeToOrder))
          ProductRow(
            product: p,
            onTap: () => Navigator.of(context)
                .push(vitrineRoute<void>(ProductPage(product: p))),
            trailing: Text('6–8 wks',
                style: kBody.copyWith(fontSize: 11.5, color: kInkFaint)),
          ),
      ],
    );
  }
}

/// One shelf: a plate with the category's own object on it, and a glass
/// capsule naming it.
class _ShelfPlate extends StatelessWidget {
  const _ShelfPlate({required this.entry, required this.height});

  final (String, ObjectKind, double) entry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (String name, ObjectKind kind, double hue) = entry;
    final int count = productsIn(name).length;

    return Pressable(
      scale: 0.97,
      onTap: () =>
          Navigator.of(context).push(vitrineRoute<void>(CategoryPage(
        category: name,
        kind: kind,
        hue: hue,
      ))),
      child: SizedBox(
        height: height,
        child: ProductPlate(
          tone: PlateTone.of(hue),
          kind: kind,
          seed: name,
          radius: 18,
          scale: 0.82,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Rim(
                radius: 15,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(name, style: kTitle.copyWith(fontSize: 13)),
                    if (count > 0) ...<Widget>[
                      const SizedBox(width: 7),
                      Text('$count',
                          style: kBody.copyWith(
                              fontSize: 11.5, color: kInkFaint)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
