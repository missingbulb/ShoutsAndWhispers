import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// The composer at rest: the range toggle offers exactly two segments —
/// whisper (ear icon) and shout (megaphone icon). The feed is kept empty so
/// nothing distracts from the composer row.
final theCase = ScreenCase(
  id: '7.1',
  slug: 'composer',
  description: 'the range toggle offers exactly two segments: whisper (ear '
      'icon) and shout (megaphone icon)',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const []),
);
