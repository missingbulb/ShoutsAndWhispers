import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ports/ports.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// A send that reaches three neighbors: after it succeeds, a snackbar slides
/// in reading "Delivered to 3 people nearby".
final theCase = ScreenCase(
  id: '8.2',
  slug: 'sending',
  description: 'after a successful send a snackbar reads "Delivered to N '
      'people nearby" with the recipient count',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    world.messages.onSend = (call) async =>
        const SendResult(messageId: 'm1', recipientCount: 3);
  },
  act: (tester, world) async {
    await tester.enterText(find.byType(TextField), 'Anyone up for coffee?');
    await tester.pump(); // the send button unlocks
    await tester.tap(find.byIcon(Icons.send));
    await settle(tester); // the send resolves and the snackbar slides in
  },
);
