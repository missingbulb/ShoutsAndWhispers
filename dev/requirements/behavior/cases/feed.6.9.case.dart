import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Newest first, top to bottom: three messages aged 5/10/15 minutes are
/// emitted in scrambled order and must still render newest at the top.
final theCase = BehaviorCase(
  id: '6.9',
  slug: 'feed',
  description: 'feed entries render newest first',
  run: (tester, world) async {
    final newest = sampleMessage(index: 0, age: const Duration(minutes: 5));
    final middle = sampleMessage(index: 1, age: const Duration(minutes: 10));
    final oldest = sampleMessage(index: 2, age: const Duration(minutes: 15));
    world
      ..signIn()
      ..feedNow([middle, oldest, newest]); // deliberately scrambled
    await pumpWorld(tester, world);

    // Compare the vertical positions of the three sender-name texts.
    final double newestDy = tester.getTopLeft(find.text(newest.senderName)).dy;
    final double middleDy = tester.getTopLeft(find.text(middle.senderName)).dy;
    final double oldestDy = tester.getTopLeft(find.text(oldest.senderName)).dy;
    expect(newestDy, lessThan(middleDy));
    expect(middleDy, lessThan(oldestDy));
  },
);
