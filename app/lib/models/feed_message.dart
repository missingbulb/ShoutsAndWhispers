import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// The two message ranges (docs/DESIGN.md §1).
enum MessageKind {
  /// 1,500 m radius — the whole neighborhood.
  shout,

  /// 150 m radius — the people right around you.
  whisper;

  /// Parses the wire value (`'shout'` | `'whisper'`). Unknown or missing
  /// values fall back to [shout] so a feed entry written by a newer backend
  /// still renders instead of crashing the feed.
  static MessageKind fromWire(Object? value) {
    switch (value) {
      case 'whisper':
        return MessageKind.whisper;
      case 'shout':
        return MessageKind.shout;
      default:
        return MessageKind.shout;
    }
  }

  /// The wire value sent to / received from the backend.
  String get wire => name;
}

/// One entry of `users/{uid}/feed/{messageId}` (docs/DESIGN.md §3).
class FeedMessage {
  const FeedMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.text,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.sentAt,
    required this.distanceM,
    required this.isOwn,
  });

  /// Builds a [FeedMessage] from a Firestore feed document.
  ///
  /// Defensive about missing/mistyped fields: the server writes `sentAt` as a
  /// Firestore server timestamp, so during latency compensation a snapshot
  /// can momentarily carry `sentAt: null` — that falls back to "now", which
  /// is within clock skew of what the server will stamp.
  factory FeedMessage.fromMap(String id, Map<String, dynamic> data) {
    return FeedMessage(
      messageId: _string(data['messageId']) ?? id,
      senderId: _string(data['senderId']) ?? '',
      senderName: _string(data['senderName']) ?? 'Someone',
      senderPhotoUrl: _string(data['senderPhotoUrl']),
      text: _string(data['text']) ?? '',
      kind: MessageKind.fromWire(data['kind']),
      lat: _double(data['lat']) ?? 0,
      lng: _double(data['lng']) ?? 0,
      sentAt: _dateTime(data['sentAt']) ?? DateTime.now(),
      distanceM: _double(data['distanceM']) ?? 0,
      isOwn: data['isOwn'] == true,
    );
  }

  /// Same id as the canonical `messages/{messageId}` document.
  final String messageId;
  final String senderId;

  /// From the sender's verified auth token — never client input.
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final MessageKind kind;

  /// Where the message was sent from (for the map marker).
  final double lat;
  final double lng;
  final DateTime sentAt;

  /// How far *you* were from the sender when the message reached you.
  final double distanceM;

  /// True on the sender's own copy.
  final bool isOwn;

  static String? _string(Object? value) => value is String ? value : null;

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
