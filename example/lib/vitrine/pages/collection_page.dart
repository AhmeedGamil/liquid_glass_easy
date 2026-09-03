import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'product_page.dart';

// =============================================================
// A collection.
//
// The masthead runs off the top of the screen and the list scrolls up
// over it, so the app bar spends the first screen on a saturated plate
// and the rest of it on paper. Watch the bar's rim as the boundary
// passes under it — that colour is coming from the page, through
// `LiquidGlassLite`'s blend, and nothing told it to change.
// =============================================================

class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key, required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final PlateTone tone = collection.tone;
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final List<Product> products = collection.products;
    final int from =
        products.map((Product p) => p.price).reduce((int a, int b) => a < b ? a : b);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: Stack(
        children: <Widget>[
          VitrineRoom(tone: tone, seed: collection.title),
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: pad.bottom + 48),
            children: <Widget>[
              SizedBox(
                height: (screen.height * 0.46).clamp(300.0, 520.0),
                child: ProductPlate(
                  tone: tone,
                  kind: collection.kind,
                  seed: collection.title,
                  radius: 0,
                  scale: 1.05,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Reveal(
                          child: Text(
                            '${products.length} PIECES · FROM ${money(from)}',
                            style: kEyebrow.copyWith(
                                color: tone.onPlate.withValues(alpha: 0.75)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Reveal(
                          index: 1,
                          child: Text(
                            collection.title,
                            style: kDisplay.copyWith(
                                fontSize: 36, color: tone.onPlate),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Reveal(
                          index: 2,
                          child: SizedBox(
                            width: 280,
                            child: Text(collection.strap,
                                style: kBody.copyWith(
                                    fontSize: 14, color: tone.onPlateSoft)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 26,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.63,
                      children: <Widget>[
                        for (final Product p in products)
                          ProductCard(
                            product: p,
                            onTap: () => Navigator.of(context).push(
                                vitrineRoute<void>(ProductPage(product: p))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'Collections are put together by the people who buy for '
                      'the shop, not by an algorithm. They change when '
                      'something sells out.',
                      style: kBody.copyWith(fontSize: 13),
                    ),
                  ],
                ),
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
        title: Text('COLLECTION',
            style: kEyebrow.copyWith(fontSize: 9.5, color: kInk)),
      ),
    );
  }
}
