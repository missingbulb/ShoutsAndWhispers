import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/ui/copy.dart';

import '../../shared/cases.dart';

/// Signed in, located, feed empty — then location permission is permanently
/// denied: the banner between map and feed states the
/// permanently-denied copy verbatim (the shared constant, never retyped),
/// pointing at system settings, with the Retry action.
final theCase = ScreenCase(
  id: '5.3',
  slug: 'location_banner',
  description: 'when permission is permanently denied, the banner reads '
      'exactly the permanently-denied copy',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const [])
    ..locationError(locationPermissionForeverCopy),
);
