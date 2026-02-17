import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherName;
  final String projectCategory;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherName,
    required this.projectCategory,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _listenToMessages();
    _markAsRead();
  }

  void _listenToMessages() {
    _db().child('conversations/${widget.conversationId}/messages').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final msgs = data.entries.map((e) {
          final msg = Map<String, dynamic>.from(e.value as Map);
          msg['id'] = e.key;
          return msg;
        }).toList();
        msgs.sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
        setState(() => _messages = msgs);
        _scrollToBottom();
      } else {
        setState(() => _messages = []);
      }
    });
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
            Text(widget.projectCategory, style: const TextStyle(fontSize: 12, color: Color(0xFFF97316))),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No messages yet', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMine = msg['senderId'] == currentUid;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFFF97316) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMine ? 16 : 4),
                              bottomRight: Radius.circular(isMine ? 4 : 16),
                            ),
                            border: isMine ? null : Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg['content'] ?? '', style: TextStyle(fontSize: 14, color: isMine ? Colors.white : Colors.black87)),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg['timestamp'] ?? ''),
                                style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 18, color: Colors.white),
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

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
