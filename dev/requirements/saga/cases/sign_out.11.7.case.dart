import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signing out: from a lived-in home screen — fix on the map, a message in
/// the feed — the app-bar sign-out lands back on the sign-in screen.
final theCase = SagaCase(
  id: '11.7',
  slug: 'sign_out',
  description: 'sign-out from a lived-in home screen lands back on the '
      'sign-in screen',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow([sampleMessage()]);
  },
  steps: [
    SagaStep('a lived-in session', (tester, world) async {}),
    SagaStep('back at the door — sign-in screen', (tester, world) async {
      await tester.tap(find.byTooltip('Sign out'));
    }),
  ],
);
