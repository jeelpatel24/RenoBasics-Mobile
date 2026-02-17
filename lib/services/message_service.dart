import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class MessageService {
  static DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

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
    final convRef = _db().child('conversations/$convId');

    final snap = await convRef.get();
    if (!snap.exists) {
      final now = DateTime.now().toIso8601String();
      await convRef.set({
        'id': convId,
        'contractorUid': contractorUid,
        'homeownerUid': homeownerUid,
        'projectId': projectId,
        'contractorName': contractorName,
        'homeownerName': homeownerName,
        'projectCategory': projectCategory,
        'lastMessage': '',
        'lastMessageAt': now,
        'createdAt': now,
      });
    }
    return convId;
  }

  /// Send a message in a conversation.
  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final now = DateTime.now().toIso8601String();
    final msgRef =
        _db().child('conversations/$conversationId/messages').push();

    final updates = <String, dynamic>{
      'conversations/$conversationId/messages/${msgRef.key}': {
        'id': msgRef.key,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': now,
        'read': false,
      },
      'conversations/$conversationId/lastMessage': content,
      'conversations/$conversationId/lastMessageAt': now,
    };

    await _db().update(updates);
  }

  /// Mark all messages in a conversation as read for the current user.
  static Future<void> markMessagesAsRead(
      String conversationId, String currentUserId) async {
    final messagesSnap =
        await _db().child('conversations/$conversationId/messages').get();
    if (!messagesSnap.exists || messagesSnap.value == null) return;

    final messages = Map<String, dynamic>.from(messagesSnap.value as Map);
    final updates = <String, dynamic>{};

    for (final entry in messages.entries) {
      final msg = Map<String, dynamic>.from(entry.value as Map);
      if (msg['senderId'] != currentUserId && msg['read'] != true) {
        updates['conversations/$conversationId/messages/${entry.key}/read'] =
            true;
      }
    }

    if (updates.isNotEmpty) {
      await _db().update(updates);
    }
  }
}
