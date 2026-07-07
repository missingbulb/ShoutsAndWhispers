import 'package:flutter_test/flutter_test.dart';

import '../saga/manifest.dart' as saga;
import '../screen/manifest.dart' as screen;
import '../shared/gallery.dart';
import '../shared/spec.dart' as spec;

/// The committed requirements.md must equal the gallery generator's output:
/// the prose is hand-authored, the image lines are derived — regenerate with
/// `dart run tool/build_gallery.dart` (refresh_goldens.py does it for you),
/// never hand-edit them.
void main() {
  test('requirements.md gallery is current (regenerate, never hand-edit)', () {
    final committed = spec.specFile().readAsStringSync();
    final regenerated = buildGallery(
      committed,
      screenCases: screen.cases,
      sagaCases: saga.cases,
    );
    expect(committed, regenerated,
        reason: 'gallery drift — run: dart run tool/build_gallery.dart');
  });
}
