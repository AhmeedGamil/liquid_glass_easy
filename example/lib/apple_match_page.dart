import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apple_match/apple_match_bands.dart';
import 'apple_match/apple_match_chips.dart';
import 'apple_match/apple_match_code.dart';
import 'apple_match/apple_match_tuning.dart';
import 'apple_match/color_picker.dart';
import 'apple_match/scenes/buttons_scene.dart';
import 'apple_match/scenes/slider_scene.dart';
import 'apple_match/scenes/switch_scene.dart';
import 'apple_match/scenes/tab_bar_scene.dart';

// =============================================================
// Apple Match — the apple_match components next to Apple's own.
//
// Two bands per scene, over the same backdrop:
//   1. Apple's control: live through cupertino_native on iOS and macOS,
//      elsewhere a screenshot of it from the iOS simulator of the chosen
//      release.
//   2. The tuned component from apple_match/.
//
// The panel at the bottom changes every apple_match value live, per iOS
// release. Values are not saved: "Copy" puts a component's package code,
// with the live values written in, on the clipboard; "Copy all" does it
// for every component.
// =============================================================

/// The appearance of the app for [brightness].
ThemeData appleMatchTheme(Brightness brightness) => ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0088FF),
        brightness: brightness,
      ),
      useMaterial3: true,
    );

enum _Component {
  buttons('Buttons', 'button', kButton,
      [Backdrop.photo, Backdrop.stripes, Backdrop.page]),
  tabBar('Tab bar', 'tab', kTabBar,
      [Backdrop.photo, Backdrop.stripes, Backdrop.page]),
  slider('Slider', 'slider', kSlider, [Backdrop.page, Backdrop.photo]),
  switches('Switch', 'switch', kSwitch, [Backdrop.page, Backdrop.photo]);

  const _Component(this.label, this.prefix, this.ownSection, this.backdrops);

  final String label;

  /// The id prefix of this component's knobs.
  final String prefix;

  /// The section holding the values only this component has.
  final String ownSection;
  final List<Backdrop> backdrops;

  /// The knob tabs, the component's own first.
  List<String> get sections => [ownSection, ...kStyleSections];

  List<Knob> knobs(String section) => [
        for (final Knob k in kKnobs)
          if (k.component == prefix && k.section == section) k,
      ];
}

class AppleMatchPage extends StatefulWidget {
  const AppleMatchPage({super.key});

  @override
  State<AppleMatchPage> createState() => _AppleMatchPageState();
}

class _AppleMatchPageState extends State<AppleMatchPage> {
  _Component _component = _Component.buttons;
  Backdrop _backdrop = Backdrop.photo;
  bool _dark = true;
  bool _knobsOpen = true;

  /// The open knob tab, per component.
  final Map<_Component, String> _section = {
    for (final c in _Component.values) c: c.ownSection,
  };

  Widget _scene() => switch (_component) {
        _Component.buttons => ButtonsScene(backdrop: _backdrop),
        _Component.tabBar => TabBarScene(backdrop: _backdrop),
        _Component.slider => SliderScene(backdrop: _backdrop),
        _Component.switches => SwitchScene(backdrop: _backdrop),
      };

  void _pick(_Component c) => setState(() {
        _component = c;
        if (!c.backdrops.contains(_backdrop)) _backdrop = c.backdrops.first;
      });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = appleMatchTheme(
      _dark ? Brightness.dark : Brightness.light,
    );
    final double screen = MediaQuery.sizeOf(context).height;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: _dark ? kPageDark : kPageLight,
        body: AppleMatchTuningScope(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _Header(
                  dark: _dark,
                  onToggleDark: () => setState(() => _dark = !_dark),
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('${_component.name}_${_backdrop.name}'),
                  child: _scene(),
                ),
              ),
              _TunerPanel(
                component: _component,
                backdrop: _backdrop,
                section: _section[_component]!,
                knobsOpen: _knobsOpen,
                knobsHeight: screen * 0.3,
                onComponent: _pick,
                onBackdrop: (b) => setState(() => _backdrop = b),
                onSection: (s) => setState(() => _section[_component] = s),
                onToggleKnobs: () => setState(() => _knobsOpen = !_knobsOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dark, required this.onToggleDark});

  final bool dark;
  final VoidCallback onToggleDark;

  @override
  Widget build(BuildContext context) {
    final Color ink = dark ? Colors.white : const Color(0xFF1C1C1E);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Apple Match',
              style: TextStyle(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: dark ? 'Light' : 'Dark',
            icon: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: ink,
            ),
            onPressed: onToggleDark,
          ),
        ],
      ),
    );
  }
}

