import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in with a fix on Rothschild Blvd and an empty feed: the map sits
/// at neighborhood zoom, centered on the device, with the white-ringed blue
/// self dot at the fix — the only marker in view.
final theCase = ScreenCase(
  id: '4.2',
  slug: 'map',
  description: 'after a fix, the self marker — a white-ringed blue dot — '
      'sits at the device position',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const []),
);
