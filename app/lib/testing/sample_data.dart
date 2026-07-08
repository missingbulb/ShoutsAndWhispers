/// Deterministic sample users and messages (docs/UI-ARCHITECTURE.md §"The
/// fake world"). All timestamps are offsets from [referenceNow], so
/// relative-time labels ("12 min ago") render identically forever.
library;

import '../models/feed_message.dart';
import '../ports/ports.dart';

/// The pinned reference time: 2026-06-01 12:00 local. `FakeWorld`'s clock is
/// fixed to this instant.
final DateTime referenceNow = DateTime(2026, 6, 1, 12, 0);

/// The default signed-in user.
const AppUser sampleUser = AppUser(uid: 'me', displayName: 'You Yourself');

const List<String> _senderNames = <String>[
  'Ada Lovelace',
  'Grace Hopper',
  'Alan Turing',
  'Katherine Johnson',
];

const List<String> _texts = <String>[
  'Anyone up for coffee on Rothschild?',
  'Lost keys near the fountain — anyone seen them?',
  'Free couch on the corner, first come first served!',
  'Pickup basketball in 20 min, need two more.',
];

/// Builds a deterministic [FeedMessage]. Everything derives from [index]
/// unless overridden: senders cycle through famous names, photo URLs are
/// always null (no network avatars), coordinates step along Rothschild Blvd
/// in Tel Aviv around (32.0731, 34.7799), and [age] defaults to
/// `12 + 9 * index` minutes before [referenceNow].
FeedMessage sampleMessage({
  int index = 0,
  String? messageId,
  String? senderId,
  String? senderName,
  String? text,
  MessageKind kind = MessageKind.whisper,
  double? lat,
  double? lng,
  Duration? age,
  double? distanceM,
  bool isOwn = false,
}) {
  return FeedMessage(
    messageId: messageId ?? 'sample-$index',
    senderId: senderId ?? (isOwn ? sampleUser.uid : 'sender-$index'),
    senderName: senderName ??
        (isOwn
            ? (sampleUser.displayName ?? 'You Yourself')
            : _senderNames[index % _senderNames.length]),
    senderPhotoUrl: null,
    text: text ?? _texts[index % _texts.length],
    kind: kind,
    lat: lat ?? 32.0731 + 0.0004 * index,
    lng: lng ?? 34.7799 - 0.0003 * index,
    sentAt: referenceNow.subtract(age ?? Duration(minutes: 12 + 9 * index)),
    distanceM: distanceM ?? (isOwn ? 0 : 80.0 + 45.0 * index),
    isOwn: isOwn,
  );
}
