import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../data/aurora_data.dart';
import '../theme/aurora_theme.dart';
import '../widgets/aurora_gooey.dart';
import '../widgets/aurora_motion.dart';
import '../widgets/aurora_page.dart';
import '../widgets/aurora_surface.dart';

/// The coach thread.
///
/// The glass here is the composer — the one thing that floats over the
/// conversation instead of sitting in it. The rest is bubbles, and the
/// gooey typing dots carry the "thinking" state without a spinner.
class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final List<CoachMessage> _messages = [...kCoachHistory];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _thinking = false;
  int _reply = 0;
  Timer? _pending;

  @override
  void dispose() {
    _pending?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _messages.add(CoachMessage(trimmed, fromCoach: false, time: 'now'));
      _thinking = true;
      _input.clear();
    });
    _toBottom();

    // Long enough to read as thought, short enough not to feel broken.
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(CoachMessage(
          kCoachReplies[_reply % kCoachReplies.length],
          fromCoach: true,
          time: 'now',
        ));
        _reply++;
      });
      _toBottom();
    });
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final insets = MediaQuery.paddingOf(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(kGutter, insets.top + 14, kGutter, 6),
          child: const PageTitle(overline: 'YOUR COACH', title: 'Check in'),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 16),
            children: [
              for (var i = 0; i < _messages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Reveal(
                    index: i.clamp(0, 4),
                    offsetY: 12,
                    child: _Bubble(message: _messages[i]),
                  ),
                ),
              if (_thinking)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AuroraSurface(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    radius: 20,
                    child: TypingDots(color: p.accent),
                  ),
                ),
            ],
          ),
        ),

        // Quick replies: the thread is useless on a phone if every turn
        // needs the keyboard.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kGutter),
            children: [
              for (final reply in kQuickReplies) ...[
                AuroraChip(label: reply, onTap: () => _send(reply)),
                const SizedBox(width: 9),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── The page's one lens ──────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            kGutter,
            0,
            kGutter,
            // Clear the floating bar completely. Tucking the composer under
            // it saved 46px and cost the send button its bottom arc.
            kNavClearance + insets.bottom,
          ),
          child: SizedBox(
            height: 62,
            // The button is STACKED over the lens, not placed inside it.
            // A lens composites its child into an offscreen layer that
            // carries no MSAA, so a filled circle drawn in there comes out
            // with stair-stepped edges; the same circle one layer up is
            // antialiased normally.
            child: Stack(
              children: [
                Positioned.fill(
                  child: LiquidGlassLens(
                    style: p.glass(radius: 31, blur: 3, distortion: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 62, 0),
                      child: Center(
                        child: TextField(
                          controller: _input,
                          onSubmitted: _send,
                          textInputAction: TextInputAction.send,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: p.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Tell me how you slept…',
                            hintStyle: AuroraText.label(p),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 9,
                  top: 9,
                  child: PressableScale(
                    onTap: () => _send(_input.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.accent,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: p.onAccent,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final CoachMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final coach = message.fromCoach;

    return Row(
      mainAxisAlignment:
          coach ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (coach) ...[
          BlobMorph(size: 30, wobble: 0.18, colors: [p.accent, p.series[1]]),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment:
                coach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                decoration: BoxDecoration(
                  color: coach ? p.surface : p.accent,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(coach ? 6 : 20),
                    bottomRight: Radius.circular(coach ? 20 : 6),
                  ),
                  border: coach ? Border.all(color: p.stroke) : null,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: coach ? p.textPrimary : p.onAccent,
                    fontSize: 14.5,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (message.time.isNotEmpty) ...[
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(message.time, style: AuroraText.caps(p)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
