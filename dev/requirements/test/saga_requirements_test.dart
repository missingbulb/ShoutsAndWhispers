import 'package:flutter_test/flutter_test.dart';

import '../saga/manifest.dart' as saga;
import '../shared/harness.dart';

/// Runs every saga: the real app shell driven step by step against the fake
/// world, capturing one golden storyboard frame per step. Same golden
/// ownership rules as screens.
void main() {
  for (final c in saga.cases) {
    testWidgets('`${c.id}` ${c.description}', (tester) async {
      await runSagaCase(tester, c);
    });
  }
}
