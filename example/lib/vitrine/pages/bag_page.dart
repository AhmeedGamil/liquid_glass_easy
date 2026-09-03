import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'checkout_page.dart';
import 'product_page.dart';

// =============================================================
// The bag.
//
// Reachable two ways — as a tab, and pushed from a product — so the
// content is one widget and the two hosts are thin. [BagTab] hands it
// to the shell's scaffold; [BagPage] gives it one of its own.
//
// The receipt at the bottom is a plate, and its hue is the AVERAGE of
// what is in the bag. Add a green bottle to a bag of clay pots and the
// receipt moves. It costs one line and it is the thing people notice.
// =============================================================

class BagTab extends VitrineTab {
  const BagTab();

  @override
  String get title => 'Bag';

  @override
  String get label => 'Bag';

  @override
  IconData get icon => Icons.shopping_bag_outlined;

  @override
  PlateTone get tone => PlateTone.of(48);

  @override
  Widget content(BuildContext context) => const BagContent();
}

/// The pushed form, for arriving here from a product page.
class BagPage extends StatelessWidget {
  const BagPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: Stack(
        children: <Widget>[
          VitrineRoom(tone: bagTone(bag), seed: 'bag'),
          const BagContent(bottom: 40),
        ],
      ),
      appBar: LiquidGlassAppBar(
        width: (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 520.0),
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
        title: Text('YOUR BAG',
            style: kEyebrow.copyWith(fontSize: 9.5, color: kInk)),
      ),
    );
  }
}

/// The bag's own colour: the mean of everything in it, or a neutral
/// warm hue when it is empty. Hues are angles, so this averages them as
/// unit vectors — a plain mean of 350 and 10 gives 180, which is the
/// wrong side of the wheel.
PlateTone bagTone(Bag bag) {
  if (bag.lines.isEmpty) return PlateTone.of(48);
  double x = 0, y = 0;
  for (final BagLine l in bag.lines) {
    final double rad = l.product.hue * math.pi / 180;
    x += l.qty * math.cos(rad);
    y += l.qty * math.sin(rad);
  }
  final double mean = math.atan2(y, x) * 180 / math.pi;
  return PlateTone.of((mean + 360) % 360);
}

class BagContent extends StatelessWidget {
  const BagContent({super.key, this.bottom = kBottomInset});

  final double bottom;

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    if (bag.lines.isEmpty) return _EmptyBag(bottom: bottom);

    return VitrineList(
      bottom: bottom,
      children: <Widget>[
        Reveal(child: Text('YOUR BAG', style: kEyebrow)),
        const SizedBox(height: 10),
        Reveal(
          index: 1,
          child: Text(
            bag.count == 1 ? 'One object.' : '${bag.count} objects.',
            style: kDisplay.copyWith(fontSize: 33),
          ),
        ),
        const SizedBox(height: 24),

        for (int i = 0; i < bag.lines.length; i++)
          _Line(
            line: bag.lines[i],
            highlight: bag.lines[i].key == bag.lastAdded,
          ),

        const SizedBox(height: 28),

        // ── The receipt ──────────────────────────────────────
        _Receipt(bag: bag),

        const SizedBox(height: 22),
        Center(
          child: Text(
            bag.delivery == 0
                ? 'Delivery is on us.'
                : 'Free delivery over ${money(20000)} — '
                    '${money(20000 - bag.subtotal)} to go.',
            style: kBody.copyWith(fontSize: 12, color: kInkFaint),
          ),
        ),
      ],
    );
  }
}

/// One line of the bag, with the finish it was chosen in.
class _Line extends StatelessWidget {
  const _Line({required this.line, this.highlight = false});

  final BagLine line;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    final Product p = line.product;

