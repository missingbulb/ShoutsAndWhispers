import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/screens/home_screen.dart';
import 'package:shouts_and_whispers/screens/sign_in_screen.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The gate's signed-in branch: an emitted user lands on the home screen,
/// with the sign-in screen gone.
final theCase = BehaviorCase(
  id: '3.2',
  slug: 'auth_gate',
  description: 'a signed-in user is shown the home screen',
  run: (tester, world) async {
    world.signIn();
    await pumpWorld(tester, world);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  },
);
