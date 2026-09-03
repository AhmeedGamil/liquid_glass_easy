import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'product_page.dart';

// =============================================================
// Saved — the shortlist.
//
// The interesting page is the empty one. A shop with nothing in its
// wishlist usually shows a grey icon and an apology; this shows three
// plates fanned out behind each other, which is the same information
// and is worth looking at.
// =============================================================

class SavedTab extends VitrineTab {
  const SavedTab();

  @override
  String get title => 'Saved';

  @override
  String get label => 'Saved';

  @override
  IconData get icon => Icons.favorite_border_rounded;

  @override
  PlateTone get tone => PlateTone.of(340);

  @override
  Widget content(BuildContext context) => const _SavedContent();
}

class _SavedContent extends StatelessWidget {
  const _SavedContent();

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    final List<Product> saved = bag.savedProducts;

    if (saved.isEmpty) return const _EmptyShortlist();

    return VitrineList(
      children: <Widget>[
        Reveal(child: Text('KEPT', style: kEyebrow)),
        const SizedBox(height: 10),
        Reveal(
          index: 1,
          child: Text(
            saved.length == 1
                ? 'One thing\nyou keep opening.'
                : '${saved.length} things\nyou keep opening.',
            style: kDisplay.copyWith(fontSize: 33),
          ),
        ),
        const SizedBox(height: 26),
        Reveal(
          index: 2,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 26,
            crossAxisSpacing: 16,
            childAspectRatio: 0.63,
            children: <Widget>[
              for (final Product p in saved)
                ProductCard(
                  product: p,
                  onTap: () => Navigator.of(context)
                      .push(vitrineRoute<void>(ProductPage(product: p))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        InkButton(
          label: 'Add all to bag',
          icon: Icons.shopping_bag_outlined,
          onPressed: () {
            for (final Product p in saved) {
              bag.add(p, 0);
            }
            showVitrineToast(context, '${saved.length} added',
                icon: Icons.check_rounded);
          },
        ),
      ],
    );
  }
}

/// Three plates in a fan, and one line. No apology.
class _EmptyShortlist extends StatelessWidget {
  const _EmptyShortlist();

  @override
  Widget build(BuildContext context) {
    final List<Product> teasers = <Product>[
      productById('vessel-01'),
      productById('light-01'),
      productById('seat-01'),
    ];

    return VitrineList(
      children: <Widget>[
        const SizedBox(height: 30),
        Reveal(
          child: SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                for (int i = 0; i < teasers.length; i++)
                  Transform.rotate(
                    angle: (i - 1) * 0.13,
                    child: Transform.translate(
                      offset: Offset((i - 1) * 62, (i == 1 ? -8 : 10)),
                      child: ProductPlate(
                        tone: teasers[i].tone(),
                        kind: teasers[i].kind,
                        seed: teasers[i].id,
                        size: 176,
                        radius: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 34),
        Reveal(
          index: 1,
          child: Center(
            child: Text('Nothing kept yet.',
                style: kDisplay.copyWith(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 2,
          child: Center(
            child: SizedBox(
              width: 260,
              child: Text(
                'The heart on any plate puts it here. It is the only list '
                'that survives closing the app.',
                textAlign: TextAlign.center,
                style: kBody,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Reveal(
          index: 3,
          // Wrapped rather than in a row: three product names do not fit
          // a narrow phone on one line, and a second line beats a
          // clipped third chip.
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 9,
            runSpacing: 9,
            children: <Widget>[
              for (final Product p in teasers)
                VitrineChip(
                  label: p.name,
                  onTap: () => Navigator.of(context)
                      .push(vitrineRoute<void>(ProductPage(product: p))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
