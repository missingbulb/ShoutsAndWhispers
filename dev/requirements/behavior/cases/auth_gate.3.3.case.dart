import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/screens/home_screen.dart';
import 'package:shouts_and_whispers/screens/sign_in_screen.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// Signing out from the home screen: the logout action calls the auth
/// port's `signOut` once, and the gate returns to the sign-in screen.
final theCase = BehaviorCase(
  id: '3.3',
  slug: 'auth_gate',
  description: 'signing out returns to the sign-in screen',
  run: (tester, world) async {
    world
      ..signIn()
      ..feedNow(const []);
    await pumpWorld(tester, world);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await settle(tester);

    expect(world.auth.signOutCalls, 1);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  },
);
