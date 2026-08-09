// Entry point for the LiquidGlassFragment.metal shape gallery, which lives
// outside the package in continuse_last_experments/. The example app is the
// only runnable Flutter target here, and this file sits outside lib/ so it may
// import across the package boundary.
//
//   cd example && flutter run -t metal_shapes_main.dart

import 'package:flutter/widgets.dart' show runApp;

import '../continuse_last_experments/metal_shapes/metal_shape_gallery.dart';

void main() => runApp(const MetalShapeGalleryApp());
