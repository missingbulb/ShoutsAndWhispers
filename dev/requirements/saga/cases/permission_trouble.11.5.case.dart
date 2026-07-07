import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/ui/copy.dart';

import '../../shared/cases.dart';

/// Permission trouble mid-session: the location permission is revoked — the
/// banner explains in the shipped copy and the stale fix is cleared so send
/// locks. Retry after re-granting clears the banner and restores the fix.
final theCase = SagaCase(
  id: '11.5',
  slug: 'permission_trouble',
  description: 'permission revoked mid-session shows the banner and locks '
      'send; Retry after re-granting restores the fix',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow([sampleMessage()]);
  },
  steps: [
    SagaStep('located and listening', (tester, world) async {}),
    SagaStep('permission revoked — the app says so and locks send',
        (tester, world) async {
      world.locationError(locationPermissionDeniedCopy);
      world.location.emitPosition(null); // the stale fix is cleared
    }),
    SagaStep('permission restored: banner gone, blue dot back',
        (tester, world) async {
      await tester.tap(find.text('Retry'));
      world.locationError(null);
      world.fix(32.0731, 34.7799);
    }),
  ],
);
