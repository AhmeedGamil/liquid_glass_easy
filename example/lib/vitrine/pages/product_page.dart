import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'bag_page.dart';

// =============================================================
// One object.
//
// The page is a single enormous plate with the buy bar floating on it,
// and everything else scrolls up over the plate afterwards. Two lenses
// and no more: the app bar, and the bar at the foot.
//
// Choosing a finish re-lights the room. The colourway carries a hue
// shift, so picking "Ink" moves the plate, the scroll-edge band and the
// colour the two lenses are refracting — all from one number, and all
// through the same 420ms curve, which is what makes it read as the
// lights changing rather than as a picture being swapped.
// =============================================================

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  int _colourway = 0;
  bool _spec = false;

  Product get _p => widget.product;

  Future<void> _add() async {
    BagScope.read(context).add(_p, _colourway);
    final bool? go = await showLiquidGlassDialog<bool>(
      context: context,
      builder: (BuildContext context) => LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        style: vitrineGlass(
            radius: 30, tint: const Color(0x8CFFFFFF), blur: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ProductPlate(
              tone: _p.tone(_colourway),
              kind: _p.kind,
              seed: _p.id,
              size: 92,
              radius: 18,
              detail: false,
            ),
            const SizedBox(height: 18),
            Text('In your bag', style: kTitle.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              '${_p.name} · ${_p.colourways[_colourway].name}',
              textAlign: TextAlign.center,
              style: kBody,
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkButton(
                    label: 'Keep looking',
                    filled: false,
                    height: 46,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkButton(
                    label: 'Go to bag',
                    height: 46,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (go == true && mounted) {
      Navigator.of(context).push(vitrineRoute<void>(const BagPage()));
    }
  }

  void _sizeGuide() {
    showLiquidGlassSheet<void>(
      context: context,
      style: vitrineGlass(radius: 34, tint: const Color(0x8CFFFFFF), blur: 13),
      foregroundColor: kInk,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('DETAILS', style: kEyebrow),
          const SizedBox(height: 14),
          Text(_p.name, style: kDisplay.copyWith(fontSize: 26)),
          const SizedBox(height: 16),
          for (final (String, String) row in _p.spec)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 106,
                    child: Text(row.$1.toUpperCase(),
                        style: kEyebrow.copyWith(fontSize: 9)),
                  ),
                  Expanded(
                      child: Text(row.$2,
                          style: kBody.copyWith(color: kInk, fontSize: 13))),
                ],
              ),
            ),
          const SizedBox(height: 6),
          InkButton(
            label: 'Close',
            filled: false,
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    final PlateTone tone = _p.tone(_colourway);
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final double plate = (screen.height * 0.52).clamp(340.0, 580.0);
    final bool saved = bag.isSaved(_p.id);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: Stack(
        children: <Widget>[
          // The room takes the product's hue too, so the paper under the
          // plate warms or cools with the finish along with everything
          // else.
          VitrineRoom(tone: tone, seed: 'product-${_p.id}'),
          ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: pad.bottom + 132),
            children: <Widget>[
              // ── The plate ────────────────────────────────────
              // Cross-fading rather than repainting, so a colourway
              // change dissolves instead of snapping.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                child: SizedBox(
                  key: ValueKey<int>(_colourway),
                  height: plate,
                  child: ProductPlate(
                    tone: tone,
                    kind: _p.kind,
                    seed: _p.id,
                    radius: 0,
                    scale: 1.1,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: RimIcon(
                            icon: saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 46,
                            active: saved,
                            onTap: () => bag.toggleSaved(_p.id),
                          ),
                        ),
                        if (_p.reduced)
                          Positioned(
                            left: 22,
                            bottom: 22,
                            child: Rim(
                              radius: 15,
                              tint: kSignal.withValues(alpha: 0.88),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              child: Text(
                                'REDUCED',
                                style: kEyebrow.copyWith(
                                    fontSize: 9,
                                    color: const Color(0xFFFFF3EF)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_p.maker.toUpperCase(), style: kEyebrow),
                    const SizedBox(height: 10),
                    Text(_p.name, style: kDisplay.copyWith(fontSize: 32)),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Price(_p, size: 18),
                        const Spacer(),
                        if (_p.madeToOrder)
                          const _Tag('MADE TO ORDER')
                        else
                          const _Tag('IN STOCK'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(_p.story, style: kBody.copyWith(fontSize: 14)),

                    // ── Finish ───────────────────────────────
                    const SizedBox(height: 30),
                    Row(
                      children: <Widget>[
                        Text('FINISH', style: kEyebrow),
                        const SizedBox(width: 10),
                        Text(_p.colourways[_colourway].name,
                            style: kTitle.copyWith(fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        for (int i = 0; i < _p.colourways.length; i++) ...<Widget>[
                          _Swatch(
                            way: _p.colourways[i],
                            selected: i == _colourway,
                            onTap: () => setState(() => _colourway = i),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),

                    // ── Details ──────────────────────────────
                    const SizedBox(height: 30),
                    PaperRow(
                      onTap: _sizeGuide,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text('Dimensions and materials',
                                style: kTitle.copyWith(fontSize: 14.5)),
                          ),
                          const Icon(Icons.north_east_rounded,
                              size: 15, color: kInkFaint),
                        ],
                      ),
                    ),
                    PaperRow(
                      onTap: () => setState(() => _spec = !_spec),
                      rule: !_spec,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text('Delivery and returns',
                                style: kTitle.copyWith(fontSize: 14.5)),
                          ),
                          AnimatedRotation(
                            turns: _spec ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: const Icon(Icons.expand_more_rounded,
                                size: 18, color: kInkFaint),
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 18),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: kLine)),
                        ),
                        child: Text(
                          _p.madeToOrder
                              ? 'Made to order, so it is built after you buy '
                                  'it — six to eight weeks, and we will write '
                                  'when it goes into the workshop. Returns '
                                  'within 30 days of it arriving.'
                              : 'Sent within two working days, tracked, and '
                                  'free over £200. Returns within 30 days, '
                                  'unused and in the box it came in.',
                          style: kBody,
                        ),
                      ),
                      crossFadeState: _spec
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 240),
                    ),

                    // ── The rest of the maker's work ─────────
                    const SizedBox(height: 34),
                    SectionHead('More from ${_p.maker}', eyebrow: 'Same hands'),
                  ],
                ),
              ),
              SizedBox(
                height: 244,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: _siblings.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (BuildContext context, int i) => SizedBox(
                    width: 150,
                    child: ProductCard(
                      product: _siblings[i],
                      onTap: () => Navigator.of(context).pushReplacement(
                          vitrineRoute<void>(
                              ProductPage(product: _siblings[i]))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── The buy bar ──────────────────────────────────────────
      // A lens rather than a rim, because it is the one surface on the
      // page that spends its whole life over MOVING content: the plate
      // and then the paragraphs slide under it as the page scrolls.
      lenses: <Widget>[
        Positioned(
          left: 16,
          right: 16,
          bottom: pad.bottom + 18,
          child: _BuyBar(
            product: _p,
            colourway: _colourway,
            onAdd: _add,
          ),
        ),
      ],

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
        title: Text(_p.category.toUpperCase(),
            style: kEyebrow.copyWith(fontSize: 9.5, color: kInk)),
        actions: <Widget>[
          Pressable(
            onTap: () => showVitrineToast(context, 'Link copied'),
            scale: 0.86,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.ios_share_rounded, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> get _siblings => kCatalogue
      .where((Product p) => p.maker == _p.maker && p.id != _p.id)
      .toList();
}

/// The bar you buy from: the price on the left, the button on the right,
/// inside one lens.
class _BuyBar extends StatelessWidget {
  const _BuyBar({
    required this.product,
    required this.colourway,
    required this.onAdd,
  });

  final Product product;
  final int colourway;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLens(
      style: vitrineChrome(radius: 30),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(product.colourways[colourway].name.toUpperCase(),
                      style: kEyebrow.copyWith(fontSize: 8.5)),
                  const SizedBox(height: 4),
                  Price(product, size: 16),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkButton(
              label: 'Add to bag',
              icon: Icons.add_rounded,
              height: 48,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

/// A finish, as a filled circle with a ring around the chosen one.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.way,
    required this.selected,
    required this.onTap,
  });

  final Colourway way;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 44,
        padding: EdgeInsets.all(selected ? 4 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? kInk : const Color(0x1F1A1714),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: way.swatch,
            border: Border.all(color: const Color(0x141A1714)),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x261A1714)),
      ),
      child: Text(label, style: kEyebrow.copyWith(fontSize: 8.5)),
    );
  }
}
