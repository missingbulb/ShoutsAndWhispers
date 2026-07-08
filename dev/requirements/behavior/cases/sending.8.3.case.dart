import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// A successful send clears the input field, ready for the next message.
final theCase = BehaviorCase(
  id: '8.3',
  slug: 'sending',
  description: 'a successful send clears the input field',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await settle(tester);

    expect(world.messages.sends, hasLength(1)); // the send happened…
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty); // …and the input was cleared.
  },
);