/// The dark panel under the bands: the release, component and backdrop
/// pickers, always showing, and the knobs of one tab at a time, which fold
/// away to give the bands the screen.
class _TunerPanel extends StatelessWidget {
  const _TunerPanel({
    required this.component,
    required this.backdrop,
    required this.section,
    required this.knobsOpen,
    required this.knobsHeight,
    required this.onComponent,
    required this.onBackdrop,
    required this.onSection,
    required this.onToggleKnobs,
  });

  final _Component component;
  final Backdrop backdrop;
  final String section;
  final bool knobsOpen;
  final double knobsHeight;
  final ValueChanged<_Component> onComponent;
  final ValueChanged<Backdrop> onBackdrop;
  final ValueChanged<String> onSection;
  final VoidCallback onToggleKnobs;

  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    final int changed = AppleMatchTuning.changedCount;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF215161C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Dropdown<IosVersion>(
                      values: IosVersion.values,
                      selected: AppleMatchTuning.version,
                      label: (v) => v.label,
                      onChanged: (v) => AppleMatchTuning.version = v,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _Dropdown<_Component>(
                      values: _Component.values,
                      selected: component,
                      label: (c) => c.label,
                      onChanged: onComponent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _Dropdown<Backdrop>(
                      values: component.backdrops,
                      selected: backdrop,
                      label: (b) => b.label,
                      onChanged: onBackdrop,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleKnobs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Tune ${AppleMatchTuning.version.label}'
                        '${changed == 0 ? '' : '  ·  $changed changed'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        knobsOpen
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              if (knobsOpen) ...[
                _SectionTabs(
                  sections: component.sections,
                  selected: section,
                  changedIn: (s) => component
                      .knobs(s)
                      .any((k) => AppleMatchTuning.changed(k.id)),
                  onChanged: onSection,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: knobsHeight,
                  child: _KnobList(
                    key: ValueKey('${component.name}/$section'),
                    knobs: component.knobs(section),
                  ),
                ),
                const SizedBox(height: 8),
                _Actions(
                  component: component,
                  knobs: component.knobs(section),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The knob tabs: one line that scrolls sideways; a dot marks a tab with
/// changed values.
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.sections,
    required this.selected,
    required this.changedIn,
    required this.onChanged,
  });

  final List<String> sections;
  final String selected;
  final bool Function(String section) changedIn;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final String s in sections)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(s),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: s == selected
                          ? _accent
                          : const Color(0x00000000),
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Text(
                      s,
                      style: TextStyle(
                        color: s == selected
                            ? Colors.white
                            : const Color(0x99FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (changedIn(s)) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KnobList extends StatefulWidget {
  const _KnobList({super.key, required this.knobs});

  final List<Knob> knobs;

  @override
  State<_KnobList> createState() => _KnobListState();
}

class _KnobListState extends State<_KnobList> {
  @override
  Widget build(BuildContext context) {
    AppleMatchTuning.watch(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final Knob k in widget.knobs)
          switch (k.kind) {
            KnobKind.number => _NumberKnob(knob: k),
            KnobKind.toggle => _ToggleKnob(knob: k),
            KnobKind.choice => _ChoiceKnob(knob: k),
            KnobKind.color => _ColorKnob(knob: k),
          },
      ],
    );
  }
}

/// One line of choices, tap to open the list.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF23242C),
          borderRadius: BorderRadius.circular(10),
          iconEnabledColor: const Color(0x99FFFFFF),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final T v in values)
              DropdownMenuItem<T>(
                value: v,
                child: Text(label(v), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Copy this component's code, copy every component's, reset this tab,
/// reset the release.
class _Actions extends StatelessWidget {
  const _Actions({required this.component, required this.knobs});

  final _Component component;
  final List<Knob> knobs;

  Future<void> _copy(BuildContext context, String code, String what) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied the code of $what with its values.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0x44FFFFFF)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
    Widget action(IconData icon, String text, VoidCallback onPressed) =>
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(text, maxLines: 1, overflow: TextOverflow.fade),
            style: style,
          ),
        );
    return Row(
      children: [
        action(
          Icons.copy_rounded,
          'Copy ${component.label}',
          () => _copy(
            context,
            componentCode(component.prefix),
            component.label,
          ),
        ),
        const SizedBox(width: 6),
        action(
          Icons.copy_all_rounded,
          'Copy all',
          () => _copy(context, allComponentsCode(), 'every component'),
        ),
        const SizedBox(width: 6),
        action(
          Icons.undo_rounded,
          'Reset tab',
          () => AppleMatchTuning.resetIds(knobs.map((k) => k.id)),
        ),
        const SizedBox(width: 6),
        action(Icons.restart_alt_rounded, 'Reset all', AppleMatchTuning.reset),
      ],
    );
  }
}

const Color _accent = Color(0xFFB8B5FF);

const TextStyle _labelStyle = TextStyle(color: Color(0xDDFFFFFF), fontSize: 13);

TextStyle _labelFor(Knob k) => AppleMatchTuning.changed(k.id)
    ? _labelStyle.copyWith(color: _accent, fontWeight: FontWeight.w600)
    : _labelStyle;

SliderThemeData _sliderTheme(BuildContext context, Color active) =>
    SliderTheme.of(context).copyWith(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      activeTrackColor: active,
      thumbColor: active,
      inactiveTrackColor: const Color(0x33FFFFFF),
    );

/// Back to the preset value; empty while the knob is unchanged.
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.knob});

  final Knob knob;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: AppleMatchTuning.changed(knob.id)
          ? IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Back to the preset value',
              icon: const Icon(Icons.undo_rounded, size: 18, color: _accent),
              onPressed: () => AppleMatchTuning.resetIds([knob.id]),
            )
          : null,
    );
  }
}

