import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../models/feed_message.dart';
import '../ports/ports.dart';

/// Returns a copy of [data] with every Firestore [Timestamp] value replaced
/// by its plain [DateTime] — `FeedMessage` is platform-free, so the
/// conversion happens here at the adapter boundary.
///
/// Top-level so it is unit-testable without Firebase initialization
/// ([Timestamp] is a plain value class).
Map<String, dynamic> convertTimestamps(Map<String, dynamic> data) {
  return data.map(
    (key, value) =>
        MapEntry(key, value is Timestamp ? value.toDate() : value),
  );
}

/// Sending (callable Cloud Function) and the live feed stream
/// (docs/DESIGN.md §4, §6).
class FirebaseMessagesAdapter implements MessagesPort {
  FirebaseMessagesAdapter({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  /// Calls the `sendMessage` callable. The audience is resolved server-side
  /// from live presence at this moment; the response says how many people
  /// (excluding the sender) received it.
  ///
  /// Throws [SendException] on validation/rate-limit/auth failures.
  @override
  Future<SendResult> send({
    required String text,
    required MessageKind kind,
    required GeoPosition at,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendMessage');
      final result = await callable.call<dynamic>(<String, dynamic>{
        'text': text,
        'kind': kind.wire,
        'lat': at.lat,
        'lng': at.lng,
      });

      final Object? raw = result.data;
      final Map<String, dynamic> data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      return SendResult(
        messageId:
            data['messageId'] is String ? data['messageId'] as String : '',
        recipientCount: data['recipientCount'] is num
            ? (data['recipientCount'] as num).toInt()
            : 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw SendException(e.message ?? e.code);
    }
  }

  /// Live stream of the signed-in user's feed, newest first, capped at 200.
  @override
  Stream<List<FeedMessage>> feed() {
    return _feedCollection()
        .orderBy('sentAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FeedMessage.fromMap(
                  doc.id,
                  convertTimestamps(doc.data()),
                ),
              )
              .toList(growable: false),
        );
  }

  /// Deletes the user's own copy of a message from their feed.
  @override
  Future<void> deleteFeedEntry(String messageId) {
    return _feedCollection().doc(messageId).delete();
  }

  CollectionReference<Map<String, dynamic>> _feedCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('FirebaseMessagesAdapter used while signed out');
    }
    return _firestore.collection('users').doc(uid).collection('feed');
  }
}
