import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// The whole first-run story: sign in, wait for GPS, get located, meet the
/// empty feed, and see the send button unlock once there are words to send.
final theCase = SagaCase(
  id: '11.1',
  slug: 'first_launch',
  description: 'first launch: sign in with Google, wait for a fix, get '
      'located, meet the empty feed',
  arrange: (world) {}, // fresh install: signed out, no fix, no feed
  steps: [
    SagaStep('a new user opens the app to the sign-in screen',
        (tester, world) async {}),
    SagaStep('signed in: home, waiting for a GPS fix — send is locked',
        (tester, world) async {
      world.signIn(sampleUser);
      await tester.pump();
      world.feedNow(const []);
    }),
    SagaStep('the fix arrives — blue dot on the map, feed honestly empty',
        (tester, world) async {
      world.fix(32.0731, 34.7799);
    }),
    SagaStep('words typed — send unlocks, the whole loop is ready',
        (tester, world) async {
      await tester.enterText(find.byType(TextField), 'hello, neighborhood');
    }),
  ],
);
