import 'package:flutter/material.dart';

// Apple's own controls as platform views, used on iOS and macOS only.
import 'package:cupertino_native/cupertino_native.dart';

import '../apple_match_bands.dart';
import '../apple_slider.dart';

const double _width = 300;

/// Two sliders per band, at different values.
class SliderScene extends StatefulWidget {
  const SliderScene({super.key, required this.backdrop});

  final Backdrop backdrop;

  @override
  State<SliderScene> createState() => _SliderSceneState();
}

class _SliderSceneState extends State<SliderScene> {
  final Map<Band, List<double>> _values = {
    for (final Band b in Band.values) b: [0.6, 0.15],
  };

  @override
  Widget build(BuildContext context) {
    return AppleMatchBands(
      backdrop: widget.backdrop,
      reference: 'slider_${widget.backdrop.name}',
      builder: (context, band) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(height: 28),
            SizedBox(
              width: _width + 100,
              height: 60,
              child: Center(child: _slider(band, i)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider(Band band, int i) {
    final double v = _values[band]![i];
    void set(double x) => setState(() => _values[band]![i] = x);
    return switch (band) {
      Band.apple => SizedBox(
          width: _width,
          child: CNSlider(value: v, onChanged: set, height: 44),
        ),
      Band.match => AppleSlider(value: v, onChanged: set, width: _width),
    };
  }
}
