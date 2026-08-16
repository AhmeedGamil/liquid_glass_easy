import 'package:flutter/material.dart';

import '../liquid_glass_tab_item.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_nav_bar_icon_row.dart';
import 'liquid_glass_nav_bar_layout.dart';

/// Static icons + labels on top of the bar capsule. Sits inside the
/// liquid-glass pipeline's `backgroundWidget` and owns the tap
/// handling.
///
/// This is the **non-animated**, release-ready bottom nav shell.
/// The selected tab is highlighted instantly (no moving glass pill,
/// no iOS-26 "icon fills through the pill" reveal). Compose it with
/// [buildLiquidGlassBottomNavCapsule] and, optionally,
/// [LiquidGlassBottomNavPillStatic] for the soft selection highlight.
///
/// The animated counterpart
/// ([LiquidGlassAnimatedBottomNavBarShell] +
/// [buildLiquidGlassBottomNavPill]) is intentionally **not exported**
/// while its motion work is still being finished.
///
/// **Important:** wrap this in [IgnorePointer] when you also place a
/// gesture overlay over the bar, otherwise the inner `InkWell`s will
/// race the overlay's drag recognizer.
class LiquidGlassTabBarShell extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final LiquidGlassTabBarLayout layout;

  const LiquidGlassTabBarShell({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final Widget innerStack = SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          // ── Icons + labels ────────────────────────────────
          // Single pass: the selected tab is colored normally.
          Positioned.fill(
            child: IgnorePointer(
              child: NavBarIconRow(
                items: items,
                layout: layout,
                selectedIndex: selectedIndex,
              ),
            ),
          ),
          // ── Tap handling ──────────────────────────────────
          // Sits on top of the icon layer but receives all
          // pointer events; the icon layer is wrapped in
          // IgnorePointer so it never competes.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(layout.padding),
              child: NavBarTapRow(
                itemCount: items.length,
                onChanged: onChanged,
                cellHeight: layout.cellHeight,
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: layout.bottomMargin),
        child: innerStack,
      ),
    );
  }
}
