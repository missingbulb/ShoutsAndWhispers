import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'adapters/fcm_push_adapter.dart';
import 'adapters/firebase_auth_adapter.dart';
import 'adapters/firebase_messages_adapter.dart';
import 'adapters/geolocator_location_adapter.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'ports/ports.dart';
import 'screens/setup_required_screen.dart';

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

  // The only place adapters are constructed (docs/UI-ARCHITECTURE.md): the
  // shared shell gets the production ports here; tests hand it fakes.
  runApp(
    ShoutsAndWhispersShell(
      auth: FirebaseAuthAdapter(),
      location: GeolocatorLocationAdapter(),
      push: FcmPushAdapter(),
      messages: FirebaseMessagesAdapter(),
      clock: const SystemClock(),
    ),
  );
}
