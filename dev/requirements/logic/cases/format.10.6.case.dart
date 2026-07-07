import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// From a kilometre up the label switches to kilometres with exactly one
/// decimal — '1.0 km away' right at the boundary, '1.6 km away' at 1550 m.
final theCase = LogicCase(
  id: '10.6',
  slug: 'format',
  description: 'a kilometre and beyond reads "X.Y km away", one decimal',
  verify: () {
    expect(distanceLabel(sampleMessage(distanceM: 1000)), '1.0 km away');
    expect(distanceLabel(sampleMessage(distanceM: 1550)), '1.6 km away');
  },
);
