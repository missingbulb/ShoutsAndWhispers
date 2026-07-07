import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import '../geo/geohash.dart' as geohash;

/// Foreground presence heartbeat (docs/DESIGN.md §6).
///
/// Streams the device position (high accuracy, 25 m distance filter) plus a
/// 2-minute timer tick, and upserts `presence/{uid}` with lat/lng/geohash and
/// a server timestamp. Writes are throttled to at most one per 30 s unless
/// the device moved >= 25 m. `fcmToken` is preserved via a merge write, and
/// `lastSentAt` is never written (server-owned; rules reject it).
class LocationService {
  LocationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Last known device position; null until the first GPS fix. The UI uses
  /// this to place the blue dot and to enable the send button.
  final ValueNotifier<Position?> position = ValueNotifier<Position?>(null);

  /// Human-readable location problem (permission denied, services off), or
  /// null when everything is fine.
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  DateTime? _lastWriteAt;
  Position? _lastWrittenPosition;

  /// Incremented by every [stop] (and therefore by every [start], which stops
  /// first). An in-flight [start] captures the value and bails out after each
  /// await if it changed — without this, a start() that is still awaiting the
  /// permission check or the first GPS fix when stop() runs would re-arm the
  /// position stream and heartbeat timer afterwards, leaking an active GPS
  /// subscription and a periodic Timer past sign-out.
  int _epoch = 0;

  /// Requests permission if needed, then starts the position stream and the
  /// periodic heartbeat. Safe to call again (e.g. to retry after the user
  /// grants permission); any previous stream/timer is torn down first.
  Future<void> start() async {
    stop();
    final int epoch = _epoch;

    if (!await _ensurePermission()) return;
    if (epoch != _epoch) return; // stop()/start() superseded us mid-await

    // Seed with a one-shot fix so the map and the send button don't have to
    // wait for the first stream event.
    try {
      final fix = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (epoch != _epoch) return;
      await _onPosition(fix);
    } catch (e) {
      debugPrint('Initial position fix failed: $e');
    }
    if (epoch != _epoch) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: moveThresholdM.round(),
      ),
    ).listen(
      _onPosition,
      onError: (Object e) {
        debugPrint('Position stream error: $e');
        error.value = 'Location updates stopped: $e';
      },
    );

    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      final current = position.value;
      if (current != null) {
        _upsertPresence(current);
      }
    });
  }

  /// Stops the position stream and heartbeat timer, and invalidates any
  /// still-awaiting [start] call so it cannot re-arm them afterwards.
  void stop() {
    _epoch++;
    _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void dispose() {
    stop();
    position.dispose();
    error.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      error.value = 'Location services are turned off. Turn them on to send '
          'and receive nearby messages.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      error.value = 'Location permission is permanently denied. Enable it '
          'for this app in your system settings, then retry.';
      return false;
    }
    if (permission == LocationPermission.denied) {
      error.value =
          'Location permission denied — nearby messaging needs your position.';
      return false;
    }

    error.value = null;
    return true;
  }

  Future<void> _onPosition(Position newPosition) async {
    position.value = newPosition;
    await _upsertPresence(newPosition);
  }

  /// Upserts `presence/{uid}`, throttled: skip unless the device moved
  /// >= [moveThresholdM] since the last write or >= [minWriteGap] elapsed.
  Future<void> _upsertPresence(Position p) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final previous = _lastWrittenPosition;
    final lastAt = _lastWriteAt;
    if (previous != null && lastAt != null) {
      final movedM = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        p.latitude,
        p.longitude,
      );
      final bool gapElapsed = now.difference(lastAt) >= minWriteGap;
      if (movedM < moveThresholdM && !gapElapsed) return;
    }

    try {
      await _firestore.collection('presence').doc(uid).set(
        <String, Object?>{
          'lat': p.latitude,
          'lng': p.longitude,
          'geohash': geohash.encode(p.latitude, p.longitude, precision: 9),
          'updatedAt': FieldValue.serverTimestamp(),
          // NOTE: never write 'lastSentAt' here — it is server-owned and the
          // security rules reject client writes that include it. The merge
          // keeps 'fcmToken' (written by PushService) intact.
        },
        SetOptions(merge: true),
      );
      _lastWriteAt = now;
      _lastWrittenPosition = p;
    } catch (e) {
      debugPrint('Presence write failed: $e');
    }
  }
}
