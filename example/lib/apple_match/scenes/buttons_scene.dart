import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

// Apple's own controls as platform views, used on iOS and macOS only.
import 'package:cupertino_native/cupertino_native.dart';

import '../apple_glass_button.dart';
import '../apple_match_bands.dart';

const double _height = 44;

/// A regular glass button, a prominent one, a round icon button and a
/// wide one.
class ButtonsScene extends StatelessWidget {
  const ButtonsScene({super.key, required this.backdrop});

  final Backdrop backdrop;

  @override
  Widget build(BuildContext context) {
    return AppleMatchBands(
      backdrop: backdrop,
      reference: 'buttons_${backdrop.name}',
      builder: (context, band) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 120, height: _height, child: _glass(band)),
              const SizedBox(width: 16),
              SizedBox(width: 140, height: _height, child: _prominent(band)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 56, height: 56, child: _round(band)),
              const SizedBox(width: 24),
              SizedBox(width: 200, height: 56, child: _wide(band)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glass(Band band) => switch (band) {
        Band.apple => CNButton(
            label: 'Glass',
            style: CNButtonStyle.glass,
            height: _height,
            onPressed: () {},
          ),
        Band.match => AppleGlassButton(
            label: 'Glass',
            width: 120,
            height: _height,
            onPressed: () {},
          ),
      };

  Widget _prominent(Band band) => switch (band) {
        Band.apple => CNButton(
            label: 'Prominent',
            style: CNButtonStyle.prominentGlass,
            // Without a tint the plugin falls back to the label colour.
            tint: const Color(0xFF0088FF),
            height: _height,
            onPressed: () {},
          ),
        Band.match => AppleGlassButton(
            label: 'Prominent',
            prominent: true,
            width: 140,
            height: _height,
            onPressed: () {},
          ),
      };

  Widget _round(Band band) => switch (band) {
        Band.apple => CNButton.icon(
            icon: const CNSymbol('heart.fill', size: 22),
            size: 56,
            onPressed: () {},
          ),
        Band.match => AppleGlassButton(
            icon: CupertinoIcons.heart_fill,
            height: 56,
            onPressed: () {},
          ),
      };

  Widget _wide(Band band) => switch (band) {
        Band.apple => CNButton(
            label: 'Add to library',
            style: CNButtonStyle.glass,
            height: 56,
            onPressed: () {},
          ),
        Band.match => AppleGlassButton(
            label: 'Add to library',
            width: 200,
            height: 56,
            onPressed: () {},
          ),
      };
}
