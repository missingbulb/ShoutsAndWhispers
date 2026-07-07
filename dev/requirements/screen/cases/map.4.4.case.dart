import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in and fixed on Rothschild Blvd; one shout from Ada landed,
/// sent ~330 m north of the fix: its megaphone marker, in deep orange,
/// stands at the send location just above the blue dot.
final theCase = ScreenCase(
  id: '4.4',
  slug: 'map',
  description: 'a received shout is marked at its send location with the '
      'megaphone icon in deep orange',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([
      sampleMessage(
        kind: MessageKind.shout,
        lat: 32.0761, // ~330 m north of the fix — visible at zoom 15
        lng: 34.7799,
        distanceM: 330,
      ),
    ]),
);
