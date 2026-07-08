import '../../shared/cases.dart';

/// Fresh app, signed out: beneath the headline sits the one-line pitch,
/// spelling out the product in a sentence — whisper 150 m, shout the
/// neighborhood.
final theCase = ScreenCase(
  id: '1.2',
  slug: 'sign_in',
  description: 'signed-out screen shows the exact one-line pitch — "Message '
      'the people around you right now — a whisper reaches 150 m, a shout '
      'the whole neighborhood."',
  arrange: (world) {}, // default world: signed out, no fix, no feed
);
