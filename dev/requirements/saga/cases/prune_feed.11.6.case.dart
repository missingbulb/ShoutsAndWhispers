import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Pruning your feed: long-press Ada's old shout, confirm "your copy only",
/// and both the feed row and its megaphone marker disappear — Grace's
/// whisper (and her marker) stay put.
final theCase = SagaCase(
  id: '11.6',
  slug: 'prune_feed',
  description: 'long-press plus Delete removes the entry from the feed and '
      'its marker from the map',
  arrange: (world) {
    world
      ..signIn(sampleUser)
      ..fix(32.0731, 34.7799)
      ..feedNow([
        // Newest first: Grace's fresh whisper, then Ada's older shout —
        // two messages at two distinct spots.
        sampleMessage(
          index: 1, // Grace Hopper
          messageId: 'grace-whisper',
          kind: MessageKind.whisper,
          lat: 32.0735,
          lng: 34.7803,
          age: const Duration(minutes: 4),
          distanceM: 60,
        ),
        sampleMessage(
          messageId: 'ada-shout',
          senderName: 'Ada Lovelace',
          kind: MessageKind.shout,
          lat: 32.0767,
          lng: 34.7799,
          age: const Duration(minutes: 12),
          distanceM: 400,
        ),
      ]);
  },
  steps: [
    SagaStep('two messages, two markers', (tester, world) async {}),
    SagaStep('delete? your copy only', (tester, world) async {
      await tester.longPress(find.text('Ada Lovelace'));
    }),
    SagaStep('gone from the feed — and its marker left the map',
        (tester, world) async {
      // FakeMessagesPort.deleteFeedEntry re-emits the pruned feed.
      await tester.tap(find.text('Delete'));
    }),
  ],
);
