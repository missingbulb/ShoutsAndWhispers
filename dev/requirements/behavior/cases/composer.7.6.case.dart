import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Whitespace is not a message: with a fix but only spaces typed, the send
/// button stays disabled.
final theCase = BehaviorCase(
  id: '7.6',
  slug: 'composer',
  description: 'send is disabled with whitespace-only text',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final IconButton send = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(send.onPressed, isNull);
  },
);
