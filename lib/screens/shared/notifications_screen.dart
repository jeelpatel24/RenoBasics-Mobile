import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/notification_service.dart';
import 'package:renobasic/utils/app_toast.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, IconData> _typeIcons = {
    'bid_received': Icons.description,
    'new_bid': Icons.description, // legacy alias
    'bid_accepted': Icons.check_circle,
    'bid_rejected': Icons.cancel,
    'project_unlocked': Icons.lock_open,
    'message': Icons.chat_bubble,
    'new_message': Icons.chat_bubble,
    'new_review': Icons.star_rounded,
    'verification_approved': Icons.verified,
    'verification_rejected': Icons.gpp_bad,
  };

  static const Map<String, Color> _typeColors = {
    'bid_received': Colors.blue,
    'new_bid': Colors.blue, // legacy alias
    'bid_accepted': Colors.green,
    'bid_rejected': Colors.red,
    'project_unlocked': Color(0xFFF97316),
    'message': Colors.purple,
    'new_message': Colors.purple,
    'new_review': Colors.amber,
    'verification_approved': Colors.green,
    'verification_rejected': Colors.red,
  };

  String _getRoute(String type, bool isContractor) {
    switch (type) {
      case 'bid_accepted':
      case 'bid_rejected':
        return isContractor ? '/contractor-bids' : '/homeowner-bids';
      case 'bid_received':
      case 'new_bid':
        return '/homeowner-bids';
      case 'new_message':
      case 'message':
        return isContractor
            ? '/contractor-messages'
            : '/homeowner-messages';
      case 'project_unlocked':
        return '/marketplace';
      case 'new_review':
        return '/contractor-analytics';
      default:
        return '';
    }
  }

  Future<void> _markAllRead(String uid) async {
    final batch = _firestore.batch();
    final unread = await _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _clearAll(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await NotificationService.deleteAllNotifications(uid);
      if (mounted) AppToast.show(context, 'All notifications cleared');
    } catch (_) {
      if (mounted) AppToast.show(context, 'Failed to clear notifications', isError: true);
    }
  }

  Future<void> _markRead(String docId) async {
    await _firestore.collection('notifications').doc(docId).update({'read': true});
  }

  String _timeAgo(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().userProfile;
    final uid = user?.uid;
    final isContractor = user?.isContractor ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          if (uid != null) ...[
            TextButton(
              onPressed: () => _markAllRead(uid),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: 'Clear all',
              onPressed: () => _clearAll(uid),
            ),
          ],
        ],
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('recipientUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF97316)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load notifications',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "You're all caught up!",
                          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final isRead = data['read'] as bool? ?? false;
                    final type = data['type'] as String? ?? '';
                    final title = data['title'] as String? ?? '';
                    final message = data['message'] as String? ?? '';
                    final createdAt = data['createdAt'] as String?;
                    final icon = _typeIcons[type] ?? Icons.notifications;
                    final color = _typeColors[type] ?? const Color(0xFFF97316);

                    final route = _getRoute(type, isContractor);

                    return Dismissible(
                      key: Key(docId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 28),
                      ),
                      onDismissed: (_) async {
                        try {
                          await NotificationService.deleteNotification(docId);
                          if (mounted) AppToast.show(context, 'Notification deleted');
                        } catch (_) {
                          if (mounted) AppToast.show(context, 'Failed to delete', isError: true);
                        }
                      },
                      child: GestureDetector(
                      onTap: () {
                        if (!isRead) _markRead(docId);
                        if (route.isNotEmpty) {
                          Navigator.pushNamed(context, route);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRead ? Colors.grey.shade200 : const Color(0xFFFED7AA),
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: color.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF97316),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _timeAgo(createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),  // closes GestureDetector (child of Dismissible)
                    );  // closes Dismissible
                  },
                );
              },
            ),
    );
  }
}
