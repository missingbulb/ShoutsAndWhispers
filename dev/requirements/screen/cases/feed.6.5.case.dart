import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// A single shout in the feed: the entry carries the deep-orange SHOUT badge
/// beside the sender's name.
final theCase = ScreenCase(
  id: '6.5',
  slug: 'feed',
  description: 'a shout entry carries the deep-orange SHOUT badge',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([sampleMessage(kind: MessageKind.shout)]),
);
