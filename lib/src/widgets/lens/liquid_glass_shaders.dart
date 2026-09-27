import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// App-wide cache for the compiled liquid-glass fragment programs.
///
/// A `FragmentProgram` is expensive to compile and identical for every
/// lens in the app, so it is loaded once and shared. Individual
/// `FragmentShader` *instances* (which hold per-lens uniform state) are
/// created from the cached programs and owned by their lens.
///
/// ## Per-backend programs
///
/// The shape-gradient method differs by backend: Impeller uses hardware
/// derivatives (`dFdx`), which are invalid SkSL — so Skia/web loads a
/// separate entry that selects the analytic gradient instead. The programs
/// are therefore cached **per backend** (`impeller` true/false), and every
/// call passes the backend it needs:
///
///   * `impeller == true`  → `liquid_glass.frag`
///   * `impeller == false` → `liquid_glass_skia.frag` / `..._border_skia.frag`
///
/// The border program is Skia-only: it draws the sharp rim over the Skia
/// capture's blur. Impeller draws its rim in the main pass and never loads it.
///
/// `LiquidGlassView` and the standalone `LiquidGlassLens` both load through
/// this cache, so whichever mounts first pays the one-time async compile and
/// every later mount on the same backend gets its shaders synchronously.
///
/// Call [ensureLoaded] ahead of time (e.g. in `main()` before `runApp`) to
/// guarantee even the very first lens — or the first `LiquidGlassBlender` —
/// renders on its first frame. It loads every program the package draws
/// with: the lens's main and border programs and the blender's merged-surface
/// program. With no argument it preloads the engine's native backend
/// (`ui.ImageFilter.isShaderFilterSupported`):
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LiquidGlassShaders.ensureLoaded();
///   runApp(const MyApp());
/// }
/// ```
class LiquidGlassShaders {
  LiquidGlassShaders._();

  // Programs keyed by backend: true = Impeller (derivative), false = Skia
  // (analytic). Each backend loads a different entry .frag.
  static final Map<bool, ui.FragmentProgram> _mainPrograms = {};
  static final Map<bool, ui.FragmentProgram> _borderPrograms = {};
  static final Map<bool, Future<void>> _loading = {};

  static const Map<bool, String> _mainAsset = {
    true: 'lib/assets/shaders/liquid_glass.frag',
    false: 'lib/assets/shaders/liquid_glass_skia.frag',
  };
  static const String _borderAsset =
      'lib/assets/shaders/liquid_glass_border_skia.frag';

  // The merged-surface entry, used by LiquidGlassBlender and nothing else.
  // [ensureLoaded] compiles it with the rest; the lens itself waits only on
  // its own two, through [ensureLensLoaded].
  static final Map<bool, ui.FragmentProgram> _metaballPrograms = {};
  static final Map<bool, Future<ui.FragmentProgram>> _metaballLoading = {};
  static const Map<bool, String> _metaballAsset = {
    true: 'lib/assets/shaders/metaball_glass.frag',
    false: 'lib/assets/shaders/metaball_glass_skia.frag',
  };

  // Impeller on desktop GLES (Windows through ANGLE, Linux on the system
  // driver). ANGLE's shader compiler takes minutes on the default entries;
  // these build lighter code for it, with the analytic gradient.
  static const String _mainDesktopAsset =
      'lib/assets/shaders/liquid_glass_desktop.frag';
  static const String _metaballDesktopAsset =
      'lib/assets/shaders/metaball_glass_desktop.frag';

  static bool _desktopEntries(bool impeller) =>
      impeller &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static String _mainAssetFor(bool impeller) =>
      _desktopEntries(impeller) ? _mainDesktopAsset : _mainAsset[impeller]!;

  static String _metaballAssetFor(bool impeller) => _desktopEntries(impeller)
      ? _metaballDesktopAsset
      : _metaballAsset[impeller]!;

  /// The engine's native backend — Impeller exposes the shader image filter.
  static bool get _defaultImpeller => ui.ImageFilter.isShaderFilterSupported;

  /// Whether the lens's programs for [impeller] are compiled and shader
  /// instances can be created synchronously via [createMainShader] (and, on
  /// Skia, [createBorderShader]).
  static bool isLoadedFor(bool impeller) =>
      _mainPrograms.containsKey(impeller) &&
      (impeller || _borderPrograms.containsKey(impeller));

