import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Long-pressing Ada's entry opens the confirmation dialog: titled "Delete
/// from your feed?", body "This removes your copy only — other recipients
/// keep theirs.", with Cancel and Delete actions.
final theCase = ScreenCase(
  id: '9.1',
  slug: 'deleting',
  description: 'long-pressing an entry opens the "Delete from your feed?" '
      'confirmation dialog with Cancel / Delete actions',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([sampleMessage()]), // one entry from Ada Lovelace
  act: (tester, world) async {
    await tester.longPress(find.byType(ListTile));
  },
);
