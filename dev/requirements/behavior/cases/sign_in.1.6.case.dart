import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ports/ports.dart';
import 'package:shouts_and_whispers/screens/sign_in_screen.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Backing out of sign-in is not a failure: a canceled attempt leaves the
/// sign-in screen with no error message at all.
final theCase = BehaviorCase(
  id: '1.6',
  slug: 'sign_in',
  description: 'a canceled sign-in shows no error',
  run: (tester, world) async {
    world.auth.signInError = const SignInCanceledException();
    await pumpWorld(tester, world);

    await tester.tap(find.text('Sign in with Google'));
    await settle(tester);

    // Still signed out with the button restored — and no error copy.
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.textContaining('Sign-in failed'), findsNothing);

    // Nothing is rendered in the theme's error color either.
    final Color errorColor = Theme.of(
      tester.element(find.byType(SignInScreen)),
    ).colorScheme.error;
    final Iterable<Text> errorTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.style?.color == errorColor);
    expect(errorTexts, isEmpty);
  },
);
