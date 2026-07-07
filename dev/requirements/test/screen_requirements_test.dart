import 'package:flutter_test/flutter_test.dart';

import '../screen/manifest.dart' as screen;
import '../shared/harness.dart';

/// Runs every screen case: real app shell, scripted fakes, one golden per
/// leaf. Regenerate goldens with `flutter test --update-goldens` (via
/// refresh_goldens.py) — committed goldens are owner-approved expecteds and
/// are never re-baselined to turn a red case green.
void main() {
  for (final c in screen.cases) {
    testWidgets('`${c.id}` ${c.description}', (tester) async {
      await runScreenCase(tester, c);
    });
  }
}
