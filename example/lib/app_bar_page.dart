import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'demo_kit.dart';

// =============================================================
// App Bar — LiquidGlassAppBar over a page that scrolls under it.
//
//   flutter run -t lib/app_bar_page.dart
//
// The bar is a floating glass capsule with leading, title and actions
// slots, sitting in a LiquidGlassScaffold that provides the view it
// samples. Scroll the tiles and watch them pass through it. The panel
// flips the title alignment and the number of actions live.
// =============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBarApp());
}

class _AppBarApp extends StatelessWidget {
  const _AppBarApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const AppBarPage(),
    );
  }
}

class AppBarPage extends StatefulWidget {
  const AppBarPage({super.key});

  @override
  State<AppBarPage> createState() => _AppBarPageState();
}

class _AppBarPageState extends State<AppBarPage> {
  bool _center = true;
  int _actions = 2;
  String _note = '';

  static const List<IconData> _actionIcons = <IconData>[
    Icons.search_rounded,
    Icons.tune_rounded,
    Icons.more_vert_rounded,
  ];

  static const List<Color> _tileColors = <Color>[
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    final double barWidth =
        (MediaQuery.sizeOf(context).width - 28).clamp(280.0, 520.0);
    return LiquidGlassScaffold(
      appBar: LiquidGlassAppBar(
        width: barWidth,
        height: 54,
        centerTitle: _center,
        title: const Text('Library'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          for (int i = 0; i < _actions; i++)
            IconButton(
              icon: Icon(_actionIcons[i], color: Colors.white),
              onPressed: () => setState(() => _note = 'action ${i + 1}'),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DemoBackdrop(seed: 3),
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 96, 14, 200),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: 24,
            itemBuilder: (BuildContext context, int i) {
              final Color c = _tileColors[i % _tileColors.length];
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
          DemoPanel(
            title: 'LiquidGlassAppBar${_note.isEmpty ? '' : '  ·  $_note'}',
            children: <Widget>[
              DemoChips<bool>(
                values: const <bool>[true, false],
                selected: _center,
                label: (bool v) => v ? 'centred title' : 'leading title',
                onChanged: (bool v) => setState(() => _center = v),
              ),
              const SizedBox(height: 8),
              DemoChips<int>(
                values: const <int>[0, 1, 2, 3],
                selected: _actions,
                label: (int n) => n == 0 ? 'no actions' : '$n action${n == 1 ? '' : 's'}',
                onChanged: (int n) => setState(() => _actions = n),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
