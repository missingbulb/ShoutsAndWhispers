import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// One message from Ada Lovelace in the feed: her name leads the entry in
/// emphasized type, with the message text beneath it.
final theCase = ScreenCase(
  id: '6.3',
  slug: 'feed',
  description: 'a feed entry shows the sender\'s name (emphasized) and the '
      'message text',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([sampleMessage()]), // Ada Lovelace, coffee on Rothschild
);
