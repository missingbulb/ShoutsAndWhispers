import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/screens/home_screen.dart';
import 'package:shouts_and_whispers/screens/sign_in_screen.dart';

import '../../shared/cases.dart';
import '../../shared/harness.dart';

/// The gate's signed-out branch: with no user emitted, the sign-in screen
/// is shown and the home screen is nowhere in the tree.
final theCase = BehaviorCase(
  id: '3.1',
  slug: 'auth_gate',
  description: 'a signed-out user is shown the sign-in screen',
  run: (tester, world) async {
    await pumpWorld(tester, world);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  },
);
