import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// A shout arrives: standing on Rothschild Blvd with an empty feed, Ada —
/// 400 m up the boulevard — shouts; the message lands instantly with the
/// SHOUT badge and its megaphone marker pins the map where she stood.
final theCase = SagaCase(
  id: '11.2',
  slug: 'shout_arrives',
  description: 'a shout from Ada 400 m away lands in the feed with the '
      'SHOUT badge and its megaphone marker on the map',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
  },
  steps: [
    SagaStep('standing on Rothschild Blvd, feed empty',
        (tester, world) async {}),
    SagaStep(
        'Ada shouts from up the boulevard — it lands instantly with the '
        'SHOUT badge', (tester, world) async {
      world.receive(sampleMessage(
        messageId: 'ada-shout',
        senderName: 'Ada Lovelace',
        kind: MessageKind.shout,
        lat: 32.0767, // 400 m north of where you stand
        lng: 34.7799,
        age: Duration.zero, // sent right now: sentAt == world.referenceNow
        distanceM: 400,
      ));
    }),
    SagaStep(
        'the deep-orange megaphone marker pins the map 400 m up the '
        'boulevard — exactly where she stood', (tester, world) async {}),
  ],
);
