import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// One tap, one flow: the Google button calls the auth port's
/// `signInWithGoogle` exactly once.
final theCase = BehaviorCase(
  id: '1.7',
  slug: 'sign_in',
  description: 'tapping the button starts Google sign-in exactly once',
  run: (tester, world) async {
    await pumpWorld(tester, world);

    await tester.tap(find.text('Sign in with Google'));
    await settle(tester);

    expect(world.auth.signInWithGoogleCalls, 1);
  },
);
