import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/aurora_theme.dart';

/// An ordinary content card.
///
/// Deliberately *not* a `LiquidGlassLens`. Real glass is the floating
/// navigation layer — bars, panels, the one hero control — and a page
/// that makes every card a lens both costs more than it's worth and
/// reads as noise. This is the frosted plate the content sits on.
class AuroraSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Adds a real backdrop blur. Worth it over photography, wasted over a
  /// gradient — so it's opt-in.
  final bool blur;

  /// Uses the heavier fill, for a card that should sit closer.
  final bool strong;

  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Border? border;
  final List<BoxShadow>? shadows;
  final Clip clipBehavior;

  const AuroraSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = false,
    this.strong = false,
    this.color,
    this.gradient,
    this.onTap,
    this.border,
    this.shadows,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final br = BorderRadius.circular(radius);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? (strong ? p.surfaceStrong : p.surface))
            : null,
        gradient: gradient,
        borderRadius: br,
        border: border ?? Border.all(color: p.stroke, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blur) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: body,
      );
    }

    body = ClipRRect(
      borderRadius: br,
      clipBehavior: clipBehavior,
      child: body,
    );

    if (shadows != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(borderRadius: br, boxShadow: shadows),
        child: body,
      );
    }

    if (onTap == null) return body;

    return _Pressable(onTap: onTap!, child: body);
  }
}

/// Scale-on-press with an over-damped return. Every tappable surface in
/// the app runs through this so touch feels like one material.
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _Pressable({required this.onTap, required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.965 : 1,
        duration: Duration(milliseconds: _down ? 110 : 340),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Public wrapper around the same press physics, for content that brings
/// its own decoration.
class PressableScale extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const PressableScale({super.key, this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return _Pressable(onTap: onTap!, child: child);
  }
}

/// A small pill — filter chips, tags, status badges.
class AuroraChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AuroraChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = color ?? p.accent;
    final fg = selected ? p.onAccent : p.textSecondary;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? tint : p.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? tint : p.stroke,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `Section title    →  action`
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 12),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: AuroraText.section(p))),
          if (action != null)
            PressableScale(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    action!,
                    style: TextStyle(
                      color: p.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 17, color: p.accent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A labelled number with an optional delta — the app's stat primitive.
class AuroraStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? tint;
  final String? delta;
  final bool deltaUp;

  /// Whether that direction is the *good* one. Defaults to [deltaUp],
  /// which is right for a step count and exactly wrong for a resting
  /// heart rate — the arrow states the direction, the color states the
  /// verdict, and they are not the same claim.
  final bool? deltaGood;

  const AuroraStat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.tint,
    this.delta,
    this.deltaUp = true,
    this.deltaGood,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = tint ?? p.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: c),
              ),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                label,
                style: AuroraText.label(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuroraText.numeric(p, size: 26),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit!, style: AuroraText.label(p)),
            ],
          ],
        ),
        if (delta != null) ...[
          const SizedBox(height: 6),
          Builder(builder: (context) {
            final good = deltaGood ?? deltaUp;
            final tone = good ? p.success : p.danger;
            return Row(
              children: [
                Icon(
                  deltaUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14,
                  color: tone,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: TextStyle(
                    color: tone,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }),
        ],
      ],
    );
  }
}
