import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/ui/copy.dart';

import '../../shared/cases.dart';

/// Signed in, located, feed empty — then location services go off: the
/// banner between map and feed states the services-off copy verbatim (the
/// shared constant, never retyped), with the Retry action.
final theCase = ScreenCase(
  id: '5.1',
  slug: 'location_banner',
  description: 'when location services are off, the banner reads exactly '
      'the services-off copy',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const [])
    ..locationError(locationServicesOffCopy),
);
