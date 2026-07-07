import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ui/copy.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The banner's Retry re-runs the location start-up: tapping it calls the
/// location port's `start` again.
final theCase = BehaviorCase(
  id: '5.5',
  slug: 'location_banner',
  description: 'the banner Retry re-runs the location start-up',
  run: (tester, world) async {
    world
      ..signIn()
      ..feedNow(const [])
      ..locationError(locationPermissionDeniedCopy);
    await pumpWorld(tester, world);
    expect(find.text(locationPermissionDeniedCopy), findsOneWidget);

    // The home screen already called start() once on mount.
    final int startCallsBefore = world.location.startCalls;
    await tester.tap(find.text('Retry'));
    await settle(tester);

    expect(world.location.startCalls, startCallsBefore + 1);
  },
);
