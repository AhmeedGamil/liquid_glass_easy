import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **App bar** — a floating capsule with the page running under it.
///
/// [LiquidGlassAppBar] is one lens wrapped around `leading`, `title` and
/// `actions`. It refracts your *page*, which is the one thing it needs from
/// you on Skia and the web: an ancestor [LiquidGlassView] whose
/// `backgroundWidget` is that page. Here the scrolling feed IS the background,
/// so the bar bends the rows as they pass beneath it.
///
/// ## Why this one captures every frame
///
/// The content moves. `realTimeCapture` stays at its default `true` because
/// the whole effect is the feed sliding under the glass — freezing the
/// snapshot would leave the bar refracting a page that is no longer there.
/// This is the case that earns the per-frame cost.
///
/// On Impeller none of it is captured: the bar reads the live backdrop and the
/// view is only there for the web.
class AppBarDemo extends StatefulWidget {
  const AppBarDemo({super.key});

  @override
  State<AppBarDemo> createState() => _AppBarDemoState();
}

class _AppBarDemoState extends State<AppBarDemo> {
  bool _centered = true;
  int _unread = 3;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassView(
      // The page under the bar is what moves, so it is re-captured per frame.
      pixelRatio: 1,
      backgroundWidget: const _Feed(),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: LiquidGlassAppBar(
                    width: 356,
                    centerTitle: _centered,
                    leading: const Icon(Icons.menu_rounded),
                    title: const Text('Library'),
                    actions: [
                      const Icon(Icons.search_rounded),
                      GestureDetector(
                        onTap: () => setState(() => _unread = 0),
                        child: Badge(
                          isLabelVisible: _unread > 0,
                          label: Text('$_unread'),
                          child: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                // On a panel, not bare: the feed runs underneath these, and
                // a hint you cannot read is not a hint.
                child: DemoPanel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DemoHint('Scroll the feed — the rows bend as they '
                          'pass under the bar'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          DemoChip(
                            label: 'centered title',
                            selected: _centered,
                            onTap: () => setState(() => _centered = true),
                          ),
                          DemoChip(
                            label: 'leading title',
                            selected: !_centered,
                            onTap: () => setState(() => _centered = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The page the bar refracts. Rows with hard edges on purpose: a straight line
/// crossing the glass visibly bows, and that is the evidence of the bend.
class _Feed extends StatelessWidget {
  const _Feed();

  static const List<(String, String, Color)> _rows = [
    ('Midnight Drive', 'Nocturne · 4:12', Color(0xFF7C5CFF)),
    ('Paper Lanterns', 'Hazel Fox · 3:38', Color(0xFFFF5C8A)),
    ('Low Tide', 'Ana Reyes · 5:02', Color(0xFF2DD4BF)),
    ('Copper Sun', 'The Vale · 2:57', Color(0xFFFFB020)),
    ('Glass House', 'Sonder · 4:44', Color(0xFF4FB3FF)),
    ('Slow Static', 'Marden · 3:21', Color(0xFFA78BFA)),
    ('Northbound', 'Ivy Lake · 4:05', Color(0xFF34D399)),
    ('Afterimage', 'Kestrel · 3:50', Color(0xFFF97316)),
    ('Harbour Lights', 'Wren', Color(0xFFEF4444)),
    ('Long Exposure', 'Bell & Co', Color(0xFF22D3EE)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackdrop.dusk(),
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 96, 16, 150),
          itemCount: _rows.length,
          itemBuilder: (context, i) {
            final (title, sub, accent) = _rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(sub,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.play_arrow_rounded,
                      color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
