import 'package:cloud_firestore/cloud_firestore.dart';

class MessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Conversation ID format: {contractorUid}_{projectId}
  static String conversationId(String contractorUid, String projectId) =>
      '${contractorUid}_$projectId';

  /// Get or create a conversation between contractor and homeowner for a project.
  /// Returns the conversation ID.
  static Future<String> getOrCreateConversation({
    required String contractorUid,
    required String projectId,
    required String homeownerUid,
    required String homeownerName,
    required String contractorName,
    required String projectCategory,
  }) async {
    final convId = conversationId(contractorUid, projectId);
    final now = DateTime.now();

    await _firestore.collection('conversations').doc(convId).set(
        {
          'id': convId,
          'contractorUid': contractorUid,
          'homeownerUid': homeownerUid,
          'projectId': projectId,
          'contractorName': contractorName,
          'homeownerName': homeownerName,
          'projectCategory': projectCategory,
          'lastMessage': '',
          'lastMessageTimestamp': now.toIso8601String(),
          'messageCount': 0,
          'createdAt': now.toIso8601String(),
        },
        SetOptions(merge: true));

    return convId;
  }

  /// Send a message in a conversation.
  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final now = DateTime.now();

    // Add message to messages subcollection
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          'senderId': senderId,
          'senderName': senderName,
          'content': content,
          'timestamp': now.toIso8601String(),
          'read': false,
        });

    // Update conversation's last message and timestamp
    final truncated = content.length > 80 ? '${content.substring(0, 80)}...' : content;
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': truncated,
      'lastMessageTimestamp': now.toIso8601String(),
      'messageCount': FieldValue.increment(1),
    });
  }

  /// Mark all messages in a conversation as read for the current user.
  static Future<void> markMessagesAsRead(
      String conversationId, String currentUserId) async {
    final messagesQuery = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    if (messagesQuery.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in messagesQuery.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Subscribe to conversations for a user.
  static Stream<QuerySnapshot> subscribeToConversations(
      String uid, String role) {
    final field = role == 'homeowner' ? 'homeownerUid' : 'contractorUid';
    return _firestore
        .collection('conversations')
        .where(field, isEqualTo: uid)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  /// Subscribe to messages in a conversation.
  static Stream<QuerySnapshot> subscribeToMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  /// Delete a conversation and all its messages.
  static Future<void> deleteConversation(String conversationId) async {
    const batchSize = 400;
    while (true) {
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .limit(batchSize)
          .get();
      if (messages.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _firestore.collection('conversations').doc(conversationId).delete();
  }

  /// Get unread message count for a conversation.
  static Stream<int> getUnreadCount(
      String conversationId, String currentUserId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
