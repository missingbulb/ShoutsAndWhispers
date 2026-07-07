import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The keyboard's send action submits just like the button: one send call
/// reaches the backend.
final theCase = BehaviorCase(
  id: '8.5',
  slug: 'sending',
  description: 'submitting from the keyboard sends, same as the button',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester);

    expect(world.messages.sends, hasLength(1));
    expect(world.messages.sends.single.text, 'hello');
  },
);
