import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Ada Lovelace has no photo (sample senders never do — senderPhotoUrl is
/// null): her avatar falls back to the letter "A".
final theCase = ScreenCase(
  id: '6.8',
  slug: 'feed',
  description: 'a sender without a photo gets an avatar with the first '
      'letter of their name',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([sampleMessage(senderName: 'Ada Lovelace')]),
);
