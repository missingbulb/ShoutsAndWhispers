import 'package:flutter_test/flutter_test.dart';

import '../logic/manifest.dart' as logic;

/// Runs every logic case: a pure product rule verified against shipped code.
void main() {
  for (final c in logic.cases) {
    test('`${c.id}` ${c.description}', c.verify);
  }
}
