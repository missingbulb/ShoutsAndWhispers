import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// Between an hour and a day the label counts whole hours — from exactly one
/// hour ('1 h ago') up to one minute shy of a day ('23 h ago').
final theCase = LogicCase(
  id: '10.3',
  slug: 'format',
  description: 'under a day, age is shown as "N h ago"',
  verify: () {
    final now = DateTime(2026, 6, 1, 12, 0);
    expect(
      relativeTime(now.subtract(const Duration(hours: 1)), now),
      '1 h ago',
    );
    expect(
      relativeTime(
        now.subtract(const Duration(hours: 23, minutes: 59)),
        now,
      ),
      '23 h ago',
    );
  },
);
