import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../shared/cases.dart';

/// Signed out, sign-in tapped while the scripted auth port holds the call
/// in flight forever: the button's place is taken by the progress spinner.
final theCase = ScreenCase(
  id: '1.4',
  slug: 'sign_in',
  description: 'while sign-in is in flight, the button is replaced by a '
      'progress spinner',
  arrange: (world) {}, // default world: signed out
  act: (tester, world) async {
    // Freeze the sign-in mid-flight: the completer is never completed, so
    // the busy spinner is what the golden captures.
    world.auth.pendingSignIn = Completer<void>();
    await tester.tap(find.text('Sign in with Google'));
  },
);
