import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The first GPS fix recenters the map from the far-out world view onto the
/// device position at neighborhood zoom (15).
final theCase = BehaviorCase(
  id: '4.3',
  slug: 'map',
  description: 'the first fix recenters the map onto the device at zoom 15',
  run: (tester, world) async {
    world
      ..signIn()
      ..feedNow(const []);
    await pumpWorld(tester, world);

    world.fix(32.0731, 34.7799);
    await settle(tester);

    // Read the camera from a context inside the FlutterMap subtree.
    final MapCamera camera =
        MapCamera.of(tester.element(find.byType(TileLayer)));
    expect(camera.center.latitude, closeTo(32.0731, 1e-6));
    expect(camera.center.longitude, closeTo(34.7799, 1e-6));
    expect(camera.zoom, 15);
  },
);
