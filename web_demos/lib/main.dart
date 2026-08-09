import 'package:flutter/material.dart';

import 'src/demo_registry.dart';
import 'src/demo_shell.dart';
import 'src/home_page.dart';

/// The live-demo island for the `liquid_glass_easy` docs site.
///
/// This app is **only** the demos. The prose lives in the static HTML site
/// under `docs_site/`, which embeds these by URL — real text for reading and
/// indexing, Flutter only where interaction earns its download.
///
/// ## Deep links
///
/// The URL selects what renders, so a docs page can point at one demo and the
/// link survives a title change:
///
///   * `/`                  — the landing page, all demos
///   * `/?d=touch`          — that demo, with its notes beside it
///   * `/?d=touch&embed=1`  — the demo alone, for an `<iframe>`
///
/// `embed=1` is the mode the docs site uses: the surrounding page already
/// says what the thing is, so the chrome here would only repeat it.
void main() {
  runApp(const DemosApp());
}

class DemosApp extends StatelessWidget {
  const DemosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, String> q = Uri.base.queryParameters;
    final DemoEntry? deepLink = demoById(q['d']);
    final bool embedded = q['embed'] == '1';

    return MaterialApp(
      title: 'Liquid Glass Easy — demos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B12),
      ),
      home: deepLink == null
          ? const HomePage()
          : _DeepLinked(entry: deepLink, embedded: embedded),
    );
  }
}

/// A demo opened straight from the URL.
///
/// There is no route to pop back to, so "back" replaces this page with the
/// index instead — except when embedded, where navigation belongs to the
/// hosting page.
class _DeepLinked extends StatelessWidget {
  final DemoEntry entry;
  final bool embedded;

  const _DeepLinked({required this.entry, required this.embedded});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: entry.title,
      blurb: entry.blurb,
      code: entry.code,
      demo: Builder(builder: entry.builder),
      embedded: embedded,
      onBack: embedded
          ? null
          : () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const HomePage()),
              ),
    );
  }
}
