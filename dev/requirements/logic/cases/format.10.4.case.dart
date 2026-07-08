import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ui/format.dart';

import '../../shared/cases.dart';

/// A day or older the label switches to the absolute calendar date and time
/// ("MMM d, h:mm a") — both days later and at the exact 24-hour boundary.
///
/// The shipped code uses an explicit 'MMM d, h:mm a' pattern rather than
/// `MMMd().add_jm()`, because intl joins added patterns with a bare space
/// ('May 28 3:40 PM') while the spec wants the conventional comma.
final theCase = LogicCase(
  id: '10.4',
  slug: 'format',
  description: 'a day or older, the meta shows the calendar date and time '
      '(e.g. "May 28, 3:40 PM")',
  verify: () {
    final now = DateTime(2026, 6, 1, 12, 0);
    expect(
      relativeTime(DateTime(2026, 5, 28, 15, 40), now),
      'May 28, 3:40 PM',
    );
    // Exactly 24 hours old: already the absolute form.
    expect(
      relativeTime(DateTime(2026, 5, 31, 12, 0), now),
      'May 31, 12:00 PM',
    );
  },
);
