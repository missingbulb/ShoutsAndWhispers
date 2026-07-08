import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in and located, but the first feed snapshot has not arrived yet:
/// the feed area shows a progress spinner while it waits.
final theCase = ScreenCase(
  id: '6.1',
  slug: 'feed',
  description: 'before the first feed snapshot the feed area shows a '
      'progress spinner',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799), // no feed emitted — the stream stays waiting
);
