// Entry point for the shape lab, which lives outside the package in
// continuse_last_experments/. The example app is the only runnable Flutter
// target here, and this file sits outside lib/ so it may import across the
// package boundary.
//
//   cd example && flutter run -t shape_lab_main.dart

import 'package:flutter/widgets.dart' show runApp;

import '../continuse_last_experments/shape_lab/shape_gallery.dart';

void main() => runApp(const ShapeLabApp());
