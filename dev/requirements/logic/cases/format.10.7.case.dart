import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// Your own messages read 'you' in place of any distance — whatever the
/// recorded distance is: zero, metres, or kilometres.
final theCase = LogicCase(
  id: '10.7',
  slug: 'format',
  description: 'own messages read "you" in place of any distance',
  verify: () {
    expect(distanceLabel(sampleMessage(isOwn: true, distanceM: 0)), 'you');
    expect(distanceLabel(sampleMessage(isOwn: true, distanceM: 320)), 'you');
    expect(
      distanceLabel(sampleMessage(isOwn: true, distanceM: 2500)),
      'you',
    );
  },
);
