import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The quiet option is the default: a fresh composer has whisper selected.
final theCase = BehaviorCase(
  id: '7.2',
  slug: 'composer',
  description: 'whisper is preselected in the range toggle',
  run: (tester, world) async {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    final toggle = tester.widget<SegmentedButton<MessageKind>>(
      find.byType(SegmentedButton<MessageKind>),
    );
    expect(toggle.selected, {MessageKind.whisper});
  },
);
