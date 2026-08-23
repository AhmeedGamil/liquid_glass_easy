import 'package:flutter/material.dart';

import '../../utils/liquid_glass_adaptivity.dart';
import '../liquid_glass_adaptive_area.dart';

import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_tab_item.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_nav_bar_icon_row.dart';
import 'liquid_glass_nav_bar_pill.dart';
import 'liquid_glass_nav_bar_style.dart';

/// Crisp content layer (selection pill + icons + labels + taps)
/// drawn on top of the [LiquidGlassTabBar] capsule, inside the
/// lens `child` so it is clipped to the capsule and stays sharp.
class BottomNavBarContent extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double itemPadding;
  final bool showSelectionPill;
  final Color selectionColor;

  /// Palette the pill flips between when the bar is adaptive. Resolved
  /// against the BAR's verdict (published by its lens), never sampled —
  /// the pill sits on the capsule, so its own rect reads the capsule's
  /// tint rather than the page. `null` keeps [selectionColor] fixed.
  final LiquidGlassAdaptivity? selectionAdaptivity;

  /// Icon + label styling for every cell.
  final LiquidGlassTabItemStyle itemStyle;

  /// Corner shape (and optional border) of the selection pill. When
  /// `null`, a plain capsule is used.
  final LiquidGlassShape? pillShape;

  /// Unselected cells follow the ambient adaptive content color
  /// (installed by the hosting lens) instead of the style's fixed color;
  /// the selected cell keeps `itemStyle.selectedColor`. Set when the
  /// bar's `style.adaptivity` is enabled.
  final bool adaptive;

  const BottomNavBarContent({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.itemPadding,
    required this.showSelectionPill,
    required this.selectionColor,
    this.selectionAdaptivity,
    required this.itemStyle,
    this.pillShape,
    this.adaptive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color pillColor = LiquidGlassAdaptiveVerdictScope.resolve(
        context, selectionAdaptivity, selectionColor);
    return Padding(
      padding: EdgeInsets.all(itemPadding),
      child: LayoutBuilder(builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / items.length;
        final cellHeight = constraints.maxHeight;
        return Stack(
          children: [
            // Static selection pill — jumps instantly to the
            // selected cell (no slide). Sits behind the icons.
            if (showSelectionPill)
              Positioned(
                left: selectedIndex * cellWidth,
                top: 0,
                bottom: 0,
                width: cellWidth,
                child: Center(
                  child: CustomPaint(
                    size: Size(cellWidth, cellHeight),
                    painter: LiquidGlassNavPillSurfacePainter(
                      color: pillColor,
                      shape: pillShape,
                    ),
                  ),
                ),
              ),
            // Icon + label row with tap handling.
            Row(
              children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(cellHeight / 2),
                        onTap: () => onChanged(i),
                        child: LiquidGlassNavTabCell(
                          item: items[i],
                          selected: i == selectedIndex,
                          style: itemStyle,
                          adaptive: adaptive,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
