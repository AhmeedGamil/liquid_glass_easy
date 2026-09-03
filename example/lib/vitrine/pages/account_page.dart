import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../common.dart';
import '../data.dart';
import '../plate.dart';
import '../theme.dart';
import 'product_page.dart';

// =============================================================
// Account — orders, preferences, and the way out.
//
// Two `LiquidGlassSwitch`es, and two is the number on purpose: each one
// runs a capture pipeline of its own, so with the app bar that is three
// lenses on this page and there is no room for a fourth. Everything
// else that looks like a control here is paper.
// =============================================================

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _restock = true;
  bool _paper = false;

  Future<void> _signOut() async {
    final bool? out = await showLiquidGlassDialog<bool>(
      context: context,
      builder: (BuildContext context) => LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        style: vitrineGlass(radius: 32, tint: const Color(0x8CFFFFFF), blur: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.logout_rounded, size: 24, color: kInk),
            const SizedBox(height: 16),
            Text('Sign out?', style: kTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Your bag stays on this device for thirty days.',
                textAlign: TextAlign.center, style: kBody),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkButton(
                    label: 'Stay',
                    filled: false,
                    height: 46,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkButton(
                    label: 'Sign out',
                    height: 46,
                    color: kSignal,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (out == true && mounted) {
      showVitrineToast(context, 'Signed out');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Bag bag = BagScope.of(context);
    final Size screen = MediaQuery.sizeOf(context);

    return LiquidGlassScaffold(
      pixelRatio: 1,
      useSync: true,
      body: Stack(
        children: <Widget>[
          VitrineRoom(tone: _slate, seed: 'account'),
          VitrineList(
            bottom: 60,
            children: <Widget>[
              Reveal(child: Text('YOUR ACCOUNT', style: kEyebrow)),
              const SizedBox(height: 10),
              Reveal(
                index: 1,
                child: Text('Ahmed', style: kDisplay.copyWith(fontSize: 34)),
              ),
              const SizedBox(height: 6),
              Reveal(
                index: 2,
                child: Text('Member since 2021 · 14 orders', style: kBody),
              ),

              // ── The order in flight ──────────────────────────
              const SizedBox(height: 28),
              Reveal(index: 3, child: const _Tracker()),

              // ── Preferences ──────────────────────────────────
              const SizedBox(height: 34),
              const SectionHead('Preferences', eyebrow: 'How we write'),
              _SwitchRow(
                label: 'Back in stock',
                detail: 'Only for things you have saved',
                value: _restock,
                onChanged: (bool v) => setState(() => _restock = v),
              ),
              _SwitchRow(
                label: 'The paper catalogue',
                detail: 'Twice a year, printed in Bristol',
                value: _paper,
                onChanged: (bool v) => setState(() => _paper = v),
              ),

              // ── The rest ─────────────────────────────────────
              const SizedBox(height: 30),
              const SectionHead('Everything else', eyebrow: 'Admin'),
              for (final (IconData, String, String) row
                  in const <(IconData, String, String)>[
                (Icons.receipt_long_outlined, 'Order history', '14 orders'),
                (Icons.place_outlined, 'Addresses', 'One on file'),
                (Icons.credit_card_outlined, 'Payment', 'Card ending 4417'),
                (Icons.help_outline_rounded, 'Help', 'We answer by email'),
              ])
                PaperRow(
                  onTap: () => showVitrineToast(context, row.$2),
                  child: Row(
                    children: <Widget>[
                      Icon(row.$1, size: 19, color: kInkSoft),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(row.$2, style: kTitle.copyWith(fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(row.$3, style: kBody.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 19, color: kInkFaint),
                    ],
                  ),
                ),

              const SizedBox(height: 28),
              InkButton(
                label: 'Sign out',
                filled: false,
                onPressed: _signOut,
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'Vitrine 1.0 · built on liquid_glass_easy'
                  '${bag.count > 0 ? ' · ${bag.count} in the bag' : ''}',
                  style: kBody.copyWith(fontSize: 11.5, color: kInkFaint),
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
        title:
            Text('ACCOUNT', style: kEyebrow.copyWith(fontSize: 9.5, color: kInk)),
      ),
    );
  }
}

/// The one order that is still moving, on its own plate, with the rail
/// it is somewhere along.
class _Tracker extends StatelessWidget {
  const _Tracker();

  static const List<String> _steps = <String>[
    'Placed',
    'In the workshop',
    'On its way',
    'Delivered',
  ];
  static const int _at = 2;

  @override
  Widget build(BuildContext context) {
    final Product p = productById('seat-01');
    final PlateTone tone = p.tone();

    return Pressable(
      scale: 0.98,
      onTap: () => Navigator.of(context)
          .push(vitrineRoute<void>(ProductPage(product: p))),
      child: SizedBox(
        height: 210,
        child: ProductPlate(
          tone: tone,
          kind: p.kind,
          seed: 'order-${p.id}',
          radius: 22,
          scale: 0.66,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Align(
                  alignment: Alignment.topLeft,
                  child: Rim(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    child: Text('ORDER 4417 · ${p.name}',
                        style: kEyebrow.copyWith(fontSize: 8.5)),
                  ),
                ),
                Rim(
                  radius: 18,
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_steps[_at], style: kTitle.copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Arriving Thursday, between 9 and 1',
                          style: kBody.copyWith(fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          for (int i = 0; i < _steps.length; i++) ...<Widget>[
                            Expanded(
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: i <= _at
                                      ? kInk
                                      : kInk.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            if (i != _steps.length - 1)
                              const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A preference, with a real [LiquidGlassSwitch] on the end of it.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PaperRow(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: kTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text(detail, style: kBody.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          LiquidGlassSwitch(
            value: value,
            activeColor: kInk,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// The account page is not lit by a product, so it gets its own quiet
/// blue-grey room.
final PlateTone _slate = PlateTone.of(214);
