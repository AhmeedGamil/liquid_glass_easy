import 'package:flutter/material.dart';

import '../liquid_glass_tab_bar.dart'
    show LiquidGlassTabBarItem, buildLiquidGlassNavGlyph;
import 'liquid_glass_nav_bar_layout.dart';
import 'liquid_glass_nav_bar_style.dart';

/// The single icon + label cell shared by every bottom-nav tier (the
/// static bar, the sliding bar, and the glass-morph shell). Driven
/// entirely by [LiquidGlassNavItemStyle], so colors, sizes, the
/// icon→label gap, and the label weights all flow from one descriptor —
/// there is no hardcoded styling here.
class LiquidGlassNavTabCell extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;
  final LiquidGlassNavItemStyle style;

  const LiquidGlassNavTabCell({
    super.key,
    required this.item,
    required this.selected,
    this.style = const LiquidGlassNavItemStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final color = style.colorFor(selected: selected);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildLiquidGlassNavGlyph(
            context,
            item,
            color: color,
            size: style.iconSize,
            selected: selected,
          ),
          if (item.label != null) ...[
            SizedBox(height: style.iconLabelGap),
            Text(
              item.label!,
              style: TextStyle(
                fontSize: style.labelFontSize,
                fontWeight: style.fontWeightFor(selected: selected),
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The transparent tap layer shared by the bottom-nav tiers: one
/// full-height `InkWell` per cell, sitting above the icon layers and
/// owning all pointer events. The ripple corner radius is **derived**
/// from the cell height (a capsule) rather than a hardcoded constant.
///
/// Wrap in [IgnorePointer] (and pass a no-op [onChanged]) only where a
/// separate gesture overlay owns the taps — but prefer simply not
/// placing this row there at all.
class NavBarTapRow extends StatelessWidget {
  final int itemCount;
  final ValueChanged<int> onChanged;

  /// Height of a cell — the ripple radius is `cellHeight / 2` so the
  /// splash is a capsule matching the cell, at any bar height.
  final double cellHeight;

  const NavBarTapRow({
    super.key,
    required this.itemCount,
    required this.onChanged,
    required this.cellHeight,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(cellHeight / 2);
    return Row(
      children: [
        for (int i = 0; i < itemCount; i++)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                onTap: () => onChanged(i),
              ),
            ),
          ),
      ],
    );
  }
}

/// Single pass of icons + labels. Used both as the non-animated
/// single-layer renderer and as the dual-layer building block for
/// the iOS-26 highlight effect.
class NavBarIconRow extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final LiquidGlassBottomNavBarLayout layout;

  /// Icon/label styling for every cell.
  final LiquidGlassNavItemStyle itemStyle;

  /// When supplied, the matching cell renders in its selected
  /// state. Ignored when [forceSelected] or [forceUnselected] is
  /// true.
  final int? selectedIndex;

  /// All cells render in their selected state. Used by the
  /// "inside-the-pill" layer.
  final bool forceSelected;

  /// All cells render in their unselected state. Used by the
  /// "outside-the-pill" layer.
  final bool forceUnselected;

  const NavBarIconRow({
    super.key,
    required this.items,
    required this.layout,
    this.itemStyle = const LiquidGlassNavItemStyle(),
    this.selectedIndex,
    this.forceSelected = false,
    this.forceUnselected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(layout.padding),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: LiquidGlassNavTabCell(
                item: items[i],
                selected: forceSelected
                    ? true
                    : forceUnselected
                        ? false
                        : i == selectedIndex,
                style: itemStyle,
              ),
            ),
        ],
      ),
    );
  }
}
