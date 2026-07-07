import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/world.dart';

import '../behavior/manifest.dart' as behavior;

/// Runs every behavior case: a driven gesture with coded assertions —
/// no goldens, because a static image cannot verify a click or a call.
/// Each case gets a fresh [FakeWorld]; the case pumps the shell itself
/// (shared/harness.dart `pumpWorld`) and asserts on the fakes' recordings.
void main() {
  for (final c in behavior.cases) {
    testWidgets('`${c.id}` ${c.description}', (tester) async {
      await c.run(tester, FakeWorld());
    });
  }
}
