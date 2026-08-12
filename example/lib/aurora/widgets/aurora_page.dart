import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';
import 'aurora_motion.dart';

/// The glass bar floats over the body rather than pushing it up, so every
/// scrolling page has to end above it on its own.
///
/// height 66 + bottom margin 22 + breathing room.
const double kNavClearance = 118;

/// The gutter every page shares. Content that changes its left edge from
/// page to page reads as three apps stitched together.
const double kGutter = 20;

/// Page padding: the status bar on top, the floating bar's clearance plus
/// the home indicator underneath.
EdgeInsets auroraPagePadding(BuildContext context) {
  final view = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    kGutter,
    view.top + 14,
    kGutter,
    kNavClearance + view.bottom,
  );
}

/// The header every page opens with: a quiet overline, a large title, and
/// an optional trailing control on the title's baseline.
class PageTitle extends StatelessWidget {
  final String overline;
  final String title;
  final Widget? trailing;

  /// Paints the title with the accent gradient — reserved for Today, so
  /// the treatment still means something.
  final bool gradient;

  const PageTitle({
    super.key,
    required this.overline,
    required this.title,
    this.trailing,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Reveal(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overline, style: AuroraText.caps(p)),
                const SizedBox(height: 8),
                if (gradient)
                  GradientText(
                    title,
                    style: AuroraText.display(p),
                    colors: [p.textPrimary, p.accent, p.textPrimary],
                  )
                else
                  Text(title, style: AuroraText.display(p)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
