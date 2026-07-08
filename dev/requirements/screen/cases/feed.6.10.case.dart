import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// The feed stream breaks after the app is up: the feed area reports
/// "Feed unavailable: …" with the error. The error is emitted in [act]
/// because stream errors reach only live listeners — they are not replayed
/// to a subscriber that attaches later.
final theCase = ScreenCase(
  id: '6.10',
  slug: 'feed',
  description: 'a broken feed stream shows "Feed unavailable: …" with the '
      'error',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799),
  act: (tester, world) async {
    world.feedError(StateError('permission-denied'));
  },
);
