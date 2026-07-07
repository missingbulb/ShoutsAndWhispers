import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The input caps at 500 characters: typing 501 leaves exactly 500 in the
/// field's controller.
final theCase = BehaviorCase(
  id: '7.9',
  slug: 'composer',
  description: 'the input accepts at most 500 characters',
  run: (tester, world) async {
    world
      ..signIn()
      ..feedNow(const []);
    await pumpWorld(tester, world);

    await tester.enterText(find.byType(TextField), 'a' * 501);
    await tester.pump();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 500);
  },
);
