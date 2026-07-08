/// The fake world (docs/UI-ARCHITECTURE.md §"The fake world"): one object
/// bundling every fake port plus the pinned clock, with saga-level verbs and
/// [FakeWorld.buildApp] returning the *real* [ShoutsAndWhispersShell] wired
/// to the fakes.
library;

import 'package:flutter/widgets.dart';

import '../app.dart';
import '../models/feed_message.dart';
import '../ports/ports.dart';
import 'fake_tiles.dart';
import 'fakes.dart';
import 'sample_data.dart' as sample;

class FakeWorld {
  FakeWorld() {
    auth.signInAs = sample.sampleUser;
  }

  final FakeAuthPort auth = FakeAuthPort();
  final FakeLocationPort location = FakeLocationPort();
  final FakeMessagesPort messages = FakeMessagesPort();
  final FakePushPort push = FakePushPort();

  /// Pinned to [referenceNow] — advance or set it per case.
  final FixedClock clock = FixedClock(sample.referenceNow);

  /// The instant the clock is pinned to (2026-06-01 12:00 local). Sample
  /// timestamps are offsets before it.
  DateTime get referenceNow => sample.referenceNow;

  /// Signs in as [user] (default: the sample user) by emitting an auth state.
  void signIn([AppUser? user]) => auth.emitAuthState(user ?? sample.sampleUser);

  /// Signs out by emitting a null auth state.
  void signOut() => auth.emitAuthState(null);

  /// Emits a GPS fix.
  void fix(double lat, double lng) =>
      location.emitPosition(GeoPosition(lat, lng));

  /// Sets (or clears, with null) the human-readable location problem.
  void locationError(String? message) => location.emitError(message);

  /// Delivers one message: appended to the current feed newest-first and
  /// re-emitted.
  void receive(FeedMessage message) =>
      messages.emitFeed(<FeedMessage>[message, ...messages.latestFeed]);

  /// Replaces the whole feed (newest first).
  void feedNow(List<FeedMessage> feed) => messages.emitFeed(feed);

  /// Breaks the feed stream (the "Feed unavailable" state).
  void feedError(Object error) => messages.emitFeedError(error);

  /// The real app shell, wired to the fakes and the deterministic tile
  /// provider — the exact widget tree `main.dart` ships.
  Widget buildApp() {
    return ShoutsAndWhispersShell(
      auth: auth,
      location: location,
      push: push,
      messages: messages,
      clock: clock,
      tileProviderBuilder: FakeTileProvider.new,
    );
  }
}
