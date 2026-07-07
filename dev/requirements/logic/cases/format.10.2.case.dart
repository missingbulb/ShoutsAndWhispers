import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// Between a minute and an hour the label counts whole minutes — from the
/// 60-second boundary ('1 min ago') up to one second shy of an hour
/// ('59 min ago').
final theCase = LogicCase(
  id: '10.2',
  slug: 'format',
  description: 'under an hour, age is shown as "N min ago"',
  verify: () {
    final now = DateTime(2026, 6, 1, 12, 0);
    expect(
      relativeTime(now.subtract(const Duration(seconds: 60)), now),
      '1 min ago',
    );
    expect(
      relativeTime(
        now.subtract(const Duration(minutes: 59, seconds: 59)),
        now,
      ),
      '59 min ago',
    );
  },
);
