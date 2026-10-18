import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this showcase can be launched directly with:
///   flutter run -t lib/showcases/video_library_page.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassShaders.ensureLoaded();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const VideoLibraryPage(),
    ),
  );
}

// =============================================================
// A video library: a two-column grid of video cards that runs under
// everything, with the glass floating over it.
//
//   • the top controls (profile, source, search + more, the video filter,
//     download + sort) are the members of ONE LiquidGlassBlender, so the
//     five pieces cost one glass pass. Press one and it swells; pressed
//     against a neighbour it flows into it;
//   • the bottom is the package's tab bar with its moving pill, and a
//     detached search circle;
//   • the switch under the header picks how the chrome shares the
//     backdrop: Batch (the default) puts it on one shared read, Layer
//     blurs it once under all of it.
// =============================================================

const Color _kPage = Color(0xFF0E1116);
const Color _kCard = Color(0xFF161A21);
const Color _kInk = Colors.white;
const Color _kSub = Color(0xB3FFFFFF);

class VideoLibraryPage extends StatefulWidget {
  const VideoLibraryPage({super.key});

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  static const double _barHeight = 64;
  static const double _edge = 18;

  /// Every glass surface's blur: what the layer or the batch shares.
  static const double _blur = 6;

  int _tab = 4;
  bool _layer = false;

  static final List<LiquidGlassTabBarItem> _tabs = [
    const LiquidGlassTabBarItem(
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
      label: 'Video',
    ),
    const LiquidGlassTabBarItem(
      icon: Icons.image_outlined,
      selectedIcon: Icons.image_rounded,
      label: 'Gallery',
    ),
    const LiquidGlassTabBarItem(
      icon: Icons.slideshow_outlined,
      selectedIcon: Icons.slideshow_rounded,
      label: 'Feed',
    ),
    const LiquidGlassTabBarItem(
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      label: 'Forum',
    ),
    const LiquidGlassTabBarItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: 'Local',
    ),
  ];

  LiquidGlassStyle _glass(double radius) => LiquidGlassStyle(
        shape: LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: radius,
        ),
        color: const Color(0x33000000),
        blur: _blur,
      );

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final double width = MediaQuery.sizeOf(context).width;

    return Theme(
      data: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      child: Scaffold(
        backgroundColor: _kPage,
        body: LiquidGlassScaffold(
          backgroundColor: _kPage,
          layer: _layer,
          bottomNavigationBarActionMargin: _edge,
          body: _VideoGrid(
            top: pad.top + _Header.height + 16,
            bottom: pad.bottom + _barHeight + 40,
          ),
          appBar: _Header(style: _glass),
          lenses: [
            Positioned(
              top: pad.top + _Header.height + 10,
              right: _edge,
              child: _ModeSwitch(
                layer: _layer,
                onChanged: (v) => setState(() => _layer = v),
              ),
            ),
          ],
          bottomNavigationBar: LiquidGlassTabBar(
            items: _tabs,
            selectedIndex: _tab,
            onChanged: (i) => setState(() => _tab = i),
            // The capsule leaves the right end of the line to search.
            width: width - 2 * _edge - _barHeight - 12,
            height: _barHeight,
            itemPadding: 4,
            alignment: Alignment.bottomLeft,
            margin: const EdgeInsets.only(left: _edge, bottom: 12),
            pillStyle:
                const LiquidGlassTabPillStyle(mode: LiquidGlassPillMode.both),
            itemStyle: const LiquidGlassTabItemStyle(
              selectedColor: Color(0xFF4DA3FF),
              unselectedColor: _kInk,
            ),
          ),
          bottomNavigationBarAction: LiquidGlassTabBarAction(
            icon: Icons.search_rounded,
            size: _barHeight,
            foregroundColor: _kInk,
            style: LiquidGlassTabBarAction.defaultStyle.copyWith(blur: _blur),
            onTap: () {},
          ),
        ),
      ),
    );
  }
}

