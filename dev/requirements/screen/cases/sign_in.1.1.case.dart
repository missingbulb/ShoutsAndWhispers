import '../../shared/cases.dart';

/// Fresh app, signed out: the brand block — megaphone mark and the app name
/// headline — is the first thing a user sees.
final theCase = ScreenCase(
  id: '1.1',
  slug: 'sign_in',
  description: 'signed-out screen leads with the megaphone mark and the '
      '"Shouts & Whispers" headline',
  arrange: (world) {}, // default world: signed out, no fix, no feed
);
