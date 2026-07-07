// Pure-Dart model tests — no Firebase types anywhere (the Firestore
// Timestamp -> DateTime conversion happens in the messages adapter).
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';

void main() {
  group('FeedMessage.fromMap', () {
    test('happy path parses every field', () {
      final sentAt = DateTime.utc(2026, 7, 7, 12, 30);
      final message = FeedMessage.fromMap('msg-1', <String, dynamic>{
        'messageId': 'msg-1',
        'senderId': 'uid-42',
        'senderName': 'Ada Lovelace',
        'senderPhotoUrl': 'https://example.com/ada.png',
        'text': 'Anyone up for coffee?',
        'kind': 'whisper',
        'lat': 57.64911,
        'lng': 10.40744,
        'sentAt': sentAt,
        'distanceM': 320,
        'isOwn': false,
      });

      expect(message.messageId, 'msg-1');
      expect(message.senderId, 'uid-42');
      expect(message.senderName, 'Ada Lovelace');
      expect(message.senderPhotoUrl, 'https://example.com/ada.png');
      expect(message.text, 'Anyone up for coffee?');
      expect(message.kind, MessageKind.whisper);
      expect(message.lat, 57.64911);
      expect(message.lng, 10.40744);
      expect(message.sentAt, sentAt);
      expect(message.distanceM, 320.0);
      expect(message.isOwn, false);
    });

    test('parses shout kind and isOwn', () {
      final message = FeedMessage.fromMap('msg-2', <String, dynamic>{
        'kind': 'shout',
        'isOwn': true,
      });
      expect(message.kind, MessageKind.shout);
      expect(message.isOwn, true);
    });

    test('tolerates missing senderPhotoUrl and null sentAt', () {
      final fallbackNow = DateTime(2026, 6, 1, 12, 0);
      final message = FeedMessage.fromMap(
        'msg-3',
        <String, dynamic>{
          'messageId': 'msg-3',
          'senderId': 'uid-7',
          'senderName': 'Grace Hopper',
          // no senderPhotoUrl at all
          'text': 'hello',
          'kind': 'shout',
          'lat': 1.0,
          'lng': 2.0,
          'sentAt': null, // latency compensation: serverTimestamp still pending
          'distanceM': 0,
          'isOwn': true,
        },
        now: () => fallbackNow,
      );

      expect(message.senderPhotoUrl, isNull);
      // Null sentAt falls back to the injected "now".
      expect(message.sentAt, fallbackNow);
    });

    test('tolerates an entirely empty map', () {
      final message = FeedMessage.fromMap('doc-id', <String, dynamic>{});
      expect(message.messageId, 'doc-id'); // falls back to the doc id
      expect(message.senderId, '');
      expect(message.senderName, isNotEmpty);
      expect(message.senderPhotoUrl, isNull);
      expect(message.text, '');
      expect(message.lat, 0);
      expect(message.lng, 0);
      expect(message.distanceM, 0);
      expect(message.isOwn, false);
    });

    test('unknown kind falls back to shout', () {
      final message = FeedMessage.fromMap('msg-4', <String, dynamic>{
        'kind': 'scream',
      });
      expect(message.kind, MessageKind.shout);

      final numericKind = FeedMessage.fromMap('msg-5', <String, dynamic>{
        'kind': 7,
      });
      expect(numericKind.kind, MessageKind.shout);
    });

    test('tolerates mistyped fields', () {
      final message = FeedMessage.fromMap('msg-6', <String, dynamic>{
        'senderName': 12345, // not a string
        'lat': 'not-a-number',
        'sentAt': 'not-a-date', // mistyped sentAt also falls back to now
        'distanceM': 12, // int, not double
        'isOwn': 'yes', // not a bool
      });
      expect(message.senderName, isNotEmpty);
      expect(message.lat, 0);
      expect(message.distanceM, 12.0);
      expect(message.isOwn, false);
    });
  });

  group('MessageKind', () {
    test('wire values match the backend contract', () {
      expect(MessageKind.shout.wire, 'shout');
      expect(MessageKind.whisper.wire, 'whisper');
    });
  });
}
