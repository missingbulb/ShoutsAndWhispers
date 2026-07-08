import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'ports/ports.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';

/// The real root widget — theme, auth gate, screen routing — used
/// *identically* by `main.dart` (with adapters) and by the requirements
/// harness (with fakes). Tests never rebuild a parallel app shell; actuals
/// come from the shipped one (docs/UI-ARCHITECTURE.md).
class ShoutsAndWhispersShell extends StatelessWidget {
  const ShoutsAndWhispersShell({
    super.key,
    required this.auth,
    required this.location,
    required this.push,
    required this.messages,
    required this.clock,
    this.tileProviderBuilder,
  });

  final AuthPort auth;
  final LocationPort location;
  final PushPort push;
  final MessagesPort messages;
  final Clock clock;

  /// Map tile source override; null keeps the default network tiles.
  final TileProvider Function()? tileProviderBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shouts & Whispers',
      // Release builds never show the ribbon anyway; disabling it keeps the
      // requirements goldens (dev/requirements/) clean of debug chrome.
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: StreamBuilder<AppUser?>(
        stream: auth.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final AppUser? user = snapshot.data;
          if (user == null) {
            return SignInScreen(auth: auth);
          }
          // Keyed by uid so a different account gets a fresh screen state
          // (feed stream, map position, composer).
          return HomeScreen(
            key: ValueKey(user.uid),
            auth: auth,
            location: location,
            push: push,
            messages: messages,
            clock: clock,
            tileProviderBuilder: tileProviderBuilder,
          );
        },
      ),
    );
  }
}
