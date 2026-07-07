import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// A send frozen in flight (the fake never completes it): the send button
/// shows a progress spinner in place of the send icon.
final theCase = ScreenCase(
  id: '7.8',
  slug: 'composer',
  description: 'while a send is in flight the send button shows a progress '
      'spinner',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const []),
  act: (tester, world) async {
    await tester.enterText(find.byType(TextField), 'Anyone near the fountain?');
    await tester.pump(); // the send button unlocks
    world.messages.pendingSend = Completer<void>(); // never completed
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
  },
);
