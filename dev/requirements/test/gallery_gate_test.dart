import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../saga/manifest.dart' as saga;
import '../screen/manifest.dart' as screen;
import '../shared/gallery.dart';
import '../shared/spec.dart' as spec;

/// The committed requirements.md must equal the gallery generator's output:
/// the prose is hand-authored, the image lines are derived — regenerate via
/// refresh_goldens.py, never hand-edit them.
///
/// This test doubles as the regenerator (the manifests import Flutter code,
/// so the generator must run inside the flutter_test harness — plain
/// `dart run` cannot compile it): with REQ_UPDATE_GALLERY=1 in the
/// environment it rewrites requirements.md instead of comparing.
void main() {
  final updating = Platform.environment['REQ_UPDATE_GALLERY'] == '1';

  test(
    updating
        ? 'regenerating the requirements.md gallery'
        : 'requirements.md gallery is current (regenerate, never hand-edit)',
    () {
      final file = spec.specFile();
      final committed = file.readAsStringSync();
      final regenerated = buildGallery(
        committed,
        screenCases: screen.cases,
        sagaCases: saga.cases,
      );
      if (updating) {
        file.writeAsStringSync(regenerated);
        // ignore: avoid_print — the refresh script watches for this marker.
        print('requirements.md gallery rebuilt.');
        return;
      }
      expect(committed, regenerated,
          reason: 'gallery drift — run: python3 refresh_goldens.py '
              '(or REQ_UPDATE_GALLERY=1 flutter test '
              'test/gallery_gate_test.dart)');
    },
  );
}