/// Layer or Batch, on a plain chip so it is not glass of its own.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.layer, required this.onChanged});

  final bool layer;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              layer ? 'Layer' : 'Batch',
              style: const TextStyle(
                color: _kInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(value: layer, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The header — five controls in two rows, one blender.
// ════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.style});

  final LiquidGlassStyle Function(double radius) style;

  static const double _ctrl = 52;
  static const double _rowGap = 14;
  static const double _left = 18;
  static const double _right = 18;
  static const double height = _ctrl * 2 + _rowGap;

  static const LiquidGlassTouch _press = LiquidGlassTouch.flexing(
    LiquidGlassFlex.subtle(),
  );

  Widget _member({
    double? left,
    double? right,
    required double top,
    required double width,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      width: width,
      height: _ctrl,
      child: LiquidGlassLens(
        style: style(_ctrl / 2),
        touch: _press,
        child: child,
      ),
    );
  }

  Widget _icon(IconData icon) => Icon(icon, color: _kInk, size: 26);

  Widget _label(String text, {IconData? lead, IconData? trail}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (lead != null) ...[_icon(lead), const SizedBox(width: 10)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kInk,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trail != null) ...[const SizedBox(width: 6), _icon(trail)],
        ],
      ),
    );
  }

  Widget _pair(IconData a, IconData b) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [_icon(a), _icon(b)],
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double second = _ctrl + _rowGap;
        return SizedBox(
          width: constraints.maxWidth,
          height: height,
          child: LiquidGlassBlender(
            smoothness: 20,
            style: style(_ctrl / 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _member(
                  left: _left,
                  top: 0,
                  width: _ctrl,
                  child: _icon(Icons.account_circle_rounded),
                ),
                _member(
                  left: _left + _ctrl + 12,
                  top: 0,
                  width: 168,
                  child: _label('On this device'),
                ),
                _member(
                  right: _right,
                  top: 0,
                  width: 104,
                  child: _pair(Icons.search_rounded, Icons.more_vert_rounded),
                ),
                _member(
                  left: _left,
                  top: second,
                  width: 168,
                  child: _label(
                    'All videos',
                    lead: Icons.video_collection_outlined,
                    trail: Icons.arrow_drop_down_rounded,
                  ),
                ),
                _member(
                  right: _right,
                  top: second,
                  width: 104,
                  child: _pair(
                    Icons.arrow_downward_rounded,
                    Icons.sort_rounded,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  The page behind the glass — plain video cards, no glass in here.
// ════════════════════════════════════════════════════════════════

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({required this.top, required this.bottom});

  final double top;
  final double bottom;

  static const List<(String, String)> _videos = [
    ('VID-20220910-WA0002', '02:51'),
    ('VID-20220714-WA0005', '00:12'),
    ('VID-20220714-WA0003', '01:00'),
    ('VID-20220713-WA0023', '00:30'),
    ('VID-20220713-WA0020', '01:00'),
    ('Video_20221110_by_VideoShow', '01:25'),
    ('VID-20220611-WA0011', '03:07'),
    ('Screen_recording_0412', '00:48'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(18, top, 18, bottom),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: 120,
      itemBuilder: (context, i) {
        final (String title, String duration) = _videos[i % _videos.length];
        return _VideoCard(id: i, title: title, duration: duration);
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.id,
    required this.title,
    required this.duration,
  });

  final int id;
  final String title;
  final String duration;

  static const List<String> _photos = [
    'assets/feed/flower.jpg',
    'assets/feed/mountain.jpg',
  ];

  Widget _thumbnail() {
    // Every third card a photo, the rest a coloured frame, so the glass
    // always has light and dark passing under it.
    if (id % 3 == 0) {
      return Image.asset(
        _photos[(id ~/ 3) % _photos.length],
        fit: BoxFit.cover,
        cacheWidth: 400,
      );
    }
    final double hue = (id * 53.0) % 360;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.7, 0.55).toColor(),
            HSLColor.fromAHSL(1, (hue + 60) % 360, 0.6, 0.22).toColor(),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_creation_outlined,
            color: Color(0x66FFFFFF), size: 42),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumbnail(),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                color: _kInk, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              duration,
                              style: const TextStyle(
                                color: _kInk,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Download',
                          style: TextStyle(color: _kSub, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.more_vert_rounded,
                            color: _kSub, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
