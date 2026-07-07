import 'package:shouts_and_whispers/screens/setup_required_screen.dart';

import '../../shared/cases.dart';

/// The fresh-checkout state: Firebase not configured, so `main.dart` shows
/// [SetupRequiredApp] instead of the shell — "Setup required" headline, the
/// build icon, and the selectable multi-line flutterfire-configure
/// instructions (the message the committed `firebase_options.dart`
/// placeholder throws).
final theCase = ScreenCase(
  id: '2.1',
  slug: 'setup',
  description: 'setup-required screen shows the "Setup required" headline '
      'with the build icon and the selectable setup instructions text',
  arrange: (world) {}, // surface outside the shell — no world state needed
  builder: (_) => const SetupRequiredApp(
    message: 'Firebase has not been configured for this build yet.\n\n'
        'lib/firebase_options.dart is a committed placeholder. To connect '
        'the app to a Firebase project, run:\n\n'
        '  dart pub global activate flutterfire_cli\n'
        '  flutterfire configure\n\n'
        'from the app/ directory, which regenerates this file with your '
        'project\'s real options.',
  ),
);
