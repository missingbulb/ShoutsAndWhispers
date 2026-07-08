import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Cancel is a no-op: dismissing the delete confirmation leaves the entry
/// in place and requests no deletion from the backend.
final theCase = BehaviorCase(
  id: '9.2',
  slug: 'deleting',
  description: 'Cancel leaves the entry in place and deletes nothing',
  run: (tester, world) async {
    final message = sampleMessage();
    world
      ..signIn()
      ..feedNow([message]);
    await pumpWorld(tester, world);

    await tester.longPress(find.byType(ListTile));
    await settle(tester);
    expect(find.text('Delete from your feed?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(world.messages.deletes, isEmpty);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text(message.text), findsOneWidget);
  },
);
