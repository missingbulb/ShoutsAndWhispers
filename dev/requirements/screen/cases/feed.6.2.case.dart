import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in, located, nothing received yet: the empty feed states exactly
/// what will land here.
final theCase = ScreenCase(
  id: '6.2',
  slug: 'feed',
  description: 'empty feed reads "Nothing yet — messages sent near you will '
      'land here."',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const []),
);