class _NumberKnob extends StatelessWidget {
  const _NumberKnob({required this.knob});

  final Knob knob;

  @override
  Widget build(BuildContext context) {
    final double value = AppleMatchTuning.d(knob.id);
    final int? divisions = knob.step >= 1
        ? ((knob.max - knob.min) / knob.step).round()
        : null;
    return Row(
      children: [
        SizedBox(
          width: 170,
          child: Text(
            '${knob.label}  ${AppleMatchTuning.formatValue(knob, value)}',
            style: _labelFor(knob),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: _sliderTheme(context, _accent),
            child: Slider(
              value: value.clamp(knob.min, knob.max),
              min: knob.min,
              max: knob.max,
              divisions: divisions,
              onChanged: (v) => AppleMatchTuning.set(
                knob.id,
                knob.step >= 1
                    ? v.roundToDouble()
                    : double.parse(v.toStringAsFixed(3)),
              ),
            ),
          ),
        ),
        _ResetButton(knob: knob),
      ],
    );
  }
}

class _ToggleKnob extends StatelessWidget {
  const _ToggleKnob({required this.knob});

  final Knob knob;

  @override
  Widget build(BuildContext context) {
    final bool on = AppleMatchTuning.b(knob.id);
    void flip() => AppleMatchTuning.set(knob.id, on ? 0 : 1);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: flip,
      child: Row(
        children: [
          Checkbox(
            value: on,
            onChanged: (_) => flip(),
            activeColor: _accent,
            checkColor: const Color(0xFF15161C),
            side: const BorderSide(color: Color(0x99FFFFFF), width: 1.5),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(child: Text(knob.label, style: _labelFor(knob))),
          _ResetButton(knob: knob),
        ],
      ),
    );
  }
}

class _ChoiceKnob extends StatelessWidget {
  const _ChoiceKnob({required this.knob});

  final Knob knob;

  @override
  Widget build(BuildContext context) {
    final int selected = AppleMatchTuning.i(knob.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(knob.label, style: _labelFor(knob)),
          ),
          Expanded(
            child: DemoChips<int>(
              values: [for (int i = 0; i < knob.choices.length; i++) i],
              selected: selected,
              label: (i) => knob.choices[i],
              onChanged: (i) => AppleMatchTuning.set(knob.id, i),
            ),
          ),
          _ResetButton(knob: knob),
        ],
      ),
    );
  }
}

/// A colour knob: a swatch and its hex; tap to open the colour picker.
class _ColorKnob extends StatelessWidget {
  const _ColorKnob({required this.knob});

  final Knob knob;

  @override
  Widget build(BuildContext context) {
    final int value = AppleMatchTuning.i(knob.id);
    final Color color = Color(value);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showRgbaColorPicker(
        context: context,
        title: knob.label,
        initial: color,
        onChanged: (c) => AppleMatchTuning.set(knob.id, c.toARGB32()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x55FFFFFF)),
                // A light-dark split shows how see-through it is.
                gradient: const LinearGradient(
                  colors: [Colors.white, Colors.white, Colors.black, Colors.black],
                  stops: [0, 0.5, 0.5, 1],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(knob.label, style: _labelFor(knob))),
            Text(
              '${AppleMatchTuning.formatValue(knob, value)}  '
              '${(((value >> 24) & 0xFF) / 2.55).round()}%',
              style: const TextStyle(
                color: Color(0x99FFFFFF),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const Icon(
              Icons.palette_outlined,
              color: Color(0x99FFFFFF),
              size: 18,
            ),
            _ResetButton(knob: knob),
          ],
        ),
      ),
    );
  }
}
