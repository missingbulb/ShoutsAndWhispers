import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/models/feed_message.dart';

import '../../shared/cases.dart';

/// The wire values for message kinds are exactly 'whisper' and 'shout',
/// round-tripping through [MessageKind.fromWire]; an unknown or missing wire
/// value falls back to shout rather than crashing the feed.
final theCase = LogicCase(
  id: '10.8',
  slug: 'wire',
  description: 'wire values are exactly "whisper"/"shout", round-tripping; '
      'unknown or missing values fall back to shout',
  verify: () {
    expect(MessageKind.whisper.wire, 'whisper');
    expect(MessageKind.shout.wire, 'shout');
    expect(MessageKind.fromWire('whisper'), MessageKind.whisper);
    expect(MessageKind.fromWire('shout'), MessageKind.shout);
    expect(
      MessageKind.fromWire(MessageKind.whisper.wire),
      MessageKind.whisper,
    );
    expect(MessageKind.fromWire(MessageKind.shout.wire), MessageKind.shout);
    expect(MessageKind.fromWire('gibberish'), MessageKind.shout);
    expect(MessageKind.fromWire(null), MessageKind.shout);
  },
);
