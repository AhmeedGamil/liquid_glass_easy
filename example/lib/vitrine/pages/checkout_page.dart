import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'bag_page.dart';

// =============================================================
// Checkout — and the one control the whole app is building toward.
//
// You do not press a button to pay. You drag a glass thumb across a
// plate, and it refracts the plate as it goes — a `LiquidGlassSlider`
// with its own capture pipeline, used as a confirm rather than as a
// value. That is worth the lens it costs, and it is why nothing else
// on this page is glass: the bar, and the slider, and that is the
// budget spent.
//
// It also solves the real problem with slide-to-confirm, which is that
// people let go halfway. Under 92% it springs back; over it, it locks.
// =============================================================

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const List<(String, String, int)> _delivery = <(String, String, int)>[
    ('Standard', '3–5 working days', 0),
    ('Named day', 'Pick a date at the door', 495),
    ('Next day', 'Ordered before 2pm', 895),
  ];

  int _method = 0;
  double _slide = 0;
  bool _placed = false;

  /// What delivery adds. Standard is whatever the bag already worked
  /// out — free over two hundred — and the two paid options are their
  /// own price whatever the bag came to.
  int _extra(Bag bag) => _method == 0 ? bag.delivery : _delivery[_method].$3;

  Future<void> _place(Bag bag) async {
    setState(() => _placed = true);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    await showLiquidGlassDialog<void>(
      context: context,
      builder: (BuildContext context) => LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        style: vitrineGlass(radius: 32, tint: const Color(0x8CFFFFFF), blur: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_rounded, size: 30, color: kInk),
            const SizedBox(height: 16),
            Text('Order placed', style: kTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Confirmation is on its way. You can watch it move in your '
              'account.',
              textAlign: TextAlign.center,
              style: kBody,
            ),
            const SizedBox(height: 22),
            InkButton(
              label: 'Done',
              height: 46,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    bag.clear();
    Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    final PlateTone tone = bagTone(bag);
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final int total = bag.subtotal + _extra(bag);
    final double slideWidth = (screen.width - 76).clamp(220.0, 420.0);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: Stack(
        children: <Widget>[
          VitrineRoom(tone: tone, seed: 'checkout'),
          VitrineList(
            bottom: pad.bottom + 40,
            children: <Widget>[
              Reveal(child: Text('ALMOST', style: kEyebrow)),
              const SizedBox(height: 10),
              Reveal(
                index: 1,
                child: Text('Where it goes,\nand how fast.',
                    style: kDisplay.copyWith(fontSize: 31)),
              ),
              const SizedBox(height: 26),

              // ── Where ────────────────────────────────────────
              Reveal(
                index: 2,
                child: PaperRow(
                  onTap: () => showVitrineToast(context, 'One address on file'),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.home_outlined, size: 19, color: kInkSoft),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Home', style: kTitle.copyWith(fontSize: 15)),
                            const SizedBox(height: 3),
                            Text('14 Ardwick Terrace, London E5 8QT',
                                style: kBody.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('Change',
                          style: kBody.copyWith(
                              fontSize: 12.5,
                              color: kInk,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              // ── How fast ─────────────────────────────────────
              const SizedBox(height: 26),
              const SectionHead('Delivery', eyebrow: 'How fast'),
              for (int i = 0; i < _delivery.length; i++)
                _Option(
                  title: _delivery[i].$1,
                  detail: _delivery[i].$2,
                  price: _delivery[i].$3 == 0
                      ? (bag.delivery == 0 ? 'Free' : money(bag.delivery))
                      : money(_delivery[i].$3),
                  selected: _method == i,
                  onTap: () => setState(() => _method = i),
                ),

              // ── Paying with ──────────────────────────────────
              const SizedBox(height: 30),
              const SectionHead('Payment', eyebrow: 'Paying with'),
              PaperRow(
                onTap: () => showVitrineToast(context, 'One card on file'),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 26,
                      decoration: BoxDecoration(
                        color: kInk,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Text('••',
                          style: TextStyle(
                              color: kPaper.withValues(alpha: 0.9),
                              fontSize: 13,
                              height: 1)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Card ending 4417',
                          style: kTitle.copyWith(fontSize: 15)),
                    ),
                    const Icon(Icons.expand_more_rounded,
                        size: 18, color: kInkFaint),
                  ],
                ),
              ),

              // ── What it comes to ─────────────────────────────
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kPaperSunk,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: <Widget>[
                    for (final BagLine l in bag.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${l.product.name}'
                                '${l.qty > 1 ? ' × ${l.qty}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kBody.copyWith(
                                    fontSize: 13, color: kInkSoft),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(money(l.total),
                                style: kPrice.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    const Divider(height: 20, color: Color(0x1F1A1714)),
                    Row(
                      children: <Widget>[
                        Text('Total', style: kTitle.copyWith(fontSize: 16)),
                        const Spacer(),
                        Text(money(total),
                            style: kDisplay.copyWith(
                                fontSize: 24, letterSpacing: -0.9)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── The slide ────────────────────────────────────
              const SizedBox(height: 34),
              _SlideToPay(
                width: slideWidth,
                tone: tone,
                value: _slide,
                locked: _placed,
                total: total,
                onChanged: (double v) => setState(() => _slide = v),
                onCommit: () => _place(bag),
                onRelease: () => setState(() => _slide = 0),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text('Nothing is charged until it ships.',
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
        title: Text('CHECKOUT',
            style: kEyebrow.copyWith(fontSize: 9.5, color: kInk)),
      ),
    );
  }
}

/// Drag the glass across to pay.
///
/// A `LiquidGlassSlider` standing on a plate, so the thumb has a disc
/// rim, a horizon and an object to bend as it travels — which is the
/// only reason this reads as glass rather than as a light-coloured
/// circle. The track is the plate; the slider draws nothing over it.
class _SlideToPay extends StatelessWidget {
  const _SlideToPay({
    required this.width,
    required this.tone,
    required this.value,
    required this.locked,
    required this.total,
    required this.onChanged,
    required this.onCommit,
    required this.onRelease,
  });

  final double width;
  final PlateTone tone;
  final double value;
  final bool locked;
  final int total;
  final ValueChanged<double> onChanged;
  final VoidCallback onCommit;
  final VoidCallback onRelease;

  /// Where a release counts as a commit rather than a slip.
  static const double _commitAt = 0.92;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(33),
      child: SizedBox(
        height: 66,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // The plate is the track. It is the thing being refracted.
            Positioned.fill(
              child: ProductPlate(
                tone: tone,
                kind: ObjectKind.clock,
                seed: 'pay',
                radius: 33,
                scale: 0.5,
                detail: false,
              ),
            ),
            // The instruction, fading out as the thumb covers it.
            IgnorePointer(
              child: Opacity(
                opacity: (1 - value * 1.6).clamp(0.0, 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      locked ? 'Placing…' : 'Slide to pay ${money(total)}',
                      style: kTitle.copyWith(
                          fontSize: 14.5, color: tone.onPlate),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: tone.onPlateSoft),
                  ],
                ),
              ),
            ),
            // Centred rather than filled: the slider wants its own
            // width, and a tight fill would fight it for one.
            IgnorePointer(
              ignoring: locked,
              child: LiquidGlassSlider(
                value: value,
                width: width,
                height: 62,
                activeColor: Colors.transparent,
                inactiveColor: Colors.transparent,
                onChanged: onChanged,
                onChangeEnd: (double v) =>
                    v >= _commitAt ? onCommit() : onRelease(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.detail,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaperRow(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? kInk : Colors.transparent,
              border: Border.all(
                color: selected ? kInk : const Color(0x331A1714),
                width: 1.3,
              ),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 12, color: kPaper)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text(detail, style: kBody.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(price, style: kPrice.copyWith(fontSize: 13.5)),
        ],
      ),
    );
  }
}
