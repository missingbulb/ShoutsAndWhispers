import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Everything in place: with a GPS fix and non-blank text, the send button
/// is enabled.
final theCase = BehaviorCase(
  id: '7.7',
  slug: 'composer',
  description: 'send is enabled with a fix and non-blank text',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    final IconButton send = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(send.onPressed, isNotNull);
  },
);
