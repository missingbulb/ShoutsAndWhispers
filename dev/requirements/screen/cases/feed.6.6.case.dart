import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// A message sent exactly 12 minutes before the pinned clock, 320 m away:
/// the meta line reads exactly "12 min ago · 320 m away".
final theCase = ScreenCase(
  id: '6.6',
  slug: 'feed',
  description: 'an entry\'s meta line reads "<relative time> · <distance>", '
      'here "12 min ago · 320 m away"',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([
      sampleMessage(age: const Duration(minutes: 12), distanceM: 320),
    ]),
);
