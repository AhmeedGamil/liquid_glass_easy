// Analyze a VM-service timeline dump: pair B/E events per thread,
// list the longest spans, and dump the children of the longest
// raster-thread frame to attribute a stall.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final data =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final events = (data['traceEvents'] as List).cast<Map<String, dynamic>>();

  // Build duration spans: explicit X events + paired B/E per tid.
  final spans = <Map<String, dynamic>>[];
  final stacks = <Object, List<Map<String, dynamic>>>{};
  for (final e in events) {
    final ph = e['ph'];
    if (ph == 'X') {
      spans.add({
        'name': e['name'],
        'ts': e['ts'],
        'dur': e['dur'] ?? 0,
        'tid': e['tid'],
      });
    } else if (ph == 'B') {
      stacks.putIfAbsent(e['tid'] ?? 0, () => []).add(e);
    } else if (ph == 'E') {
      final st = stacks[e['tid'] ?? 0];
      if (st != null && st.isNotEmpty) {
        final b = st.removeLast();
        spans.add({
          'name': b['name'],
          'ts': b['ts'],
          'dur': (e['ts'] as num) - (b['ts'] as num),
          'tid': b['tid'],
          'depth': st.length,
        });
      }
    }
  }

  spans.sort((a, b) => (b['dur'] as num).compareTo(a['dur'] as num));
  stdout.writeln('=== top 35 longest spans ===');
  for (final s in spans.take(35)) {
    stdout.writeln(
        '${(s['dur'] as num) / 1000}ms  tid=${s['tid']} depth=${s['depth'] ?? '-'}  ${s['name']}');
  }

  // Longest Rasterizer frame: print its children sorted by duration.
  final raster = spans
      .where((s) => (s['name'] as String).contains('Rasterizer::Draw'))
      .toList();
  if (raster.isEmpty) {
    stdout.writeln('no Rasterizer::Draw spans found');
    return;
  }
  final worst = raster.first;
  final t0 = worst['ts'] as num;
  final t1 = t0 + (worst['dur'] as num);
  stdout.writeln(
      '\n=== worst raster frame: ${(worst['dur'] as num) / 1000}ms (tid=${worst['tid']}) — children >0.5ms ===');
  final children = spans
      .where((s) =>
          s['tid'] == worst['tid'] &&
          s != worst &&
          (s['ts'] as num) >= t0 &&
          (s['ts'] as num) < t1 &&
          (s['dur'] as num) > 500)
      .toList()
    ..sort((a, b) => (a['ts'] as num).compareTo(b['ts'] as num));
  for (final s in children) {
    stdout.writeln(
        '+${((s['ts'] as num) - t0) / 1000}ms  ${(s['dur'] as num) / 1000}ms  depth=${s['depth'] ?? '-'}  ${s['name']}');
  }

  // Name histogram inside the worst frame (all durations).
  final hist = <String, num>{};
  for (final s in spans) {
    if (s['tid'] == worst['tid'] &&
        (s['ts'] as num) >= t0 &&
        (s['ts'] as num) < t1 &&
        s != worst) {
      hist[s['name'] as String] =
          (hist[s['name'] as String] ?? 0) + (s['dur'] as num);
    }
  }
  final entries = hist.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('\n=== time by event name inside worst frame ===');
  for (final e in entries.take(20)) {
    stdout.writeln('${e.value / 1000}ms  ${e.key}');
  }
}
