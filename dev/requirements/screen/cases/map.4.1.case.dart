import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Signed in, feed empty, but no GPS fix yet: the map rests at the world
/// view (zoom far out) and carries no self marker — the blue dot only
/// exists once the device knows where it is.
final theCase = ScreenCase(
  id: '4.1',
  slug: 'map',
  description: 'before the first GPS fix, the map shows the world view with '
      'no self marker',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..feedNow(const []), // deliberately NO fix
);
