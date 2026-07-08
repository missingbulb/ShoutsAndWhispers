import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/ports/ports.dart';

import '../../shared/cases.dart';

/// Signed out, the scripted auth port set to fail the next sign-in: after
/// the tap, the failure message appears beneath the button in the theme's
/// error color.
final theCase = ScreenCase(
  id: '1.5',
  slug: 'sign_in',
  description: 'a failed sign-in shows the failure message beneath, in the '
      'theme\'s error color',
  arrange: (world) => world.auth.signInError =
      const SignInException('Google sign-in failed: network_error'),
  act: (tester, world) async {
    await tester.tap(find.text('Sign in with Google'));
  },
);
