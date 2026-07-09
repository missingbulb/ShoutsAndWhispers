import 'package:flutter_test/flutter_test.dart';

import '../saga/manifest.dart' as saga;
import '../shared/harness.dart';

/// Runs every saga: the real app shell driven step by step against the fake
/// world, recording the UI's motion into one animated PNG (APNG) golden
/// compared by exact identity (see shared/saga_animation.dart). Same golden
/// ownership rules as screens.
void main() {
  for (final c in saga.cases) {
    testWidgets('`${c.id}` ${c.description}', (tester) async {
      await runSagaCase(tester, c);
    });
  }
}
