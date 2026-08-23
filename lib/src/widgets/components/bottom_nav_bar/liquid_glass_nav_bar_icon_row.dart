import 'package:flutter/material.dart';

import '../liquid_glass_tab_item.dart'
    show
        LiquidGlassTabBarItem,
        buildLiquidGlassNavGlyph,
        buildLiquidGlassNavLabel;
import 'liquid_glass_nav_bar_layout.dart';
import 'liquid_glass_nav_bar_style.dart';

/// The single icon + label cell shared by every bottom-nav tier (the
/// static bar, the sliding bar, and the glass-morph shell). Driven
/// entirely by [LiquidGlassTabItemStyle], so colors, sizes, the
/// icon→label gap, and the label weights all flow from one descriptor —
/// there is no hardcoded styling here.
class LiquidGlassNavTabCell extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;

  /// How much **glass** is over this cell in the layer being drawn,
  /// `0`–`1` — the glass's state, distinct from [selected]. `1` while
  /// the moving glass pill covers it, easing back to `0` as the landed
  /// pill sheds into the static rest pill, and always `0` under a flat
  /// pill or none. The under-glass sizes lerp on this; color, weight
  /// and icon art key off [selected].
  final double underGlass;

  final LiquidGlassTabItemStyle style;

  /// When `true` (the bar's `style.adaptivity` is set), **unselected**
  /// cells ignore the style's fixed color and follow the **ambient
  /// adaptive content color** instead — the animated `IconTheme` color
  /// installed by the hosting lens (plain tiers) or by the animated bar
  /// (glass tier). The selected cell keeps [LiquidGlassTabItemStyle
  /// .selectedColor] when that color is a **distinct accent**; when the
  /// style gives it no accent (`selectedColor == unselectedColor`) the
  /// selected cell is just content and follows the adaptive color too.
  final bool adaptive;

  const LiquidGlassNavTabCell({
    super.key,
    required this.item,
    required this.selected,
    this.underGlass = 0,
    this.style = const LiquidGlassTabItemStyle(),
    this.adaptive = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color = style.colorFor(selected: selected);
    // The adaptive content color arrives through IconTheme (animated
    // every frame of a palette flip by the lens / animated bar). The
    // selected cell joins in only when the style gives it no distinct
    // accent — identical selected/unselected colors mean "just content";
    // a distinct selectedColor is a deliberate accent and stays pinned.
    if (adaptive &&
        (!selected || style.selectedColor == style.unselectedColor)) {
      final Color? content = IconTheme.of(context).color;
      if (content != null) color = content;
    }
    final double glass = underGlass.clamp(0.0, 1.0);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildLiquidGlassNavGlyph(
            context,
            item,
            color: color,
            size: style.iconSizeFor(underGlass: glass),
            selected: selected,
            underGlass: glass > 0,
          ),
          if (item.hasLabel) ...[
            SizedBox(height: style.iconLabelGap),
            buildLiquidGlassNavLabel(
              context,
              item,
              color: color,
              fontSize: style.labelFontSizeFor(underGlass: glass),
              fontWeight: style.fontWeightFor(selected: selected),
              selected: selected,
              underGlass: glass > 0,
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
  final LiquidGlassTabBarLayout layout;

  /// Icon/label styling for every cell.
  final LiquidGlassTabItemStyle itemStyle;

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

  /// How much glass, `0`–`1`, sits over the cells rendering selected:
  /// the moving glass pill's presence on the inside-the-pill layer
  /// (only what the pill covers is visible there), easing to `0` as the
  /// landed pill sheds into the static rest pill. `0` — the default —
  /// when nothing over the selection is glass: then selected cells keep
  /// the shared sizes and differ by color/weight alone.
  final double selectedUnderGlass;

  /// Forwarded to every [LiquidGlassNavTabCell]: cells follow the
  /// ambient adaptive content color instead of the style's fixed colors.
  final bool adaptive;

  const NavBarIconRow({
    super.key,
    required this.items,
    required this.layout,
    this.itemStyle = const LiquidGlassTabItemStyle(),
    this.selectedIndex,
    this.forceSelected = false,
    this.forceUnselected = false,
    this.selectedUnderGlass = 0,
    this.adaptive = false,
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
                underGlass: (forceSelected ||
                        (!forceUnselected && i == selectedIndex))
                    ? selectedUnderGlass
                    : 0,
                style: itemStyle,
                adaptive: adaptive,
              ),
            ),
        ],
      ),
    );
  }
}
