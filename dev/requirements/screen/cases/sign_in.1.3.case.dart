import '../../shared/cases.dart';

/// Fresh app, signed out: below the brand block, the filled "Sign in with
/// Google" button with the login icon stands alone — no other action on the
/// screen.
final theCase = ScreenCase(
  id: '1.3',
  slug: 'sign_in',
  description: 'a filled "Sign in with Google" button with the login icon is '
      'the single call to action',
  arrange: (world) {}, // default world: signed out, no fix, no feed
);
