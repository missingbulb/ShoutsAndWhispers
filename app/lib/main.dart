import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/message_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // lib/firebase_options.dart is a committed placeholder that throws until
  // `flutterfire configure` replaces it — show setup instructions instead of
  // crashing on a fresh checkout.
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError catch (e) {
    runApp(SetupRequiredApp(message: e.message ?? 'Firebase not configured.'));
    return;
  }

  try {
    await Firebase.initializeApp(options: options);
  } catch (e) {
    runApp(
      SetupRequiredApp(
        message: 'Firebase failed to initialize: $e\n\n'
            'Check the options in lib/firebase_options.dart (regenerate them '
            'with `flutterfire configure`) and the platform config files '
            '(google-services.json / GoogleService-Info.plist).',
      ),
    );
    return;
  }

  runApp(const ShoutsAndWhispersApp());
}

/// Full-screen setup instructions shown when Firebase isn't configured yet.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shouts & Whispers — setup required',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.build_circle_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Setup required',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(message, textAlign: TextAlign.left),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Root app: builds the services once and gates on auth state.
class ShoutsAndWhispersApp extends StatefulWidget {
  const ShoutsAndWhispersApp({super.key});

  @override
  State<ShoutsAndWhispersApp> createState() => _ShoutsAndWhispersAppState();
}

class _ShoutsAndWhispersAppState extends State<ShoutsAndWhispersApp> {
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final PushService _pushService = PushService();
  final MessageService _messageService = MessageService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shouts & Whispers',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final User? user = snapshot.data;
          if (user == null) {
            return SignInScreen(authService: _authService);
          }
          // Keyed by uid so a different account gets a fresh screen state
          // (feed stream, map position, composer).
          return HomeScreen(
            key: ValueKey(user.uid),
            authService: _authService,
            locationService: _locationService,
            pushService: _pushService,
            messageService: _messageService,
          );
        },
      ),
    );
  }
}
