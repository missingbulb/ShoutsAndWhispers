import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../ports/ports.dart';

/// Google sign-in -> Firebase Auth, using the google_sign_in v7 API
/// (singleton [GoogleSignIn.instance], one-time [GoogleSignIn.initialize],
/// then [GoogleSignIn.authenticate]).
class FirebaseAuthAdapter implements AuthPort {
  FirebaseAuthAdapter({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  /// Emits the signed-in [AppUser] (or null) — drives the auth gate.
  ///
  /// Firebase already replays the current user to every new listener; the
  /// per-listener `map` preserves that.
  @override
  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().map(_toAppUser);

  static AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );

  /// Runs the interactive Google sign-in flow and signs into Firebase with
  /// the resulting ID token.
  @override
  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await googleSignIn.initialize();
        _googleInitialized = true;
      }

      final GoogleSignInAccount account = await googleSignIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Google sign-in returned no ID token. Check the platform '
              'client-id configuration (see the google_sign_in README).',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User backed out — not an error worth shouting about.
        throw const SignInCanceledException();
      }
      throw SignInException(
        'Google sign-in failed: ${e.description ?? e.code.name}',
      );
    } catch (e) {
      throw SignInException('Sign-in failed: $e');
    }
  }

  /// Signs out of Firebase and, best-effort, of Google.
  @override
  Future<void> signOut() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      // Google sign-out is best-effort; Firebase sign-out below is what
      // actually flips the auth gate.
      debugPrint('Google sign-out failed: $e');
    }
    await _auth.signOut();
  }
}
