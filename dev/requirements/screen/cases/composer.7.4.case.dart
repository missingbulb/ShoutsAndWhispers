import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';

import '../../shared/cases.dart';

/// Flipping the toggle to shout swaps the hint: "Shout to people within
/// 1500 m…". The feed is kept empty so the toggle's megaphone is the only
/// campaign icon on screen (feed badges and map markers reuse it).
final theCase = ScreenCase(
  id: '7.4',
  slug: 'composer',
  description: 'with shout selected the input hint reads "Shout to people '
      'within 1500 m…"',
  arrange: (world) => world
    ..signIn(sampleUser)
    ..fix(32.0731, 34.7799)
    ..feedNow(const []),
  act: (tester, world) async {
    await tester.tap(find.byIcon(Icons.campaign));
  },
);
