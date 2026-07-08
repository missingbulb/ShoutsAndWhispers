// Adapter parsing coverage that needs no Firebase initialization: Timestamp
// is a plain value class, and convertTimestamps is a top-level function.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/adapters/firebase_messages_adapter.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';

void main() {
  group('convertTimestamps', () {
    test('converts Timestamp values to DateTime and leaves the rest alone',
        () {
      final sentAt = DateTime.utc(2026, 7, 7, 12, 30);
      final converted = convertTimestamps(<String, dynamic>{
        'sentAt': Timestamp.fromDate(sentAt),
        'text': 'hello',
        'distanceM': 320,
        'isOwn': false,
        'senderPhotoUrl': null,
      });

      // Timestamp.toDate() yields a local-zone DateTime; compare instants.
      expect(converted['sentAt'], isA<DateTime>());
      expect((converted['sentAt'] as DateTime).toUtc(), sentAt);
      expect(converted['text'], 'hello');
      expect(converted['distanceM'], 320);
      expect(converted['isOwn'], false);
      expect(converted['senderPhotoUrl'], isNull);
    });

    test('feeds FeedMessage.fromMap the DateTime it expects', () {
      final sentAt = DateTime.utc(2026, 7, 7, 12, 30);
      final message = FeedMessage.fromMap(
        'msg-1',
        convertTimestamps(<String, dynamic>{
          'sentAt': Timestamp.fromDate(sentAt),
          'kind': 'whisper',
        }),
      );
      expect(message.sentAt.toUtc(), sentAt);
      expect(message.kind, MessageKind.whisper);
    });
  });
}
