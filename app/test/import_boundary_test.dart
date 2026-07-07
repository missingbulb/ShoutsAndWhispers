// Enforces the ports-and-adapters import boundary (docs/UI-ARCHITECTURE.md):
// the analyzer-visible import graph is the boundary, so this test scans the
// source tree with dart:io. Pure Dart — no Flutter bindings needed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches import/export directives and captures the target URI.
final RegExp _directive =
    RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

List<File> _dartFilesUnder(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

Iterable<String> _importsOf(File file) =>
    _directive.allMatches(file.readAsStringSync()).map((m) => m.group(1)!);

void main() {
  test('screens/, ui/, and app.dart never import platform packages', () {
    final banned =
        RegExp(r'^package:(firebase_|cloud_|google_sign_in|geolocator)');
    final files = <File>[
      ..._dartFilesUnder(Directory('lib/screens')),
      ..._dartFilesUnder(Directory('lib/ui')),
      File('lib/app.dart'),
    ];
    // Guard against the scan silently going stale (e.g. moved directories).
    expect(files.length, greaterThanOrEqualTo(4));

    final violations = <String>[
      for (final file in files)
        for (final uri in _importsOf(file))
          if (banned.hasMatch(uri)) '${file.path} imports $uri',
    ];
    expect(
      violations,
      isEmpty,
      reason: 'UI code must depend only on ports (docs/UI-ARCHITECTURE.md): '
          '${violations.join('; ')}',
    );
  });

  test('main.dart is the only file outside adapters/ importing adapters', () {
    final adaptersImport = RegExp(
      r'^(package:shouts_and_whispers/adapters/|(\.\./)*adapters/)',
    );
    final importers = <String>{
      for (final file in _dartFilesUnder(Directory('lib')))
        if (!file.path.startsWith('lib/adapters/'))
          for (final uri in _importsOf(file))
            if (adaptersImport.hasMatch(uri)) file.path,
    };
    expect(
      importers,
      <String>{'lib/main.dart'},
      reason: 'main.dart is the only place adapters are constructed '
          '(docs/UI-ARCHITECTURE.md)',
    );
  });
}
