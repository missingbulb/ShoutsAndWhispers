import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Confirming the dialog requests deletion of exactly that entry — its
/// message id and nothing else — from the backend.
final theCase = BehaviorCase(
  id: '9.3',
  slug: 'deleting',
  description: 'Delete requests deletion of exactly that entry',
  run: (tester, world) async {
    final message = sampleMessage();
    world
      ..signIn()
      ..feedNow([message]);
    await pumpWorld(tester, world);

    await tester.longPress(find.byType(ListTile));
    await settle(tester);
    expect(find.text('Delete from your feed?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(world.messages.deletes, [message.messageId]);
  },
);
