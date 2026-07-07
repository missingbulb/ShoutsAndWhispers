import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../models/feed_message.dart';

/// Result of a successful `sendMessage` call.
class SendResult {
  const SendResult({required this.messageId, required this.recipientCount});

  final String messageId;

  /// Number of people the message was delivered to, excluding the sender.
  final int recipientCount;
}

/// Sending (callable Cloud Function) and the live feed stream
/// (docs/DESIGN.md §4, §6).
class MessageService {
  MessageService({
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
  /// Throws [FirebaseFunctionsException] on validation/rate-limit/auth
  /// failures.
  Future<SendResult> sendMessage({
    required String text,
    required MessageKind kind,
    required double lat,
    required double lng,
  }) async {
    final callable = _functions.httpsCallable('sendMessage');
    final result = await callable.call<dynamic>(<String, dynamic>{
      'text': text,
      'kind': kind.wire,
      'lat': lat,
      'lng': lng,
    });

    final Object? raw = result.data;
    final Map<String, dynamic> data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return SendResult(
      messageId: data['messageId'] is String ? data['messageId'] as String : '',
      recipientCount: data['recipientCount'] is num
          ? (data['recipientCount'] as num).toInt()
          : 0,
    );
  }

  /// Live stream of the signed-in user's feed, newest first, capped at 200.
  Stream<List<FeedMessage>> feedStream() {
    return _feedCollection()
        .orderBy('sentAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FeedMessage.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Deletes the user's own copy of a message from their feed.
  Future<void> deleteFeedEntry(String messageId) {
    return _feedCollection().doc(messageId).delete();
  }

  CollectionReference<Map<String, dynamic>> _feedCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('MessageService used while signed out');
    }
    return _firestore.collection('users').doc(uid).collection('feed');
  }
}
