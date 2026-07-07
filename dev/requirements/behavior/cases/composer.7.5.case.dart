import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Without a GPS fix the send button stays disabled even with text typed,
/// and its tooltip says what it is waiting for.
final theCase = BehaviorCase(
  id: '7.5',
  slug: 'composer',
  description: 'send is disabled without a GPS fix, with the waiting tooltip',
  run: (tester, world) async {
    world
      ..signIn()
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    final IconButton send = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(send.onPressed, isNull);
    expect(find.byTooltip('Waiting for a GPS fix…'), findsOneWidget);
  },
);