  /// Whether the engine's native backend is loaded. Convenience for callers
  /// that don't track the backend explicitly.
  static bool get isLoaded => isLoadedFor(_defaultImpeller);

  /// Loads and compiles every fragment program the package draws with, for
  /// [impeller] (defaults to the engine's native backend): the lens's main
  /// and border programs, and the merged-surface program `LiquidGlassBlender`
  /// and `LiquidGlassMorph` draw with. One `await` in `main()` and the first
  /// lens and the first blender are both glass on their first frame.
  ///
  /// Safe to call repeatedly and from multiple call sites — concurrent
  /// callers for the same backend share the in-flight futures, and once
  /// loaded it completes synchronously.
  static Future<void> ensureLoaded([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    if (isLoadedFor(backend) && isBlenderLoadedFor(backend)) {
      return Future.value();
    }
    return Future.wait<Object?>(<Future<Object?>>[
      ensureLensLoaded(backend),
      ensureBlenderLoaded(backend),
    ]).then((_) {});
  }

  /// The lens's programs only, for [impeller]: what a lens needs to
  /// paint, without waiting on the blender's larger entry.
  ///
  /// The lens, the view and the warm-up load through this so a first lens is
  /// never held back by a program it does not draw with. Apps call
  /// [ensureLoaded], which covers this and the blender's program together.
  @internal
  static Future<void> ensureLensLoaded([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    if (isLoadedFor(backend)) return Future.value();
    return _loading[backend] ??= _load(backend);
  }

  static Future<void> _load(bool impeller) async {
    try {
      _mainPrograms[impeller] ??= await _loadProgram(_mainAssetFor(impeller));
      if (!impeller) {
        _borderPrograms[impeller] ??= await _loadProgram(_borderAsset);
      }
    } finally {
      // Reset so a failed load (e.g. asset missing in a broken build) can be
      // retried instead of caching the failure forever.
      _loading.remove(impeller);
    }
  }

  /// Whether the merged-surface program for [impeller] is compiled.
  @internal
  static bool isBlenderLoadedFor(bool impeller) =>
      _metaballPrograms.containsKey(impeller);

  /// Loads and compiles the merged-surface program `LiquidGlassBlender` and
  /// `LiquidGlassGroup` draw with, once per backend, and hands it back.
  ///
  /// The blender loads through this because it needs the program itself;
  /// apps call [ensureLoaded], which covers it. A blender with no program yet
  /// paints **nothing**, where a single lens would show its frosted fallback
  /// — which is why the one public call compiles this one too.
  @internal
  static Future<ui.FragmentProgram> ensureBlenderLoaded([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    final ui.FragmentProgram? cached = _metaballPrograms[backend];
    if (cached != null) return Future.value(cached);
    return _metaballLoading[backend] ??= _loadMetaball(backend);
  }

  static Future<ui.FragmentProgram> _loadMetaball(bool impeller) async {
    try {
      return _metaballPrograms[impeller] =
          await _loadProgram(_metaballAssetFor(impeller));
    } finally {
      // Reset so a failed load can be retried instead of cached forever.
      _metaballLoading.remove(impeller);
    }
  }

  static Future<ui.FragmentProgram> _loadProgram(String relativePath) async {
    try {
      // Normal case: this package is a dependency of the running app, so its
      // assets live under the packages/ prefix.
      return await ui.FragmentProgram.fromAsset(
          'packages/liquid_glass_easy/$relativePath');
    } catch (_) {
      // Running inside the package itself (its own widget tests), where the
      // same assets resolve without the prefix.
      return await ui.FragmentProgram.fromAsset(relativePath);
    }
  }

  /// Creates a fresh main-shader instance for [impeller] (defaults to the
  /// engine's native backend). [isLoadedFor] must be true for that backend.
  static ui.FragmentShader createMainShader([bool? impeller]) {
    final bool backend = impeller ?? _defaultImpeller;
    final program = _mainPrograms[backend];
    assert(program != null,
        'LiquidGlassShaders not loaded — await ensureLoaded($backend) first.');
    return program!.fragmentShader();
  }

  /// Creates a fresh border-shader instance. Skia only — Impeller has no
  /// border program. [isLoadedFor] must be true for Skia.
  static ui.FragmentShader createBorderShader() {
    final program = _borderPrograms[false];
    assert(program != null,
        'LiquidGlassShaders not loaded — await ensureLoaded(false) first.');
    return program!.fragmentShader();
  }
}
