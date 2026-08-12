import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';

/// Fades + lifts its child in, [index] steps behind its neighbours.
///
/// Entrance staggering is the cheapest way to make a static list feel
/// authored, and it costs one implicit animation per row.
class Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  final double offsetY;
  final Duration duration;
  final Duration step;

  const Reveal({
    super.key,
    this.index = 0,
    required this.child,
    this.offsetY = 26,
    this.duration = const Duration(milliseconds: 620),
    this.step = const Duration(milliseconds: 62),
  });

  @override
  Widget build(BuildContext context) {
    if (context.auroraController.reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + step * index,
      curve: Interval(
        // Later rows start later inside a shared, longer window, so the
        // whole group still lands together.
        (index * 0.055).clamp(0.0, 0.6),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, offsetY * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Counts from 0 to [value] on first build, and animates between values
/// after that.
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final int decimals;
  final String prefix;
  final String suffix;
  final Duration duration;

  /// Inserts thousands separators — balances read wrong without them.
  final bool grouped;

  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.grouped = false,
    this.duration = const Duration(milliseconds: 1100),
  });

  static String format(double v, int decimals, bool grouped) {
    var text = v.toStringAsFixed(decimals);
    if (!grouped) return text;
    final parts = text.split('.');
    final digits = parts.first.replaceAll('-', '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    text = '${v < 0 ? '-' : ''}$buf';
    return parts.length > 1 ? '$text.${parts[1]}' : text;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => Text(
        '$prefix${format(v, decimals, grouped)}$suffix',
        style: style ?? AuroraText.numeric(context.palette),
      ),
    );
  }
}

/// A slow scale/opacity pulse — used on live indicators and the record
/// dot, where "this is happening now" has to read without a label.
class Breathe extends StatefulWidget {
  final Widget child;
  final double amount;
  final Duration period;

  const Breathe({
    super.key,
    required this.child,
    this.amount = 0.06,
    this.period = const Duration(milliseconds: 2200),
  });

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.auroraController.reduceMotion) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final s = 1 + widget.amount * math.sin(_c.value * 2 * math.pi);
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}

/// Text painted with a gradient that slides across it.
class GradientText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final TextAlign textAlign;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
    this.textAlign = TextAlign.start,
  });

  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = context.auroraController.reduceMotion;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shift = still ? 0.0 : _c.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + shift, -0.4),
            end: Alignment(1 + shift, 0.4),
            colors: [...widget.colors, ...widget.colors],
            tileMode: TileMode.mirror,
          ).createShader(rect),
          child: Text(
            widget.text,
            textAlign: widget.textAlign,
            style: widget.style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

/// The app's push transition: the incoming page rises and scales up out
/// of the outgoing one, which dims and drops back a step.
class AuroraPageRoute<T> extends PageRouteBuilder<T> {
  AuroraPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 460),
          reverseTransitionDuration: const Duration(milliseconds: 340),
          pageBuilder: (context, a, b) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuint,
              reverseCurve: Curves.easeInCubic,
            );
            final out = CurvedAnimation(
              parent: secondary,
              curve: Curves.easeOutQuint,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.045),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween(begin: 0.965, end: 1.0).animate(curved),
                  child: ScaleTransition(
                    scale: Tween(begin: 1.0, end: 0.96).animate(out),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

/// Cross-fades between children by index, sliding the new one in from
/// the direction of travel. Used by the shell's tab switch.
class DirectionalSwitcher extends StatelessWidget {
  final int index;
  final int previousIndex;
  final Widget child;
  final Duration duration;

  const DirectionalSwitcher({
    super.key,
    required this.index,
    required this.previousIndex,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  Widget build(BuildContext context) {
    final forward = index >= previousIndex;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: Offset(forward ? 0.06 : -0.06, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(index), child: child),
    );
  }
}
