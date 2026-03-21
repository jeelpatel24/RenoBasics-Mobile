import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/message_service.dart';
import 'package:renobasic/utils/app_toast.dart';

class ContractorMessagesScreen extends StatefulWidget {
  const ContractorMessagesScreen({super.key});

  @override
  State<ContractorMessagesScreen> createState() => _ContractorMessagesScreenState();
}

class _ContractorMessagesScreenState extends State<ContractorMessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().userProfile?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Messages')),
      body: uid == null
          ? const Center(child: Text('User not found'))
          : StreamBuilder<QuerySnapshot>(
              stream: MessageService.subscribeToConversations(uid, 'contractor'),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF97316)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No conversations yet',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Unlock a project to start messaging',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[400])),
                      ],
                    ),
                  );
                }

                final conversations = snapshot.data!.docs;
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (ctx, i) {
                      final conv = conversations[i];
                      final convId = conv.id;
                      final homeownerName = conv['homeownerName'] ?? 'Homeowner';
                      final homeownerUid = conv['homeownerUid'] as String? ?? '';
                      final projectCategory = conv['projectCategory'] ?? '';
                      final lastMessage = conv['lastMessage'] ?? 'No messages yet';

                      return Dismissible(
                        key: Key(convId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (_) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Conversation'),
                              content: Text(
                                  'Delete your conversation with $homeownerName? This cannot be undone.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style:
                                          TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          return confirmed == true;
                        },
                        onDismissed: (_) async {
                          try {
                            await MessageService.deleteConversation(convId);
                            if (mounted) AppToast.show(context, 'Conversation deleted');
                          } catch (_) {
                            if (mounted) AppToast.show(context, 'Failed to delete', isError: true);
                          }
                        },
                        child: StreamBuilder<int>(
                        stream: MessageService.getUnreadCount(convId, uid),
                        builder: (ctx, unreadSnapshot) {
                          final unreadCount = unreadSnapshot.data ?? 0;
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFFF97316).withAlpha(25),
                                  child: Text(
                                    homeownerName.isNotEmpty
                                        ? homeownerName.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Color(0xFFF97316),
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      constraints:
                                          const BoxConstraints(
                                              minWidth: 20, minHeight: 20),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(homeownerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(projectCategory,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFF97316))),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.pushNamed(context, '/chat',
                                  arguments: {
                                    'conversationId': convId,
                                    'otherName': homeownerName,
                                    'projectCategory': projectCategory,
                                    'recipientUid': homeownerUid,
                                  });
                            },
                          );
                        },
                      ),  // closes StreamBuilder (child of Dismissible)
                      );  // closes Dismissible
                    },
                  ),
                );
              },
            ),
    );
  }
}
