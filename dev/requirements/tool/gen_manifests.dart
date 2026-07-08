import 'dart:io';

/// Regenerates every `<kind>/manifest.dart` from the case files on disk.
/// Run from dev/requirements/:  dart run tool/gen_manifests.dart
///
/// Dart has no dynamic import, so each kind keeps a manifest; this tool
/// makes it derived output (like the gallery) instead of hand-maintained.
/// The coverage gate still verifies manifest ⇄ disk equality — running this
/// tool is how you satisfy it after adding or removing a case.
const kindTypes = <String, String>{
  'screen': 'ScreenCase',
  'saga': 'SagaCase',
  'behavior': 'BehaviorCase',
  'logic': 'LogicCase',
};

void main() {
  final caseFile = RegExp(r'^([a-z][a-z0-9_]*)\.(\d+(?:\.\d+)+)\.case\.dart$');
  for (final entry in kindTypes.entries) {
    final kind = entry.key;
    final names = Directory('$kind/cases')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where(caseFile.hasMatch)
        .toList()
      ..sort(_bySectionThenId);

    final buffer = StringBuffer()..writeln("import '../shared/cases.dart';");
    final entries = <String>[];
    for (final name in names) {
      final m = caseFile.firstMatch(name)!;
      final prefix = '${m.group(1)}_${m.group(2)!.replaceAll('.', '_')}';
      buffer.writeln("import 'cases/$name' as $prefix;");
      entries.add('  $prefix.theCase,');
    }
    buffer
      ..writeln()
      ..writeln(
          '/// Every $kind case, derived from the files on disk — regenerate')
      ..writeln('/// with `dart run tool/gen_manifests.dart`; the coverage '
          'gate enforces')
      ..writeln('/// manifest ⇄ disk equality.')
      ..writeln('final List<${entry.value}> cases = [')
      ..writeAll(entries, '\n')
      ..writeln(entries.isEmpty ? '];' : '\n];');
    File('$kind/manifest.dart').writeAsStringSync(buffer.toString());
    stdout.writeln('$kind/manifest.dart: ${names.length} cases');
  }
}

/// Sorts by the numeric leaf id (1.2 < 1.10 < 4.1), then name.
int _bySectionThenId(String a, String b) {
  List<int> id(String name) => RegExp(r'\.(\d+(?:\.\d+)+)\.case\.dart$')
      .firstMatch(name)!
      .group(1)!
      .split('.')
      .map(int.parse)
      .toList();
  final ia = id(a), ib = id(b);
  for (var i = 0; i < ia.length && i < ib.length; i++) {
    final c = ia[i].compareTo(ib[i]);
    if (c != 0) return c;
  }
  return ia.length.compareTo(ib.length);
}
