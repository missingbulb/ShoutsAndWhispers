import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// A single whisper in the feed: the entry carries the indigo WHISPER badge
/// beside the sender's name.
final theCase = ScreenCase(
  id: '6.4',
  slug: 'feed',
  description: 'a whisper entry carries the indigo WHISPER badge',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([sampleMessage()]), // sampleMessage defaults to a whisper
);
