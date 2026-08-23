import 'package:flutter/foundation.dart';

/// Whether the gallery paints Flutter's performance overlay (the two
/// stacked graphs: UI thread on top, RASTER thread below).
///
/// Lives in its own file so pages can flip it without importing the
/// gallery that imports them.
///
/// Only meaningful in a **profile** build — a debug build's raster times
/// include assertions and unoptimised shaders, so the graphs there say
/// nothing about shipped performance.
final ValueNotifier<bool> showPerfOverlay = ValueNotifier<bool>(true);
