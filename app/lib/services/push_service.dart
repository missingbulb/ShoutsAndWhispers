import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM registration (docs/DESIGN.md §6).
///
/// Requests notification permission, writes the device token into
/// `presence/{uid}` (merge — never clobbers the heartbeat fields), and keeps
/// it fresh on token rotation. Everything is best-effort: on a build without
/// APNS / google-services configuration this logs and moves on instead of
/// crashing — push is a nicety, the live feed stream is the source of truth
/// while the app is open.
class PushService {
  PushService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<String>? _tokenRefreshSub;

  /// Requests permission, uploads the current token, and subscribes to token
  /// rotation. Safe to call more than once.
  Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      _tokenRefreshSub ??= messaging.onTokenRefresh.listen(
        _saveToken,
        onError: (Object e) => debugPrint('FCM token refresh error: $e'),
      );
    } catch (e) {
      // Missing APNS entitlements / google-services config, or messaging not
      // supported on this platform. Push simply stays off.
      debugPrint('Push notifications unavailable: $e');
    }
  }

  /// Stops listening for token rotation.
  void stop() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('presence').doc(uid).set(
        <String, Object?>{'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }
}
