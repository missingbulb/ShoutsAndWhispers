import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ports/ports.dart';
import 'package:shouts_and_whispers/screens/home_screen.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Screen state is keyed by the user id: a different signed-in account gets
/// a freshly mounted home screen, not the previous user's widget state.
final theCase = BehaviorCase(
  id: '3.4',
  slug: 'auth_gate',
  description: 'a different account gets a freshly keyed home screen',
  run: (tester, world) async {
    world.signIn(); // user A: the sample user, uid 'me'
    await pumpWorld(tester, world);
    final Key? firstKey = tester.widget(find.byType(HomeScreen)).key;
    expect(firstKey, const ValueKey('me'));

    world.signIn(const AppUser(uid: 'other', displayName: 'Other'));
    await settle(tester);

    final Key? secondKey = tester.widget(find.byType(HomeScreen)).key;
    expect(secondKey, const ValueKey('other'));
    expect(secondKey, isNot(equals(firstKey)));
  },
);
