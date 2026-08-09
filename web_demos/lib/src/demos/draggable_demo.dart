import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../backdrop.dart';
import '../glass_ui.dart';

/// **Draggable** — the drag wiring, so you do not write it again.
///
/// [LiquidGlassDraggable] wraps any widget and moves it with the finger,
/// keeping the offset itself and reporting it through `onChanged`. It is
/// ordinary `GestureDetector` plumbing, done once and correctly: the child
/// keeps its layout slot, so nothing around it reflows as it travels.
///
/// `enabled: false` freezes it in place without unwrapping anything — useful
/// when a lens is arrangeable in one mode of your UI and fixed in another.
///
/// The lens inside is the point of the pairing: drag a piece of glass over a
/// background captured once and the cost is a shader pass, no matter where it
/// ends up.
class DraggableDemo extends StatefulWidget {
  const DraggableDemo({super.key});

  @override
  State<DraggableDemo> createState() => _DraggableDemoState();
}

class _DraggableDemoState extends State<DraggableDemo> {
  Offset _offset = Offset.zero;
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassView(
      // Static backdrop: one snapshot, dragged over forever.
      realTimeCapture: false,
      backgroundWidget: const GlassBackdrop.dusk(),
      child: Stack(
        children: [
          Center(
            child: Padding(
              // Room for the controls pinned at the bottom.
              padding: const EdgeInsets.only(bottom: 130),
              child: LiquidGlassDraggable(
                enabled: _enabled,
                onChanged: (o) => setState(() => _offset = o),
                child: const SizedBox(
                  width: 190,
                  height: 190,
                  child: LiquidGlassLens(
                    style: LiquidGlassStyle(
                      shape: LiquidGlassShape.squircle(
                        cornerRadius: 56,
                        borderWidth: 1.4,
                        lightIntensity: 1.15,
                        lightDirection: 42,
                      ),
                      appearance: LiquidGlassAppearance(
                        color: Color(0x0FFFFFFF),
                        saturation: 1.06,
                      ),
                      refraction: LiquidGlassRefraction(
                        distortion: 0.13,
                        distortionWidth: 34,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.open_with_rounded,
                        color: Colors.white70,
                        size: 30,
                      ),
                    ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DemoHint(_enabled
                        ? 'Drag the glass. onChanged reports where it went.'
                        : 'Dragging is off — the same widget, frozen in place'),
                    const SizedBox(height: 10),
                    DemoPanel(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'offset  ${_offset.dx.toStringAsFixed(0)}, '
                              '${_offset.dy.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          DemoChip(
                            label: _enabled ? 'enabled' : 'disabled',
                            selected: _enabled,
                            onTap: () => setState(() => _enabled = !_enabled),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
