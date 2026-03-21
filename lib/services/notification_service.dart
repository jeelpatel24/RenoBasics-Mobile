import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a notification document in the `notifications` collection.
  /// Mirrors the web app's createNotification() function exactly.
  static Future<void> createNotification({
    required String recipientUid,
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) async {
    try {
      final data = <String, dynamic>{
        'recipientUid': recipientUid,
        'type': type,
        'title': title,
        'message': message,
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      if (relatedId != null) data['relatedId'] = relatedId;
      await _firestore.collection('notifications').add(data);
    } catch (e) {
      debugPrint('NotificationService.createNotification error: $e');
    }
  }

  /// Delete a single notification by document ID.
  static Future<void> deleteNotification(String docId) async {
    await _firestore.collection('notifications').doc(docId).delete();
  }

  /// Delete all notifications for a user.
  static Future<void> deleteAllNotifications(String uid) async {
    const batchSize = 400;
    while (true) {
      final snap = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .limit(batchSize)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
