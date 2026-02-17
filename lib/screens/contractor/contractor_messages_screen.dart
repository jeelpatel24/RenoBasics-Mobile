import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';

class ContractorMessagesScreen extends StatefulWidget {
  const ContractorMessagesScreen({super.key});

  @override
  State<ContractorMessagesScreen> createState() => _ContractorMessagesScreenState();
}

class _ContractorMessagesScreenState extends State<ContractorMessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;

    _db().child('conversations').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final convs = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          final conv = Map<String, dynamic>.from(value as Map);
          if (conv['contractorUid'] == uid) {
            conv['id'] = key;
            convs.add(conv);
          }
        });
        convs.sort((a, b) => (b['lastMessageAt'] ?? '').compareTo(a['lastMessageAt'] ?? ''));
        setState(() {
          _conversations = convs;
          _loading = false;
        });
      } else {
        setState(() {
          _conversations = [];
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No conversations yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Unlock a project to start messaging', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (ctx, i) {
                    final conv = _conversations[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF97316).withAlpha(25),
                        child: Text(
                          (conv['homeownerName'] ?? 'H').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(conv['homeownerName'] ?? 'Homeowner', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conv['projectCategory'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFF97316))),
                          Text(
                            conv['lastMessage'] ?? 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.pushNamed(context, '/chat', arguments: {
                          'conversationId': conv['id'],
                          'otherName': conv['homeownerName'] ?? 'Homeowner',
                          'projectCategory': conv['projectCategory'] ?? '',
                        });
                      },
                    );
                  },
                ),
    );
  }
}
