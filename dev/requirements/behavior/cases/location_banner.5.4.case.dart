import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ui/copy.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// A healthy world shows no banner: none of the three location-problem
/// copies nor the Retry action are rendered.
final theCase = BehaviorCase(
  id: '5.4',
  slug: 'location_banner',
  description: 'no banner is shown when there is no location problem',
  run: (tester, world) async {
    world
      ..signIn()
      ..fix(32.0731, 34.7799)
      ..feedNow(const []);
    await pumpWorld(tester, world);

    expect(find.text('Retry'), findsNothing);
    expect(find.text(locationServicesOffCopy), findsNothing);
    expect(find.text(locationPermissionDeniedCopy), findsNothing);
    expect(find.text(locationPermissionForeverCopy), findsNothing);
  },
);
