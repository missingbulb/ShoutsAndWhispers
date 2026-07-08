import 'package:intl/intl.dart';

import '../models/feed_message.dart';

/// "just now" / "12 min ago" / "3 h ago", or an absolute date once a message
/// is a day old. [now] is injected (the UI passes `Clock.now()`) so the label
/// is deterministic under a fixed clock.
String relativeTime(DateTime sentAt, DateTime now) {
  final Duration age = now.difference(sentAt);
  if (age.inSeconds < 60) return 'just now';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  if (age.inHours < 24) return '${age.inHours} h ago';
  // Explicit pattern: MMMd().add_jm() joins with a bare space ("May 28 3:40
  // PM"); the spec (dev/requirements §10.4) wants the conventional comma.
  return DateFormat('MMM d, h:mm a').format(sentAt);
}

/// "you" on own messages, otherwise how far away the message was sent.
String distanceLabel(FeedMessage message) {
  if (message.isOwn) return 'you';
  final double d = message.distanceM;
  if (d < 1000) return '${d.round()} m away';
  return '${(d / 1000).toStringAsFixed(1)} km away';
}
