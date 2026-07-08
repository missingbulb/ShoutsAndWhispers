import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// The audience is decided at send time: Grace's shout from before you were
/// nearby never reaches you — not even when you later walk to the exact spot
/// she shouted from. Only a fresh shout, sent while you are there, lands.
final theCase = SagaCase(
  id: '11.4',
  slug: 'send_time_audience',
  description: 'the audience is decided at send time — walking to the spot '
      'later never back-fills an old shout; only a fresh one lands',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799) // the corner where you stand
      ..feedNow(const []);
  },
  steps: [
    SagaStep(
        'you are at the corner; two blocks away Grace shouted five minutes '
        'ago — your feed is empty and stays that way',
        (tester, world) async {}),
    SagaStep('you walk to that exact spot — the old shout never back-fills',
        (tester, world) async {
      world.fix(32.0767, 34.7799); // Grace's spot, two blocks north
    }),
    SagaStep('Grace shouts again, now that you are here — THIS one lands',
        (tester, world) async {
      world.receive(sampleMessage(
        messageId: 'grace-shout-fresh',
        senderName: 'Grace Hopper',
        kind: MessageKind.shout,
        lat: 32.0767,
        lng: 34.7799,
        age: Duration.zero, // sent right now: sentAt == world.referenceNow
        distanceM: 0, // you are standing right beside her
      ));
    }),
  ],
);
