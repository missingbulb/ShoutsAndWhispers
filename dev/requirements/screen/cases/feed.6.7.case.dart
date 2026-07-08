import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Your own message in the feed: the meta line ends in "you" instead of a
/// distance — you know where you were.
final theCase = ScreenCase(
  id: '6.7',
  slug: 'feed',
  description: 'your own message\'s meta line shows "you" instead of a '
      'distance',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([sampleMessage(isOwn: true)]),
);
