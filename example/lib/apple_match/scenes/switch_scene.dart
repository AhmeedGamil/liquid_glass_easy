import 'package:flutter/material.dart';

// Apple's own controls as platform views, used on iOS and macOS only.
import 'package:cupertino_native/cupertino_native.dart';

import '../apple_match_bands.dart';
import '../apple_switch.dart';

/// An on and an off switch per band.
class SwitchScene extends StatefulWidget {
  const SwitchScene({super.key, required this.backdrop});

  final Backdrop backdrop;

  @override
  State<SwitchScene> createState() => _SwitchSceneState();
}

class _SwitchSceneState extends State<SwitchScene> {
  final Map<Band, List<bool>> _values = {
    for (final Band b in Band.values) b: [true, false],
  };

  @override
  Widget build(BuildContext context) {
    return AppleMatchBands(
      backdrop: widget.backdrop,
      reference: 'switch_${widget.backdrop.name}',
      builder: (context, band) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 40),
            SizedBox(
              width: 100,
              height: 60,
              child: Center(child: _switch(band, i)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _switch(Band band, int i) {
    final bool v = _values[band]![i];
    void set(bool x) => setState(() => _values[band]![i] = x);
    return switch (band) {
      Band.apple => CNSwitch(
          value: v,
          onChanged: set,
          // The plugin otherwise tints with the accent colour; iOS's
          // own default is system green.
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF30D158)
              : const Color(0xFF34C759),
        ),
      Band.match => AppleSwitch(value: v, onChanged: set),
    };
  }
}
