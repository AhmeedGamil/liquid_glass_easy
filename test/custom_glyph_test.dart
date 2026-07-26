import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// Verifies the custom-content slots: LiquidGlassTabBarItem.iconBuilder
// (every nav/tab tier), LiquidGlassButton.child and
// LiquidGlassTabBarAction.child.
//
// The contract is that custom content receives the SAME resolved color a
// plain Icon would have — so it follows the selected/unselected palette
// and the moving pill's reveal — and that it can never size its host.

const Color _accent = Colors.red; // distinct selected color

/// A stand-in for an SVG/PNG: a box painted in whatever color the host
/// hands it, tagged so a test can find every copy of one tab's glyph
/// (the reveal tiers draw each tab twice).
class _Glyph extends StatelessWidget {
  final Color color;
  final double size;
  final String tag;
  const _Glyph({required this.color, required this.size, required this.tag});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: ColoredBox(color: color));
}

LiquidGlassTabBarItem _customItem(String label) =>
    LiquidGlassTabBarItem.custom(
      label: label,
      iconBuilder: (_, i) => _Glyph(color: i.color, size: i.size, tag: label),
    );

Iterable<Color> _glyphColors(WidgetTester tester, String tag) => tester
    .widgetList<_Glyph>(find.byType(_Glyph))
    .where((g) => g.tag == tag)
    .map((g) => g.color);

Widget _navBar({
  required List<LiquidGlassTabBarItem> items,
  LiquidGlassNavPillStyle pillStyle = const LiquidGlassNavPillStyle(),
  double width = 320,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: LiquidGlassBottomNavBar(
          items: items,
          selectedIndex: 0,
          onChanged: (_) {},
          width: width,
          pillStyle: pillStyle,
          itemStyle: const LiquidGlassNavItemStyle(selectedColor: _accent),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('nav bar: iconBuilder replaces the Icon and gets its color',
      (tester) async {
    await tester.pumpWidget(_navBar(items: [
      _customItem('Home'),
      _customItem('Search'),
    ]));
    await tester.pump();

    // A `.custom` item never renders an IconData — the placeholder
    // glyph must not reach the screen.
    expect(find.byType(Icon), findsNothing);

    // Selected cell gets the style's selected color, unselected the
    // unselected one — exactly what a plain Icon would have received.
    expect(_glyphColors(tester, 'Home').single, _accent);
    expect(_glyphColors(tester, 'Search').single,
        const LiquidGlassNavItemStyle().unselectedColor);
  });

  testWidgets('nav bar: IconData items and custom items mix in one bar',
      (tester) async {
    await tester.pumpWidget(_navBar(items: [
      const LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
      _customItem('Search'),
    ]));
    await tester.pump();

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byType(_Glyph), findsOneWidget);
  });

  testWidgets('sliding tier: the builder runs for BOTH reveal layers',
      (tester) async {
    await tester.pumpWidget(_navBar(
      items: [_customItem('Home'), _customItem('Search')],
      pillStyle: const LiquidGlassNavPillStyle(animated: true),
    ));
    await tester.pumpAndSettle();

    // The selected tab is drawn twice — inside the pill (selected color)
    // and outside it (unselected). Custom art must be tinted per layer
    // like an Icon, or the reveal would do nothing.
    expect(_glyphColors(tester, 'Home').toSet(),
        {_accent, const LiquidGlassNavItemStyle().unselectedColor});
  });

  testWidgets('an icon-only custom item renders no label', (tester) async {
    await tester.pumpWidget(_navBar(items: [
      LiquidGlassTabBarItem.custom(
        iconBuilder: (_, i) => _Glyph(color: i.color, size: i.size, tag: 'a'),
      ),
      const LiquidGlassTabBarItem(icon: Icons.search_rounded),
    ]));
    await tester.pump();

    expect(find.byType(_Glyph), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('tab bar honors iconBuilder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassTabBar(
            items: [_customItem('Home'), _customItem('Search')],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(_Glyph), findsNWidgets(2));
  });

  testWidgets('an oversized custom glyph cannot grow its cell',
      (tester) async {
    const double barWidth = 320;
    await tester.pumpWidget(_navBar(
      width: barWidth,
      items: [
        LiquidGlassTabBarItem.custom(
          label: 'Home',
          // Deliberately far larger than the item style's icon size.
          iconBuilder: (_, i) => _Glyph(color: i.color, size: 400, tag: 'Home'),
        ),
        _customItem('Search'),
      ],
    ));
    await tester.pump();

    // The glyph keeps its own 400px layout size but is PAINTED scaled
    // into the icon box, so the box it occupies in the cell stays the
    // item style's icon size and the bar keeps its declared width.
    final double iconSize = const LiquidGlassNavItemStyle().iconSize;
    final Size glyphBox = tester.getSize(find
        .ancestor(
            of: find.byType(_Glyph).first, matching: find.byType(FittedBox))
        .first);
    expect(glyphBox.width, lessThanOrEqualTo(iconSize + 0.01));
    expect(glyphBox.height, lessThanOrEqualTo(iconSize + 0.01));
    expect(
        tester.getSize(find.byType(LiquidGlassBottomNavBar)).width, barWidth);
  });

  testWidgets('button: child replaces the label row and never resizes it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassButton.custom(
            width: 200,
            child: Text('custom'),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('custom'), findsOneWidget);
    final Size size = tester.getSize(find.byType(LiquidGlassButton));
    expect(size.width, 200);
    expect(size.height, 48);
  });

  testWidgets('button: a bare Text in the child inherits foregroundColor',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassButton.custom(
            foregroundColor: _accent,
            child: Text('custom'),
          ),
        ),
      ),
    ));
    await tester.pump();

    final TextStyle style = tester
        .widget<DefaultTextStyle>(find
            .ancestor(
              of: find.text('custom'),
              matching: find.byType(DefaultTextStyle),
            )
            .first)
        .style;
    expect(style.color, _accent);
  });

  testWidgets('tab bar action: child replaces the glyph', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassTabBarAction.custom(child: Text('A')),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(Icon), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(tester.getSize(find.byType(LiquidGlassTabBarAction)),
        const Size(56, 56));
  });
}
