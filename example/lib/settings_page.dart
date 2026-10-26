import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'app_settings.dart';

// =============================================================
// Settings — the gallery's own preferences page.
//
// Glass switches and sliders, each bound to a notifier the gallery listens to:
//
//   • Dark mode → app_settings.dart's `darkMode`, which picks the
//     MaterialApp's themeMode. Every demo opened from the menu reads it
//     back through `Theme.of(context).brightness`.
//   • Lite glass → app_settings.dart's `liteGlass`, which sets both
//     `LiquidGlassEngine` switches, so every lens in the gallery draws
//     the shader-free material.
//   • Performance overlay → app_settings.dart's `performanceOverlay`,
//     which turns on the MaterialApp's frame graphs over every page.
//   • Shape cache → app_settings.dart's `shapeCache`, which sets
//     `LiquidGlassConfiguration.shapeCache`.
//   • Separate-pass batch → app_settings.dart's `separatePassBatch`,
//     which sets `LiquidGlassConfiguration.batchMode`; read when a page opens.
//   • Batch → `galleryBatchEnabled`, the `batch` flag of every view,
//     scaffold, batch, sheet and dialog; read when a page opens.
//   • Shader blur → `LiquidGlassConfiguration.blurMethod` (lenses outside a
//     batch); Batched shader blur → `.batchBlurMethod`. Read when a page
//     opens.
//   • Shader blur dispersion → `LiquidGlassConfiguration.shaderBlurDispersion`;
//     Batched dispersion → `.batchShaderBlurDispersion`.
//   • Override blur & dispersion → `LiquidGlassConfiguration.blurOverride` and
//     `.dispersionOverride`, from the two sliders; read when a page opens.
//
// The settings are not persisted; they reset on restart.
//
//   flutter run -t lib/gallery.dart   → gear icon, top right
// =============================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : const Color(0xFF11131A);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: galleryBackground(brightness)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: ink.withValues(alpha: 0.8),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Appearance'),
              const SizedBox(height: 12),
              _Card(
                children: [
                  // Rebuilt from the notifier rather than page state: the
                  // MaterialApp above listens to the same one, so the
                  // switch and the whole app flip off a single source.
                  ValueListenableBuilder<bool>(
                    valueListenable: darkMode,
                    builder: (context, value, _) => _SwitchRow(
                      icon: value
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: 'Dark mode',
                      detail: value
                          ? 'Glass over a dark backdrop'
                          : 'Glass over a light backdrop',
                      value: value,
                      onChanged: (v) => darkMode.value = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Engine'),
              const SizedBox(height: 12),
              _Card(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: liteGlass,
                    builder: (context, value, _) => _SwitchRow(
                      icon: value
                          ? Icons.blur_on_rounded
                          : Icons.lens_blur_rounded,
                      label: 'Lite glass',
                      detail: value
                          ? 'Frost, tint and rim — no shader, no capture'
                          : 'The shader: every lens refracts its backdrop',
                      value: value,
                      onChanged: (v) => liteGlass.value = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Performance'),
              const SizedBox(height: 12),
              _Card(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: performanceOverlay,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.speed_rounded,
                      label: 'Performance overlay',
                      detail: value
                          ? 'Raster and UI frame graphs over every page'
                          : 'Off',
                      value: value,
                      onChanged: (v) => performanceOverlay.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: shapeCache,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.layers_rounded,
                      label: 'Shape cache',
                      detail: value
                          ? 'Shapes baked once, kept while they only move'
                          : 'Every shape evaluated per pixel, every frame',
                      value: value,
                      onChanged: (v) => shapeCache.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: separatePassBatch,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.key_rounded,
                      label: 'Separate-pass batch',
                      detail: value
                          ? 'Engine blur keyed, shader takes its own read'
                          : 'Single pass: engine blur composed into the shader',
                      value: value,
                      onChanged: (v) => separatePassBatch.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: galleryBatchEnabled,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.join_full_rounded,
                      label: 'Batch',
                      detail: value
                          ? 'Glass shares one backdrop read per batch'
                          : 'Every glass takes its own read',
                      value: value,
                      onChanged: (v) => galleryBatchEnabled.value = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel('Blur'),
              const SizedBox(height: 12),
              _Card(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: shaderBlur,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.blur_circular_rounded,
                      label: 'Shader blur',
                      detail: value
                          ? 'Unbatched lenses: the shader blurs'
                          : 'Unbatched lenses: an engine blur pass',
                      value: value,
                      onChanged: (v) => shaderBlur.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: batchShaderBlur,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.blur_linear_rounded,
                      label: 'Batched shader blur',
                      detail: value
                          ? 'Batched lenses: the shader blurs'
                          : 'Batched lenses: the engine blurs',
                      value: value,
                      onChanged: (v) => batchShaderBlur.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: shaderBlurDispersion,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.gradient_rounded,
                      label: 'Shader blur dispersion',
                      detail: value
                          ? 'Unbatched lenses: every blur tap dispersed'
                          : 'Unbatched lenses: no fringe in a shader blur',
                      value: value,
                      onChanged: (v) => shaderBlurDispersion.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: batchShaderBlurDispersion,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.gradient_outlined,
                      label: 'Batched dispersion',
                      detail: value
                          ? 'Batched lenses: every blur tap dispersed'
                          : 'Batched lenses: no fringe in a shader blur',
                      value: value,
                      onChanged: (v) => batchShaderBlurDispersion.value = v,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: overrideGlass,
                    builder: (context, value, _) => _SwitchRow(
                      icon: Icons.tune_rounded,
                      label: 'Override blur & dispersion',
                      detail: value
                          ? 'Every lens takes the values below'
                          : 'Every lens keeps its own',
                      value: value,
                      onChanged: (v) => overrideGlass.value = v,
                    ),
                  ),
                  _SliderRow(
                    label: 'Blur',
                    notifier: glassBlur,
                    max: 20,
                  ),
                  _SliderRow(
                    label: 'Dispersion',
                    notifier: glassDispersion,
                    max: 8,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: (dark ? Colors.white : const Color(0xFF11131A))
            .withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// The rounded panel the rows sit on — a translucent white in both
/// brightnesses, only at different strengths.
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dark ? 0.05 : 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: children),
      ),
    );
  }
}

/// One settings row with a value slider, bound to [notifier].
class _SliderRow extends StatelessWidget {
  final String label;
  final ValueNotifier<double> notifier;
  final double max;

  const _SliderRow({
    required this.label,
    required this.notifier,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : const Color(0xFF11131A);
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, value, _) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                max: max,
                onChanged: (v) => notifier.value = v,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                value.toStringAsFixed(1),
                textAlign: TextAlign.end,
                style: TextStyle(color: ink.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One settings row: icon, label + detail, and the glass switch.
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = dark ? Colors.white : const Color(0xFF11131A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 21, color: ink.withValues(alpha: 0.75)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Shipped defaults throughout — the clear glass thumb, its
          // inset contact shadow and the pinched slice behind the glass
          // all come from LiquidGlassSwitch.defaultStyle.
          LiquidGlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
