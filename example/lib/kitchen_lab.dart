import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchen_glass_lab/kitchen_glass_lab.dart';

/// Entry point for the experimental glass lab.
///
///     flutter run -t lib/kitchen_lab.dart
void main() => runApp(const KitchenLabApp());

class KitchenLabApp extends StatelessWidget {
  const KitchenLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: KitchenGlassLabPage(onPickImage: _pickFromGallery),
    );
  }
}

/// The system photo picker, handed to the lab as its backdrop source.
///
/// The lab package itself stays plugin-free — drop this argument and it falls
/// back to its own folder chooser ([showBackdropPicker]).
Future<ui.Image?> _pickFromGallery(BuildContext context) async {
  final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  // Same 2048 px cap the folder chooser uses: the picture lives in GPU memory
  // for as long as it is shown, and is only ever drawn at screen size.
  return decodeBackdropFile(File(file.path));
}
