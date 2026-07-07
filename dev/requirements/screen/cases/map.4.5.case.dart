import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in and fixed on Rothschild Blvd; one whisper from Ada landed,
/// sent ~330 m south of the fix: its ear marker, in indigo, stands at the
/// send location just below the blue dot.
final theCase = ScreenCase(
  id: '4.5',
  slug: 'map',
  description: 'a received whisper is marked at its send location with the '
      'ear icon in indigo',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([
      sampleMessage(
        kind: MessageKind.whisper,
        lat: 32.0701, // ~330 m south of the fix — visible at zoom 15
        lng: 34.7799,
        distanceM: 330,
      ),
    ]),
);
