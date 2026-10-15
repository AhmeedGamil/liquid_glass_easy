import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// Apple's own controls as platform views, used on iOS and macOS only.
import 'package:cupertino_native/cupertino_native.dart';

import '../apple_match_bands.dart';
import '../apple_match_tuning.dart';
import '../apple_tab_bar.dart';

const double _width = 370;

/// The centre of Apple's bar in the reference band, measured from the iOS
/// screenshots (the native bar draws at the top of its 90 pt view).
const double _appleCenterY = 134.5;

/// The tabs the bar can show; the `items.length` knob takes the first N.
const List<LiquidGlassTabBarItem> _pool = [
  LiquidGlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
  LiquidGlassTabBarItem(icon: CupertinoIcons.search, label: 'Search'),
  LiquidGlassTabBarItem(
    icon: CupertinoIcons.square_stack_fill,
    label: 'Library',
  ),
  LiquidGlassTabBarItem(
    icon: CupertinoIcons.person_crop_circle_fill,
    label: 'Profile',
  ),
  LiquidGlassTabBarItem(icon: CupertinoIcons.heart_fill, label: 'Favorites'),
  LiquidGlassTabBarItem(icon: CupertinoIcons.gear_alt_fill, label: 'Settings'),
];

/// The same tabs as Apple's SF Symbols, for the native bar.
const List<CNTabBarItem> _nativePool = [
  CNTabBarItem(label: 'Home', icon: CNSymbol('house.fill')),
  CNTabBarItem(label: 'Search', icon: CNSymbol('magnifyingglass')),
  CNTabBarItem(label: 'Library', icon: CNSymbol('square.stack.fill')),
  CNTabBarItem(label: 'Profile', icon: CNSymbol('person.crop.circle.fill')),
  CNTabBarItem(label: 'Favorites', icon: CNSymbol('heart.fill')),
  CNTabBarItem(label: 'Settings', icon: CNSymbol('gearshape.fill')),
];

List<LiquidGlassTabBarItem> get _items => _pool
    .take(AppleMatchTuning.i('tab.itemCount').clamp(1, _pool.length))
    .toList();

/// A four-tab bar with the first tab selected.
class TabBarScene extends StatefulWidget {
  const TabBarScene({super.key, required this.backdrop});

  final Backdrop backdrop;

  @override
  State<TabBarScene> createState() => _TabBarSceneState();
}

class _TabBarSceneState extends State<TabBarScene> {
  final Map<Band, int> _index = {for (final Band b in Band.values) b: 0};

  @override
  Widget build(BuildContext context) {
    return AppleMatchBands(
      backdrop: widget.backdrop,
      reference: 'tabbar_${widget.backdrop.name}',
      photo: 'flower.jpg',
      // The glass pill needs a view of its own, so the tuned band is
      // hosted by the bar itself.
      hostedMatch: (context, backdrop) => AppleTabBar(
        // A new count starts the bar fresh rather than mid-travel.
        key: ValueKey(_items.length),
        items: _items,
        selectedIndex: _index[Band.match]!.clamp(0, _items.length - 1),
        onChanged: (x) => setState(() => _index[Band.match] = x),
        body: backdrop,
        centerY: _appleCenterY,
      ),
      builder: (context, band) => SizedBox(
        width: _width,
        height: 90,
        child: Center(child: _bar(band)),
      ),
    );
  }

  Widget _bar(Band band) {
    final int i = _index[band]!.clamp(0, _items.length - 1);
    void set(int x) => setState(() => _index[band] = x);
    return switch (band) {
      Band.apple => CNTabBar(
          // A new count rebuilds the native bar rather than patching it.
          key: ValueKey(_items.length),
          items: _nativePool.take(_items.length).toList(),
          currentIndex: i,
          onTap: set,
        ),
      Band.match => AppleTabBar(
          items: _items,
          selectedIndex: i,
          onChanged: set,
        ),
    };
  }
}
