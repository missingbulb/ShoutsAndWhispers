import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The outgoing request: sending passes the trimmed text, the selected
/// kind, and the current device position to the backend — exactly once.
final theCase = BehaviorCase(
  id: '8.1',
  slug: 'sending',
  description: 'send passes trimmed text, selected kind, and the fix',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.tap(find.byIcon(Icons.campaign)); // select the shout segment
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  hi there  ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await settle(tester);

    expect(world.messages.sends, hasLength(1));
    final call = world.messages.sends.single;
    expect(call.text, 'hi there');
    expect(call.kind, MessageKind.shout);
    expect(call.at.lat, 32.0731);
    expect(call.at.lng, 34.7799);
  },
);
