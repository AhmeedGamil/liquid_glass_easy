import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'responsive.dart';

/// Renders a demo the way its size class wants it.
///
/// On a phone the demo IS the page — full-bleed, nothing around it. On a
/// desktop it sits in a phone-shaped frame, because every one of these demos
/// is a mobile UI: a bottom nav bar stretched across a 1900px window reads as
/// broken rather than as responsive.
///
/// The frame is not decoration. It overrides the `MediaQuery` its child sees,
/// so a demo asking for `MediaQuery.sizeOf(context)` gets the **frame's** size
/// and lays out for the box it actually occupies. Without that a framed demo
/// would believe it was on a desktop and pick desktop layouts inside a 412px
/// box.
class DemoFrame extends StatelessWidget {
  final Widget child;

  static const double frameWidth = 412;
  static const double _frameHeight = 880;
  static const double _frameRadius = 34;

  const DemoFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 40).clamp(360.0, _frameHeight)
            : _frameHeight;
        final Size framed = Size(frameWidth, h);

        return Container(
          width: framed.width,
          height: framed.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_frameRadius),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000), blurRadius: 52, spreadRadius: -10),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_frameRadius),
                child: MediaQuery(
                  // The demo's world is the frame, not the browser window.
                  data: MediaQuery.of(context).copyWith(
                    size: framed,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: SizedBox.fromSize(size: framed, child: child),
                ),
              ),
              // Drawn over the clip: the glass would otherwise paint across it.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_frameRadius),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A demo plus the docs around it.
///
/// Two layouts, one breakpoint:
///
///  * **compact** — the demo takes the whole viewport under a slim title bar.
///    On a phone the demo is the point; prose can wait.
///  * **medium / expanded** — a two-column split: what the thing is and how to
///    write it on the left, the running demo framed on the right. The desktop
///    window is filled with something useful instead of letterboxing a phone.
///
/// `embedded` strips all of it and renders only the demo, for the docs site to
/// drop into an `<iframe>` where the surrounding page already provides context.
class DemoScaffold extends StatelessWidget {
  final String title;
  final String blurb;

  /// The snippet that produces what is on screen. Selectable, and copyable.
  final String code;
  final Widget demo;
  final bool embedded;
  final VoidCallback? onBack;

  const DemoScaffold({
    super.key,
    required this.title,
    required this.blurb,
    required this.code,
    required this.demo,
    this.embedded = false,
    this.onBack,
  });

  static const Color _bg = Color(0xFF0B0B12);

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return ColoredBox(color: _bg, child: demo);
    }

    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = ScreenClass.of(constraints.maxWidth);
          return screen.isCompact
              ? _compact(context)
              : _wide(context, screen);
        },
      ),
    );
  }

  // ── phone: bar on top, demo owns the rest ──────────────────────────
  Widget _compact(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _Bar(title: title, onBack: onBack),
          Expanded(child: demo),
        ],
      ),
    );
  }

  // ── desktop: docs left, framed demo right ──────────────────────────
  Widget _wide(BuildContext context, ScreenClass screen) {
    final double pad = pagePadding(screen);
    return SafeArea(
      child: Column(
        children: [
          _Bar(title: title, onBack: onBack),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _DocsColumn(blurb: blurb, code: code),
                      ),
                      SizedBox(width: screen.isExpanded ? 56 : 32),
                      DemoFrame(child: demo),
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

/// The left column on desktop: what it is, and the code that makes it.
class _DocsColumn extends StatelessWidget {
  final String blurb;
  final String code;

  const _DocsColumn({required this.blurb, required this.code});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            blurb,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          CodeBlock(code: code),
        ],
      ),
    );
  }
}

/// A selectable, copyable code sample.
///
/// Selectable on purpose: a docs page whose code cannot be copied is a
/// screenshot with extra steps.
class CodeBlock extends StatelessWidget {
  final String code;
  const CodeBlock({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _CopyButton(code: code),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
                  color: Color(0xFFD5D5E6),
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String code;
  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.code));
        if (!mounted) return;
        setState(() => _done = true);
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (mounted) setState(() => _done = false);
      },
      icon: Icon(_done ? Icons.check_rounded : Icons.copy_rounded, size: 15),
      label: Text(_done ? 'Copied' : 'Copy',
          style: const TextStyle(fontSize: 12.5)),
      style: TextButton.styleFrom(
        foregroundColor: _done ? const Color(0xFF34D399) : Colors.white60,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const _Bar({required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              tooltip: 'All demos',
            )
          else
            const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