    return PaperRow(
      onTap: () => Navigator.of(context)
          .push(vitrineRoute<void>(ProductPage(product: p))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The newest line arrives with a ring around its plate, which
          // fades out on its own — a bag you were just sent to should
          // say which line is the new one.
          AnimatedContainer(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(highlight ? 3 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: highlight ? kInk : Colors.transparent,
                width: highlight ? 1.2 : 0,
              ),
            ),
            child: ProductPlate(
              tone: p.tone(line.colourway),
              kind: p.kind,
              seed: p.id,
              size: 72,
              radius: 14,
              detail: false,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(p.maker.toUpperCase(),
                    style: kEyebrow.copyWith(fontSize: 8.5)),
                const SizedBox(height: 5),
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text(p.colourways[line.colourway].name,
                    style: kBody.copyWith(fontSize: 12)),
                const SizedBox(height: 10),
                _Stepper(
                  qty: line.qty,
                  onChanged: (int q) => bag.setQty(line, q),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(money(line.total), style: kPrice),
        ],
      ),
    );
  }
}

/// Minus, the number, plus. Removing is what minus does at one.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F1A1714)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Step(
            icon: qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            onTap: () => onChanged(qty - 1),
          ),
          SizedBox(
            width: 26,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: kTitle.copyWith(fontSize: 13.5)),
          ),
          _Step(icon: Icons.add_rounded, onTap: () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.82,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: 15, color: kInk),
      ),
    );
  }
}

/// The total, on a plate the bag mixed itself.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.bag});

  final Bag bag;

  @override
  Widget build(BuildContext context) {
    final PlateTone tone = bagTone(bag);

    return SizedBox(
      height: 284,
      child: ProductPlate(
        tone: tone,
        kind: bag.lines.first.product.kind,
        seed: 'receipt-${bag.count}',
        radius: 24,
        scale: 0.72,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.topLeft,
                child: Rim(
                  radius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text('TO PAY', style: kEyebrow.copyWith(fontSize: 8.5)),
                ),
              ),
              Rim(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  children: <Widget>[
                    _Row('Subtotal', money(bag.subtotal)),
                    const SizedBox(height: 7),
                    _Row(
                      'Delivery',
                      bag.delivery == 0 ? 'Free' : money(bag.delivery),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 11),
                      child: Divider(height: 1, color: Color(0x1F1A1714)),
                    ),
                    Row(
                      children: <Widget>[
                        Text('Total', style: kTitle.copyWith(fontSize: 15)),
                        const Spacer(),
                        Text(money(bag.total),
                            style: kDisplay.copyWith(
                                fontSize: 22, letterSpacing: -0.8)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkButton(
                      label: 'Checkout',
                      icon: Icons.lock_outline_rounded,
                      height: 50,
                      onPressed: () => Navigator.of(context)
                          .push(vitrineRoute<void>(const CheckoutPage())),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(label, style: kBody.copyWith(fontSize: 13)),
        const Spacer(),
        Text(value, style: kPrice.copyWith(fontSize: 13.5)),
      ],
    );
  }
}

class _EmptyBag extends StatelessWidget {
  const _EmptyBag({required this.bottom});

  final double bottom;

  @override
  Widget build(BuildContext context) {
    final Product suggestion = productById('table-01');
    return VitrineList(
      bottom: bottom,
      children: <Widget>[
        const SizedBox(height: 40),
        Reveal(
          child: Center(
            child: ProductPlate(
              tone: PlateTone.of(48),
              kind: ObjectKind.bowl,
              seed: 'empty-bag',
              size: 190,
              radius: 26,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Reveal(
          index: 1,
          child: Center(
            child: Text('The bag is empty.',
                style: kDisplay.copyWith(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 2,
          child: Center(
            child: SizedBox(
              width: 250,
              child: Text(
                'Most people start with the mug. It is the cheapest thing '
                'here and the one they come back for.',
                textAlign: TextAlign.center,
                style: kBody,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Reveal(
          index: 3,
          child: ProductRow(
            product: suggestion,
            onTap: () => Navigator.of(context)
                .push(vitrineRoute<void>(ProductPage(product: suggestion))),
          ),
        ),
      ],
    );
  }
}
