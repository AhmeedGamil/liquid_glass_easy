import 'package:flutter/material.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'account_page.dart';
import 'collection_page.dart';
import 'product_page.dart';

// =============================================================
// Shop — the front page, and the page that sets the rule.
//
// One full-bleed plate at the top, everything under it on paper. The
// hero is deliberately tall enough that the app bar is always standing
// on it rather than on the page background: that is where the glass has
// something to do, and it is why the bar's rim picks up the hero's
// colour rather than reading white.
// =============================================================

class ShopTab extends VitrineTab {
  const ShopTab();

  @override
  String get title => 'Vitrine';

  @override
  String get label => 'Shop';

  @override
  IconData get icon => Icons.storefront_outlined;

  @override
  PlateTone get tone => PlateTone.of(30);

  @override
  List<Widget> actions(BuildContext context) => <Widget>[
        Pressable(
          scale: 0.85,
          onTap: () =>
              Navigator.of(context).push(vitrineRoute<void>(const AccountPage())),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.person_outline_rounded, size: 21),
          ),
        ),
      ];

  @override
  Widget content(BuildContext context) => const _ShopContent();
}

class _ShopContent extends StatelessWidget {
  const _ShopContent();

  @override
  Widget build(BuildContext context) {
    final Product featured = productById('light-01');
    final List<Product> newIn = kCatalogue.take(4).toList();
    final EdgeInsets pad = MediaQuery.paddingOf(context);

    // Not a `VitrineList`: that one insets for the app bar, and the
    // hero is meant to run UNDER it and under the status bar. This is
    // the only page in the app that starts at y = 0.
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: pad.bottom + kBottomInset),
      children: <Widget>[
        _Hero(product: featured),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Collections ──────────────────────────────────
              Reveal(
                index: 1,
                child: SectionHead(
                  'Collections',
                  eyebrow: 'Put together by us',
                  action: 'All four',
                  onAction: () => showVitrineToast(context, 'Four collections'),
                ),
              ),
            ],
          ),
        ),
        Reveal(
          index: 2,
          child: SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: kCollections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (BuildContext context, int i) =>
                  _CollectionCard(collection: kCollections[i]),
            ),
          ),
        ),

        // ── New in ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 38, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Reveal(
                index: 3,
                child: const SectionHead('New in', eyebrow: 'This week'),
              ),
              Reveal(
                index: 4,
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 26,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.63,
                  children: <Widget>[
                    for (final Product p in newIn)
                      ProductCard(
                        product: p,
                        onTap: () => Navigator.of(context)
                            .push(vitrineRoute<void>(ProductPage(product: p))),
                      ),
                  ],
                ),
              ),

              // ── The makers ───────────────────────────────────
              const SizedBox(height: 38),
              const SectionHead('The makers', eyebrow: 'Who made it'),
              for (final Maker m in kMakers)
                PaperRow(
                  onTap: () => showVitrineToast(context, m.name),
                  child: Row(
                    children: <Widget>[
                      ProductPlate(
                        tone: PlateTone.of(m.hue),
                        kind: ObjectKind.bowl,
                        seed: m.name,
                        size: 44,
                        radius: 22,
                        detail: false,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(m.name, style: kTitle.copyWith(fontSize: 15)),
                            const SizedBox(height: 3),
                            Text('${m.where} · since ${m.since}',
                                style: kBody.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_outward_rounded,
                          size: 16, color: kInkFaint),
                    ],
                  ),
                ),

              const SizedBox(height: 34),
              Center(
                child: Text(
                  'Everything here is made in runs of under two hundred.',
                  textAlign: TextAlign.center,
                  style: kBody.copyWith(fontSize: 12, color: kInkFaint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The full-bleed plate at the top of the shop.
///
/// It runs edge to edge and under the status bar, which is the whole
/// point: the app bar floats on it, so the first thing the app shows is
/// glass over a saturated field rather than glass over paper.
class _Hero extends StatelessWidget {
  const _Hero({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final PlateTone tone = product.tone();
    final double height =
        (MediaQuery.sizeOf(context).height * 0.56).clamp(360.0, 620.0);

    return SizedBox(
      height: height,
      child: ProductPlate(
        tone: tone,
        kind: product.kind,
        seed: '${product.id}-hero',
        radius: 0,
        scale: 1.15,
        child: Stack(
          children: <Widget>[
            // Type sits in the lower third, over the floor, where the
            // plate is darkest and a light face has the most contrast.
            Positioned(
              left: 22,
              right: 22,
              bottom: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Reveal(
                    child: Text(
                      'THE WINTER EDIT',
                      style: kEyebrow.copyWith(
                          color: tone.onPlate.withValues(alpha: 0.75)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Reveal(
                    index: 1,
                    child: Text(
                      'One good lamp\nis the whole room.',
                      style: kDisplay.copyWith(
                        fontSize: 34,
                        color: tone.onPlate,
                        height: 1.06,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Reveal(
                    index: 2,
                    child: Row(
                      children: <Widget>[
                        Rim(
                          radius: 24,
                          padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
                          onTap: () => Navigator.of(context).push(
                              vitrineRoute<void>(ProductPage(product: product))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text('See the Halo',
                                  style: kTitle.copyWith(fontSize: 14)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: kInk),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Rim(
                          radius: 24,
                          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                          child: Price(product, size: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A collection, on its own plate.
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final PlateTone tone = collection.tone;
    return Pressable(
      scale: 0.97,
      onTap: () => Navigator.of(context)
          .push(vitrineRoute<void>(CollectionPage(collection: collection))),
      child: SizedBox(
        width: 190,
        child: ProductPlate(
          tone: tone,
          kind: collection.kind,
          seed: collection.title,
          radius: 20,
          scale: 0.8,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('${collection.ids.length} PIECES',
                    style: kEyebrow.copyWith(
                        fontSize: 8.5,
                        color: tone.onPlate.withValues(alpha: 0.7))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(collection.title,
                        maxLines: 2,
                        style: kTitle.copyWith(
                            fontSize: 17, color: tone.onPlate, height: 1.15)),
                    const SizedBox(height: 5),
                    Text(collection.strap,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: kBody.copyWith(
                            fontSize: 11.5, color: tone.onPlateSoft)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
