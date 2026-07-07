import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in -> Firebase Auth, using the google_sign_in v7 API
/// (singleton [GoogleSignIn.instance], one-time [GoogleSignIn.initialize],
/// then [GoogleSignIn.authenticate]).
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  /// Emits the signed-in [User] (or null) — drives the auth gate.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Runs the interactive Google sign-in flow and signs into Firebase with
  /// the resulting ID token.
  ///
  /// Throws [GoogleSignInException] (e.g. code `canceled` when the user backs
  /// out) or [FirebaseAuthException] on failure.
  Future<UserCredential> signInWithGoogle() async {
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
    return _auth.signInWithCredential(credential);
  }

  /// Signs out of Firebase and, best-effort, of Google.
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
