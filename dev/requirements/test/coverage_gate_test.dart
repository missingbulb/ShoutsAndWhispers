import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/manifest.dart' as behavior;
import '../logic/manifest.dart' as logic;
import '../saga/manifest.dart' as saga;
import '../screen/manifest.dart' as screen;
import '../shared/cases.dart';
import '../shared/spec.dart' as spec;

/// The spine of the framework: every spec leaf ⇄ exactly one case, of
/// exactly one kind, registered in its kind's manifest, named for its leaf.
/// Doc-first and red by default — adding a leaf to requirements.md fails
/// this gate until a case claims it.
void main() {
  final caseFile = RegExp(r'^([a-z][a-z0-9_]*)\.(\d+(?:\.\d+)+)\.case\.dart$');

  final manifests = <String, List<RequirementCase>>{
    'screen': screen.cases,
    'saga': saga.cases,
    'behavior': behavior.cases,
    'logic': logic.cases,
  };

  test('the kind registry matches the directories on disk', () {
    final onDisk = Directory('.')
        .listSync()
        .whereType<Directory>()
        .where((d) => Directory('${d.path}/cases').existsSync())
        .map((d) => d.path.replaceFirst('./', ''))
        .toSet();
    expect(onDisk, kinds.keys.toSet(),
        reason: 'every directory with a cases/ subfolder must be a '
            'registered kind (shared/cases.dart) and vice versa — '
            'the folder IS the kind');
    expect(manifests.keys.toSet(), kinds.keys.toSet());
  });

  test('every leaf ⇄ exactly one case file, correctly named and registered',
      () {
    final leaves = spec.leafRequirementIds(spec.specFile());
    expect(leaves, isNotEmpty, reason: 'spec parse produced no leaves');

    final problems = <String>[];
    final claims = <String, String>{}; // leaf id -> "kind/file"

    for (final kind in kinds.keys) {
      final dir = Directory('$kind/cases');
      final diskCases = <String, String>{}; // id -> slug
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.dart')) continue;
        final m = caseFile.firstMatch(name);
        if (m == null) {
          problems.add('$kind/cases/$name: misnamed — expected '
              '<slug>.<leaf-id>.case.dart');
          continue;
        }
        final slug = m.group(1)!, id = m.group(2)!;
        if (!leaves.contains(id)) {
          problems.add('$kind/cases/$name claims `$id`, which is not a leaf '
              'in requirements.md');
        }
        final prior = claims[id];
        if (prior != null) {
          problems.add('leaf `$id` claimed twice: $prior and $kind/$name');
        }
        claims[id] = '$kind/$name';
        diskCases[id] = slug;
      }

      // Manifest ⇄ disk: a case file not registered never runs; a
      // registration without a file is stale.
      final registered = {for (final c in manifests[kind]!) c.id: c.slug};
      for (final id in diskCases.keys) {
        if (registered[id] != diskCases[id]) {
          problems.add('$kind/cases/${diskCases[id]}.$id.case.dart exists '
              'but is not registered in $kind/manifest.dart');
        }
      }
      for (final c in manifests[kind]!) {
        if (diskCases[c.id] != c.slug) {
          problems.add('$kind/manifest.dart registers ${c.caseFileName} '
              'but no such file exists');
        }
      }
    }

    for (final leaf in leaves) {
      if (!claims.containsKey(leaf)) {
        problems.add('leaf `$leaf` has no case — red by default until one '
            'claims it');
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('non-image kinds carry no images; image kinds carry no strays', () {
    final problems = <String>[];
    for (final entry in kinds.entries) {
      final pngs = Directory('${entry.key}/cases')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.png'))
          .toSet();
      switch (entry.value) {
        case KindImages.none:
          // A screenshot cannot verify a gesture or a pure rule — a PNG
          // here means a case is green-lighting something it can't check.
          problems.addAll(
              pngs.map((n) => '${entry.key}/cases/$n: image in a coded kind'));
        case KindImages.one:
        case KindImages.animation:
          // Both expect exactly one `<slug>.<id>.png` per case — a still for
          // `one`, an animated PNG (APNG) for `animation`. Same on-disk shape.
          final expected = manifests[entry.key]!
              .map((c) => '${c.slug}.${c.id}.png')
              .toSet();
          problems.addAll(pngs
              .difference(expected)
              .map((n) => '${entry.key}/cases/$n: stray golden (no case)'));
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
