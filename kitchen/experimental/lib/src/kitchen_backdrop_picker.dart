import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Picking a backdrop off the device without a picker plugin.
///
/// The gallery itself is out of reach: on Android 13 reading `/sdcard/Pictures`
/// needs `READ_MEDIA_IMAGES`, and the system photo picker needs an activity
/// result — both mean native code. What an app *can* always read is its **own**
/// external files directory, no permission and no plugin, so that is where the
/// lab looks. Drop pictures there and they show up here.
///
///     adb push photo.jpg /sdcard/Android/data/<applicationId>/files/
///
/// The other locations below are tried anyway and ignored when they throw, so
/// they light up on their own if the storage permission is ever granted.

const List<String> _imageExtensions = <String>[
  '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif',
];

/// The app's own package id, read back out of the temp directory Dart is given
/// (`/data/user/0/<id>/cache`) so nothing has to be hardcoded.
String? appPackageId() {
  try {
    final String tmp = '${Directory.systemTemp.path.replaceAll(r'\', '/')}/';
    return RegExp(r'/data/(?:user/\d+|data)/([^/]+)/').firstMatch(tmp)?.group(1);
  } catch (_) {
    return null;
  }
}

/// The folder to drop pictures into. Created on first look so `adb push` has
/// somewhere to land.
Directory? appImagesDirectory() {
  final String? id = appPackageId();
  if (id == null) return null;
  for (final String root in <String>['/sdcard', '/storage/emulated/0']) {
    final Directory dir = Directory('$root/Android/data/$id/files');
    try {
      if (!dir.existsSync()) dir.createSync(recursive: true);
      if (dir.existsSync()) return dir;
    } catch (_) {
      // Next candidate.
    }
  }
  return null;
}

/// Every readable picture the lab can find, newest first.
///
/// Walks the app folder plus the usual media folders; anything that throws (a
/// permission wall, a missing volume) is skipped rather than surfaced.
List<File> findBackdropImages({int limit = 120}) {
  final List<Directory> roots = <Directory>[
    if (appImagesDirectory() case final Directory dir) dir,
    Directory('/sdcard/Download'),
    Directory('/sdcard/Pictures'),
    Directory('/sdcard/DCIM/Camera'),
  ];

  final List<File> found = <File>[];
  for (final Directory root in roots) {
    _collect(root, found, depth: 2, limit: limit);
    if (found.length >= limit) break;
  }

  found.sort((File a, File b) {
    try {
      return b.statSync().modified.compareTo(a.statSync().modified);
    } catch (_) {
      return 0;
    }
  });
  return found;
}

void _collect(Directory dir, List<File> out, {required int depth, required int limit}) {
  if (depth < 0 || out.length >= limit) return;
  late final List<FileSystemEntity> entries;
  try {
    if (!dir.existsSync()) return;
    entries = dir.listSync(followLinks: false);
  } catch (_) {
    return;
  }
  for (final FileSystemEntity entity in entries) {
    if (out.length >= limit) return;
    if (entity is File) {
      final String path = entity.path.toLowerCase();
      if (_imageExtensions.any(path.endsWith)) out.add(entity);
    } else if (entity is Directory) {
      _collect(entity, out, depth: depth - 1, limit: limit);
    }
  }
}

/// Decodes a file to a GPU image, capped on the long edge.
///
/// The backdrop is only ever drawn at screen size and the image stays in memory
/// for as long as it is shown, so a 48 MP frame is scaled down during decode
/// rather than after.
///
/// Ownership is left to `instantiateImageCodecWithSize`, which releases the
/// buffer and keeps the descriptor alive for the codec to decode out of.
/// Hand-rolling that is how the picker crashed the IO worker: disposing the
/// descriptor before `getNextFrame` frees the data the codec is still reading.
Future<ui.Image> decodeBackdropFile(File file, {int maxEdge = 2048}) async {
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromFilePath(file.path);
  final ui.Codec codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (int width, int height) {
      final int longest = width > height ? width : height;
      if (longest <= maxEdge) return const ui.TargetImageSize();
      final double scale = maxEdge / longest;
      return ui.TargetImageSize(
        width: (width * scale).round(),
        height: (height * scale).round(),
      );
    },
  );
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

/// Opens the chooser sheet and decodes whatever is tapped.
Future<ui.Image?> showBackdropPicker(BuildContext context) async {
  final File? file = await showModalBottomSheet<File>(
    context: context,
    backgroundColor: const Color(0xF00E1116),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext context) => const _BackdropPickerSheet(),
  );
  if (file == null) return null;
  return decodeBackdropFile(file);
}

class _BackdropPickerSheet extends StatefulWidget {
  const _BackdropPickerSheet();

  @override
  State<_BackdropPickerSheet> createState() => _BackdropPickerSheetState();
}

class _BackdropPickerSheetState extends State<_BackdropPickerSheet> {
  late List<File> _files = findBackdropImages();

  @override
  Widget build(BuildContext context) {
    final Directory? dir = appImagesDirectory();
    final double height = MediaQuery.sizeOf(context).height * 0.66;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
            child: Row(
              children: <Widget>[
                const Text(
                  'Choose a backdrop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rescan',
                  onPressed: () => setState(() => _files = findBackdropImages()),
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: _files.isEmpty
                ? _EmptyState(directory: dir)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (BuildContext context, int i) {
                      final File file = _files[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).pop(file),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0x14FFFFFF),
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white24),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (dir != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text(
                'Looking in ${dir.path}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.directory});

  final Directory? directory;

  @override
  Widget build(BuildContext context) {
    final String path = directory?.path ?? '/sdcard/Android/data/<app>/files';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.photo_library_outlined,
                size: 40, color: Colors.white24),
            const SizedBox(height: 14),
            const Text(
              'No pictures found',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Copy a few into the app folder, then tap refresh. '
              'No permission is needed for that folder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                'adb push photo.jpg $path/',
                style: const TextStyle(
                  color: Color(0xFF6BE3FF),
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
