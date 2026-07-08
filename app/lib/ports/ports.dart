/// Ports — the abstract seams between the UI and the platform
/// (docs/UI-ARCHITECTURE.md).
///
/// Pure Dart + `flutter/foundation` only: no `firebase_*`, `cloud_*`,
/// `google_sign_in`, or `geolocator` imports. Screens and the app shell
/// depend on these interfaces; `lib/adapters/` implements them against the
/// real platform and `lib/testing/` implements them as scripted fakes.
library;

import 'package:flutter/foundation.dart';

import '../models/feed_message.dart';

/// Injectable time source, so relative-time labels are testable.
///
/// Prod: [SystemClock]. Tests: `FixedClock` (in `lib/testing/fakes.dart`).
abstract class Clock {
  DateTime now();
}

/// The real wall clock.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A latitude/longitude pair — the platform-free stand-in for a geolocator
/// `Position` at the UI boundary.
@immutable
class GeoPosition {
  const GeoPosition(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPosition && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPosition($lat, $lng)';
}

/// The signed-in user — the platform-free stand-in for a Firebase `User`.
@immutable
class AppUser {
  const AppUser({required this.uid, this.displayName, this.photoUrl});

  final String uid;
  final String? displayName;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, displayName, photoUrl);
}

/// Result of a successful [MessagesPort.send] call.
class SendResult {
  const SendResult({required this.messageId, required this.recipientCount});

  final String messageId;

  /// Number of people the message was delivered to, excluding the sender.
  final int recipientCount;
}

/// The user backed out of the sign-in flow — not an error worth showing.
class SignInCanceledException implements Exception {
  const SignInCanceledException();
}

/// Sign-in failed; [message] is ready to show to the user as-is.
class SignInException implements Exception {
  const SignInException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sending a message failed; [message] is ready to show to the user as-is.
class SendException implements Exception {
  const SendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authentication: the auth gate and the sign-in/sign-out actions.
abstract class AuthPort {
  /// Emits the signed-in [AppUser] (or null) — drives the auth gate.
  ///
  /// Implementations must replay the latest value to every new listener, so
  /// a listener attached after sign-in still learns who is signed in.
  Stream<AppUser?> get authStateChanges;

  /// Runs the interactive Google sign-in flow.
  ///
  /// Throws [SignInCanceledException] when the user backs out, or
  /// [SignInException] on failure.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

/// Device location: the current fix, problems, and lifecycle.
///
/// Presence writing (the server-facing heartbeat) is an adapter concern and
/// deliberately invisible here — the UI only sees the fix and the error.
abstract class LocationPort {
  /// Last known device position; null until the first fix. The UI uses this
  /// to place the blue dot and to enable the send button.
  ValueListenable<GeoPosition?> get position;

  /// Human-readable location problem (permission denied, services off), or
  /// null when everything is fine.
  ValueListenable<String?> get error;

  /// Starts (or retries) location updates. Safe to call again.
  Future<void> start();

  /// Stops location updates.
  void stop();
}

/// Messaging: the live feed, sending, and feed-entry deletion.
abstract class MessagesPort {
  /// Live stream of the signed-in user's feed, newest first.
  Stream<List<FeedMessage>> feed();

  /// Sends [text] as a [kind] message from position [at].
  ///
  /// Throws [SendException] on validation/rate-limit/auth failures.
  Future<SendResult> send({
    required String text,
    required MessageKind kind,
    required GeoPosition at,
  });

  /// Deletes the user's own copy of a message from their feed.
  Future<void> deleteFeedEntry(String messageId);
}

/// Push registration. Fire-and-forget; the UI never observes push state.
abstract class PushPort {
  Future<void> init();

  void stop();
}
