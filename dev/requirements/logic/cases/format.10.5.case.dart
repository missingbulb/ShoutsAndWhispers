import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// Distances under a kilometre read metre-rounded "N m away". The shipped
/// code picks the metres branch *before* rounding (`d < 1000`, then
/// `d.round()`), so 999.4 rounds down to '999 m away' while 999.5 rounds up
/// to '1000 m away' — still worded in metres, not switching to '1.0 km'.
final theCase = LogicCase(
  id: '10.5',
  slug: 'format',
  description: 'distances under a kilometre read "N m away", metre-rounded '
      '(999.5 rounds up to "1000 m away", still in the metres branch)',
  verify: () {
    expect(distanceLabel(sampleMessage(distanceM: 320)), '320 m away');
    expect(distanceLabel(sampleMessage(distanceM: 999.4)), '999 m away');
    // The `d < 1000` check happens before rounding, so 999.5 renders as
    // 1000 in the metres wording rather than as kilometres.
    expect(distanceLabel(sampleMessage(distanceM: 999.5)), '1000 m away');
  },
);
