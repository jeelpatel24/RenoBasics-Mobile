import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/message_service.dart';
import 'package:renobasic/services/notification_service.dart';
import 'package:renobasic/utils/app_toast.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherName;
  final String projectCategory;
  final String recipientUid;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    required this.projectCategory,
    required this.recipientUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _deleting = false;

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
            'Delete your conversation with ${widget.otherName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await MessageService.deleteConversation(widget.conversationId);
      if (mounted) {
        AppToast.show(context, 'Conversation deleted');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        AppToast.show(context, 'Failed to delete conversation', isError: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markAsRead() {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid != null) {
      MessageService.markMessagesAsRead(widget.conversationId, uid);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;

    _messageController.clear();
    setState(() => _sending = true);
    try {
      await MessageService.sendMessage(
        conversationId: widget.conversationId,
        senderId: user.uid,
        senderName: user.fullName,
        content: text,
      );
      _scrollToBottom();
      // Notify the recipient
      if (widget.recipientUid.isNotEmpty) {
        NotificationService.createNotification(
          recipientUid: widget.recipientUid,
          type: 'new_message',
          title: 'New message from ${user.fullName}',
          message: text.length > 80 ? '${text.substring(0, 80)}…' : text,
          relatedId: widget.conversationId,
        );
      }
    } catch (e) {
      debugPrint('Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthProvider>().userProfile?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherName, style: const TextStyle(fontSize: 16)),
            Text(widget.projectCategory,
                style: const TextStyle(fontSize: 12, color: Color(0xFFF97316))),
          ],
        ),
        actions: [
          if (_deleting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.red, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Conversation',
              onPressed: _deleteConversation,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: MessageService.subscribeToMessages(widget.conversationId),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFF97316)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No messages yet',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i].data() as Map<String, dynamic>;
                    final isMine = msg['senderId'] == currentUid;
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMine
                              ? const Color(0xFFF97316)
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(isMine ? 16 : 4),
                            bottomRight:
                                Radius.circular(isMine ? 4 : 16),
                          ),
                          border: isMine
                              ? null
                              : Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg['content'] ?? '',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isMine
                                        ? Colors.white
                                        : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(msg['timestamp'] ?? ''),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isMine
                                      ? Colors.white70
                                      : Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFF97316),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send,
                            size: 18, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is String) {
        dt = DateTime.parse(timestamp);
      } else {
        return '';
      }
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
