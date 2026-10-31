// Standalone VM-service timeline client (dart:io only, no packages).
//
// Usage:
//   dart tool/timeline_dump.dart <ws-uri> clear     — enable streams + clear
//   dart tool/timeline_dump.dart <ws-uri> dump out.json — fetch timeline JSON
//
// Used to catch what the raster thread does during the first-touch
// stall of the liquid-glass slider/toggle (run with --trace-skia).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: timeline_dump.dart <ws-uri> clear|dump [out.json]');
    exit(2);
  }
  final uri = args[0];
  final cmd = args[1];

  final ws = await WebSocket.connect(uri);
  var nextId = 1;
  final pending = <int, Completer<Map<String, dynamic>>>{};

  ws.listen((data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final id = msg['id'];
    if (id != null) {
      final c = pending.remove(int.parse(id.toString()));
      c?.complete(msg);
    }
  });

  Future<Map<String, dynamic>> rpc(String method,
      [Map<String, dynamic>? params]) {
    final id = nextId++;
    final c = Completer<Map<String, dynamic>>();
    pending[id] = c;
    ws.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': '$id',
      'method': method,
      'params': params ?? {},
    }));
    return c.future.timeout(const Duration(seconds: 60));
  }

  if (cmd == 'clear') {
    final flags = await rpc('setVMTimelineFlags', {
      'recordedStreams': ['Embedder', 'GC', 'Compiler', 'Dart']
    });
    final cleared = await rpc('clearVMTimeline');
    stdout.writeln('flags: ${jsonEncode(flags['result'] ?? flags)}');
    stdout.writeln('cleared: ${jsonEncode(cleared['result'] ?? cleared)}');
  } else if (cmd == 'dump') {
    final out = args.length > 2 ? args[2] : 'timeline.json';
    final res = await rpc('getVMTimeline');
    final result = res['result'];
    if (result == null) {
      stderr.writeln('error: ${jsonEncode(res)}');
      await ws.close();
      exit(1);
    }
    File(out).writeAsStringSync(jsonEncode(result));
    final events = (result['traceEvents'] as List?)?.length ?? 0;
    stdout.writeln('wrote $out with $events events');
  } else {
    stderr.writeln('unknown command $cmd');
  }
  await ws.close();
  exit(0);
}
