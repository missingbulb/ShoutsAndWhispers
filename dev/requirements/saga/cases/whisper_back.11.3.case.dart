import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/ports/ports.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Whispering back: type a reply to Ada's shout, watch the send button spin
/// while the send is held in flight, then land the "Delivered to 1 people
/// nearby" snackbar with your own whisper topping the feed as "you".
final theCase = SagaCase(
  id: '11.3',
  slug: 'whisper_back',
  description: 'a whisper reply: the button spins in flight, then the '
      'delivery snackbar and your own entry marked "you"',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow([
        sampleMessage(
          messageId: 'ada-shout',
          senderName: 'Ada Lovelace',
          kind: MessageKind.shout,
          lat: 32.0767,
          lng: 34.7799,
          age: const Duration(minutes: 5),
          distanceM: 400,
        ),
      ]);
    // Script the backend: this send reaches exactly one person.
    world.messages.onSend =
        (call) async => const SendResult(messageId: 'm1', recipientCount: 1);
  },
  steps: [
    SagaStep('a reply, kept to a whisper', (tester, world) async {
      await tester.enterText(find.byType(TextField), 'on my way!');
    }),
    SagaStep('in flight — the button spins', (tester, world) async {
      // Hold the send in flight: the fake awaits this completer first.
      world.messages.pendingSend = Completer<void>();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
    }),
    SagaStep(
        'delivered to 1 person nearby — your whisper tops the feed as "you"',
        (tester, world) async {
      // Release the send: the fake finishes awaiting pendingSend, then
      // produces the scripted SendResult — snackbar up, input cleared.
      world.messages.pendingSend!.complete();
      world.messages.pendingSend = null;
      await settle(tester);
      // Your own copy of the whisper reaches your feed.
      world.receive(sampleMessage(
        messageId: 'm1',
        isOwn: true,
        text: 'on my way!',
        kind: MessageKind.whisper,
        lat: 32.0731,
        lng: 34.7799,
        age: Duration.zero, // sent right now: sentAt == world.referenceNow
        distanceM: 0,
      ));
    }),
  ],
);
