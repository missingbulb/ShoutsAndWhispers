/// PLACEHOLDER Firebase configuration.
///
/// This file is committed on purpose so the project compiles out of the box,
/// but it contains no real Firebase project credentials. To connect the app
/// to your own Firebase project, run:
///
/// ```sh
/// dart pub global activate flutterfire_cli
/// flutterfire configure
/// ```
///
/// from the `app/` directory. The FlutterFire CLI will overwrite this file
/// with a generated `DefaultFirebaseOptions` containing your project's real
/// per-platform options (and drop the matching `google-services.json` /
/// `GoogleService-Info.plist` into the platform folders).
///
/// Until then, [DefaultFirebaseOptions.currentPlatform] throws an
/// [UnsupportedError]; `main.dart` catches it and shows a friendly
/// setup-instructions screen instead of crashing.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Placeholder for the FlutterFire-generated default options.
class DefaultFirebaseOptions {
  /// Throws until `flutterfire configure` replaces this file.
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase has not been configured for this build yet.\n\n'
      'lib/firebase_options.dart is a committed placeholder. To connect the '
      'app to a Firebase project, run:\n\n'
      '  dart pub global activate flutterfire_cli\n'
      '  flutterfire configure\n\n'
      'from the app/ directory, which regenerates this file with your '
      'project\'s real options.',
    );
  }
}
