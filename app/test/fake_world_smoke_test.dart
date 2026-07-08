// Guards lib/testing/: the fake world must be able to drive the real shipped
// shell end-to-end — sign in, get a fix, receive a message — with no
// platform and no network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shouts_and_whispers/testing/sample_data.dart';
import 'package:shouts_and_whispers/testing/world.dart';

void main() {
  testWidgets('fake world drives the real shell end-to-end', (tester) async {
    final world = FakeWorld();
    await tester.pumpWidget(world.buildApp());

    // Auth replay (null) resolves the gate to the sign-in screen.
    await tester.pump();
    expect(find.text('Sign in with Google'), findsOneWidget);

    // Sign in -> home screen (app bar + waiting feed).
    world.signIn();
    await tester.pump();
    await tester.pump();
    expect(find.text('Shouts & Whispers'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(world.location.startCalls, 1);
    expect(world.push.initCalls, 1);

    // A GPS fix and one received message render a feed entry with the
    // deterministic relative time (12 min before the pinned clock).
    world.fix(32.0731, 34.7799);
    world.receive(sampleMessage());
    await tester.pump();
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Anyone up for coffee on Rothschild?'), findsOneWidget);
    expect(find.textContaining('12 min ago'), findsOneWidget);
    expect(find.textContaining('80 m away'), findsOneWidget);
  });
}
