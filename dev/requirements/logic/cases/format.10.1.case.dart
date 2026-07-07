import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// Messages younger than a minute are "just now" — both at zero age and one
/// second shy of the boundary.
final theCase = LogicCase(
  id: '10.1',
  slug: 'format',
  description: 'a message younger than a minute is dated "just now"',
  verify: () {
    final now = DateTime(2026, 6, 1, 12, 0);
    expect(relativeTime(now, now), 'just now');
    expect(
      relativeTime(now.subtract(const Duration(seconds: 59)), now),
      'just now',
    );
  },
);
