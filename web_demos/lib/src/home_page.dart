import 'package:flutter/material.dart';

import 'demo_registry.dart';
import 'demo_shell.dart';
import 'responsive.dart';

/// The demo index.
///
/// This app is the interactive island of the docs site, so its landing page
/// is a list of demos and nothing else — the prose that used to live here is
/// real HTML now, in `docs_site/`.
///
/// One column on a phone, a grid once there is width for it — the cards
/// themselves are identical, only the axis count changes.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = ScreenClass.of(constraints.maxWidth);
          final double pad = pagePadding(screen);
          final int columns = screen.pick(compact: 1, medium: 2, expanded: 3);

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(pad, 28, pad, 48),
                  children: [
                    _Masthead(screen: screen),
                    SizedBox(height: screen.isCompact ? 28 : 40),
                    GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      // Cards are wider than tall on desktop, squarer on a
                      // phone where a single column is very wide.
                      childAspectRatio:
                          screen.pick(compact: 2.1, medium: 1.25, expanded: 1.1),
                      children: [
                        for (final demo in kDemos) _DemoCard(demo: demo),
                      ],
                    ),
                    const SizedBox(height: 34),
                    const _Footnote(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  final ScreenClass screen;
  const _Masthead({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIQUID GLASS EASY',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Live demos',
          style: TextStyle(
            color: Colors.white,
            fontSize: screen.pick(compact: 32, medium: 40, expanded: 46),
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Real glass, running in your browser — not a recording. Press it, '
            'drag it, scroll under it.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 15.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoCard extends StatefulWidget {
  final DemoEntry demo;
  const _DemoCard({required this.demo});

  @override
  State<_DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<_DemoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DemoScaffold(
              title: widget.demo.title,
              blurb: widget.demo.blurb,
              code: widget.demo.code,
              demo: Builder(builder: widget.demo.builder),
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF1A1A26) : const Color(0xFF14141F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hover ? 0.22 : 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.demo.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  // First paragraph only: the card is a door, not the room.
                  widget.demo.blurb.split('\n\n').first,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'These run on Skia — the web never uses Impeller. Every demo that needs '
      'to refract real content is wrapped in a LiquidGlassView so it does not '
      'fall back to a plain blur.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 12.5,
        height: 1.5,
      ),
    );
  }
}
