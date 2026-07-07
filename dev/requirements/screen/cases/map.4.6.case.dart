import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in and fixed on Rothschild Blvd with a three-entry feed — a shout
/// from Ada to the north, a whisper from Grace to the south-east, and your
/// own whisper to the west: all three markers are on the map alongside the
/// blue self dot, one per feed entry, own message included.
final theCase = ScreenCase(
  id: '4.6',
  slug: 'map',
  description: 'every feed entry — including your own messages — has its '
      'marker on the map',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow([
      sampleMessage(
        index: 0, // Ada Lovelace
        kind: MessageKind.shout,
        lat: 32.0761, // ~330 m north of the fix
        lng: 34.7799,
        distanceM: 330,
      ),
      sampleMessage(
        index: 1, // Grace Hopper
        kind: MessageKind.whisper,
        lat: 32.0711, // ~310 m south-east of the fix
        lng: 34.7824,
        distanceM: 310,
      ),
      sampleMessage(
        index: 2,
        isOwn: true, // your own copy — still gets a marker
        kind: MessageKind.whisper,
        lat: 32.0736,
        lng: 34.7769, // ~290 m west of the fix
      ),
    ]),
);
