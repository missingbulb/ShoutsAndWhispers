import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ports/ports.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// A failed send shows the failure snackbar and keeps the typed text in the
/// field so the user can retry.
final theCase = BehaviorCase(
  id: '8.4',
  slug: 'sending',
  description: 'a failed send shows "Send failed: …" and keeps the text',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    world.messages.onSend = (_) => throw const SendException('rate limited');
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await settle(tester);

    final Finder snackText = find.descendant(
      of: find.byType(SnackBar),
      matching: find.textContaining('Send failed:'),
    );
    expect(snackText, findsOneWidget);
    expect(tester.widget<Text>(snackText).data, 'Send failed: rate limited');

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'hello');
  },
);
