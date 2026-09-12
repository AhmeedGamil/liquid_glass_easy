import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// Scroll Edge — LiquidGlassScrollEdge over a photo journal.
//
//   flutter run -t lib/scroll_edge_page.dart
//
// A travel journal — edge-to-edge photos with text entries between them
// — under a glass header, with a scroll-edge band at each end of the
// page. The band is a tint fading in from the edge plus one blur pass,
// feathered so it meets the sharp photos without a seam; it never blocks
// a touch. The panel switches soft and hard, and drives blur and height.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ScrollEdgeApp());
}

class _ScrollEdgeApp extends StatelessWidget {
  const _ScrollEdgeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const ScrollEdgePage(),
    );
  }
}

class ScrollEdgePage extends StatefulWidget {
  const ScrollEdgePage({super.key});

  @override
  State<ScrollEdgePage> createState() => _ScrollEdgePageState();
}

class _ScrollEdgePageState extends State<ScrollEdgePage> {
  LiquidGlassScrollEdgeStyle _style = LiquidGlassScrollEdgeStyle.soft;
  double _blur = 6;
  double _height = 130;

  static const Color _tint = Color(0xA6000000);

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    return LiquidGlassScaffold(
      appBar: const DemoHeader(title: 'Scroll Edge'),
      body: const _Journal(),
      lenses: <Widget>[
        // Top band, behind the header: the photos dim as they slide
        // under the title, so it stays readable.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + _height,
          child: LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.top,
            style: _style,
            blur: _blur,
            color: _tint,
          ),
        ),
        // Bottom band, under the control panel.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: pad.bottom + _height + 80,
          child: LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.bottom,
            style: _style,
            blur: _blur,
            color: _tint,
          ),
        ),
        DemoPanel(
          title: 'LiquidGlassScrollEdge',
          children: <Widget>[
            DemoChips<LiquidGlassScrollEdgeStyle>(
              values: LiquidGlassScrollEdgeStyle.values,
              selected: _style,
              label: (LiquidGlassScrollEdgeStyle s) => s.name,
              onChanged: (LiquidGlassScrollEdgeStyle s) =>
                  setState(() => _style = s),
            ),
            const SizedBox(height: 6),
            DemoSlider(
              label: 'blur',
              value: _blur,
              min: 0,
              max: 16,
              onChanged: (double v) => setState(() => _blur = v),
            ),
            DemoSlider(
              label: 'height',
              value: _height,
              min: 60,
              max: 220,
              onChanged: (double v) => setState(() => _height = v),
            ),
          ],
        ),
      ],
    );
  }
}

/// The page: photos and journal entries, alternating, ending on a photo.
class _Journal extends StatelessWidget {
  const _Journal();

  static const Color _paper = Color(0xFF14171D);
  static const Color _ink = Color(0xFFE8E6EF);

  static const List<String> _entries = <String>[
    'We started in the south, island-hopping out of Krabi. The longtail '
        'boats drop you straight onto sandbars that disappear at high '
        'tide — water so clear the boats look like they are floating on '
        'glass.',
    'Up north near Chiang Mai we spent a day at an elephant sanctuary. '
        'Feeding them bananas was the highlight — they are so gentle, and '
        'so hungry. Then a green forest, and nothing to do but take it in.',
    'Back in the city we ate our way through the night markets. Mango '
        'sticky rice from a cart, boat noodles for pennies, and the best '
        'pad kra pao of the trip from a stall with three plastic stools.',
    'The temples deserve a slow morning. Wat Arun at sunrise before the '
        'crowds, all gold and porcelain in the early light, then down the '
        'river on the public ferry like locals.',
    'Last stop was a quiet beach town where nothing happened, which was '
        'the point. Hammocks, coconut shakes, and one final sunset.',
  ];

  static const List<String> _seeds = <String>[
    'krabi-longtail',
    'chiangmai-elephant',
    'bangkok-alley',
    'wat-arun',
    'beach-town',
    'last-sunset',
  ];

  static const int _photos = 12;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[
      for (int i = 0; i < _photos * 2 - 1; i++)
        i.isEven
            ? _Photo(index: i ~/ 2)
            : _Entry(text: _entries[(i ~/ 2) % _entries.length]),
    ];
    return ColoredBox(
      color: _paper,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (BuildContext context, int i) => items[i],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  final String text;
  const _Entry({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      child: Text(
        text,
        style: const TextStyle(
          color: _Journal._ink,
          fontSize: 17,
          height: 1.45,
          letterSpacing: -0.2,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

/// One square photo, kept alive while scrolled away so it never re-fetches.
class _Photo extends StatefulWidget {
  final int index;
  const _Photo({required this.index});

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int round = widget.index ~/ _Journal._seeds.length;
    final String base = _Journal._seeds[widget.index % _Journal._seeds.length];
    final String seed = round == 0 ? base : '$base-$round';
    return AspectRatio(
      aspectRatio: 1,
      child: Image.network(
        'https://picsum.photos/seed/$seed/720/720',
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (_, Widget child, ImageChunkEvent? progress) =>
            progress == null ? child : DemoBackdrop(seed: widget.index),
        errorBuilder: (_, __, ___) => DemoBackdrop(seed: widget.index),
      ),
    );
  }
}
