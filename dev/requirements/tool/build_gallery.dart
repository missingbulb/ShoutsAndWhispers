import 'dart:io';

import '../saga/manifest.dart' as saga;
import '../screen/manifest.dart' as screen;
import '../shared/gallery.dart';

/// Rewrites the machine-managed gallery lines in requirements.md from the
/// current case manifests. Run from dev/requirements/:
///   dart run tool/build_gallery.dart
/// (refresh_goldens.py runs it after regenerating the goldens.)
void main() {
  final file = File('requirements.md');
  final updated = buildGallery(
    file.readAsStringSync(),
    screenCases: screen.cases,
    sagaCases: saga.cases,
  );
  file.writeAsStringSync(updated);
  stdout.writeln('requirements.md gallery rebuilt.');
}
