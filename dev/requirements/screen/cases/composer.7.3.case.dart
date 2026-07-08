import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Whisper is the default selection, so the empty input carries the whisper
/// hint: "Whisper to people within 150 m…".
final theCase = ScreenCase(
  id: '7.3',
  slug: 'composer',
  description: 'with whisper selected the input hint reads "Whisper to '
      'people within 150 m…"',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const []),
);
