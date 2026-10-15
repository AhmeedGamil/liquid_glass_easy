import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'apple_match_tuning.dart';

/// Whether Apple's own controls can be shown live: iOS and macOS, through
/// cupertino_native. Elsewhere the Apple band is an iOS screenshot.
bool get kNativeApple =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// The two rows every Apple Match scene shows, top to bottom.
enum Band {
  /// Apple's own control: live through cupertino_native on iOS and macOS,
  /// a screenshot of it from the iOS simulator everywhere else.
  apple,

  /// The tuned component from apple_match/.
  match;

  String get caption => switch (this) {
        Band.apple =>
          kNativeApple ? 'APPLE  (native)' : 'APPLE  (iOS screenshot)',
        Band.match => 'TUNED  (apple_match)',
      };
}

/// What sits behind a scene's controls.
enum Backdrop {
  page('Plain page'),
  photo('Photo'),
  stripes('Stripes');

  const Backdrop(this.label);

  final String label;
}

// The plain page behind Apple's controls, read off the reference
// screenshots: every page shot, light and dark, is this one flat colour.
const Color kPageLight = Color(0xFFFEF7FF);
const Color kPageDark = Color(0xFF141118);

/// The size of one band of the iOS reference screenshots, in logical
/// pixels (a third of an iPhone 17 Pro screen).
const Size kReferenceBand = Size(402, 291.3);

/// [child] laid out on a [kReferenceBand]-sized stage, centred in the
/// band and clipped to it, exactly as the reference screenshot is drawn: a
/// backdrop fitted here crops and zooms the same as Apple's.
Widget referenceStage(Widget child) => ClipRect(
      child: OverflowBox(
        minWidth: kReferenceBand.width,
        maxWidth: kReferenceBand.width,
        minHeight: kReferenceBand.height,
        maxHeight: kReferenceBand.height,
        child: child,
      ),
    );

/// Splits the area into two equal bands and builds each band's controls
/// with [builder]. Where Apple's controls cannot run ([kNativeApple] is
/// false) the top band shows the iOS screenshot named [reference] instead.
class AppleMatchBands extends StatelessWidget {
  const AppleMatchBands({
    super.key,
    required this.backdrop,
    required this.reference,
    required this.builder,
    this.photo = 'mountain.jpg',
    this.hostedMatch,
  });

  final Backdrop backdrop;

  /// The scene name of the reference screenshot, e.g. `buttons_photo`.
  final String reference;
  final String photo;
  final Widget Function(BuildContext context, Band band) builder;

  /// Builds the tuned band as its own glass host, outside the shared view,
  /// over [backdrop]: for a control that sets up its own views, like the
  /// tab bar's glass pill. [builder] is not used for that band when set.
  final Widget Function(BuildContext context, Widget backdrop)? hostedMatch;

  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = backdrop == Backdrop.page && !dark
        ? const Color(0x99000000)
        : const Color(0xE6FFFFFF);
    final Widget backdropStage =
        referenceStage(_BandBackdrop(kind: backdrop, photo: photo));
    // Apple's band: the live control over the same backdrop, or its
    // screenshot where it cannot run.
    final Widget shot = kNativeApple
        ? backdropStage
        : _ReferenceShot(
            'assets/apple_match/reference/'
            '${AppleMatchTuning.version.folder}/${reference}_'
            '${dark ? 'dark' : 'light'}.jpg',
          );
    final Widget appleControl = kNativeApple
        ? referenceStage(Center(child: builder(context, Band.apple)))
        : const SizedBox.shrink();
    Widget captioned(Band band, Widget child) => Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              left: 10,
              top: 6,
              child: _Caption(band.caption, ink: ink),
            ),
          ],
        );

    // The tuned band hosts itself: the screenshot needs no glass view, and
    // each band keeps exactly half the height.
    final hosted = hostedMatch;
    if (hosted != null) {
      return Column(
        children: [
          Expanded(
            child: captioned(
              Band.apple,
              Stack(fit: StackFit.expand, children: [shot, appleControl]),
            ),
          ),
          Expanded(
            child: captioned(
              Band.match,
              referenceStage(
                hosted(context, _BandBackdrop(kind: backdrop, photo: photo)),
              ),
            ),
          ),
        ],
      );
    }

    return LiquidGlassView(
      backgroundWidget: Column(
        children: [
          Expanded(child: shot),
          Expanded(child: backdropStage),
        ],
      ),
      child: Column(
        children: [
          for (final Band band in Band.values)
            Expanded(
              child: captioned(
                band,
                band == Band.apple
                    ? appleControl
                    : Center(child: builder(context, band)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: ink,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        shadows: const [Shadow(color: Color(0x40000000), blurRadius: 3)],
      ),
    );
  }
}

/// The iOS screenshot at its true logical size, centred and clipped, so
/// Apple's control is drawn at the size it has on an iPhone.
class _ReferenceShot extends StatelessWidget {
  const _ReferenceShot(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return referenceStage(
      Image.asset(
          asset,
          width: kReferenceBand.width,
          height: kReferenceBand.height,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          // No screenshot for this release yet: say which file to add.
          errorBuilder: (context, error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No reference yet.\nAdd ${asset.substring('assets/'.length)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0x99888888), fontSize: 13),
              ),
            ),
          ),
        ),
    );
  }
}

class _BandBackdrop extends StatelessWidget {
  const _BandBackdrop({required this.kind, required this.photo});

  final Backdrop kind;
  final String photo;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: switch (kind) {
        Backdrop.page => ColoredBox(
            color: dark ? kPageDark : kPageLight,
            child: const SizedBox.expand(),
          ),
        Backdrop.photo => Image.asset(
            'assets/apple_match/$photo',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        Backdrop.stripes => const SizedBox.expand(
            child: CustomPaint(painter: _Stripes()),
          ),
      },
    );
  }
}

class _Stripes extends CustomPainter {
  const _Stripes();

  static const List<Color> _colors = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFFFFFF),
    Color(0xFF1C1C1E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const double band = 18;
    final Paint p = Paint();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.5);
    final double reach = size.longestSide;
    int i = 0;
    for (double x = -reach; x < reach; x += band, i++) {
      p.color = _colors[i % _colors.length];
      canvas.drawRect(Rect.fromLTWH(x, -reach, band, reach * 2), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
