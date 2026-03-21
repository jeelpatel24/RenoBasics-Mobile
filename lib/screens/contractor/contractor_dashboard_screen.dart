import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/screens/shared/notifications_screen.dart';

class ContractorDashboardScreen extends StatefulWidget {
  const ContractorDashboardScreen({super.key});

  @override
  State<ContractorDashboardScreen> createState() => _ContractorDashboardScreenState();
}

class _ContractorDashboardScreenState extends State<ContractorDashboardScreen> {
  int _unlocked = 0;
  int _bids = 0;
  int _messages = 0;
  int _acceptedBids = 0;
  int _unreadNotifications = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Defer until after first frame so AuthProvider is fully ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;

    if (!mounted) return;

    try {
      final results = await Future.wait([
        _firestore.collection('unlocks').where('contractorUid', isEqualTo: uid).count().get(),
        _firestore.collection('bids').where('contractorUid', isEqualTo: uid).count().get(),
        _firestore.collection('conversations').where('contractorUid', isEqualTo: uid).count().get(),
        _firestore.collection('bids').where('contractorUid', isEqualTo: uid).where('status', isEqualTo: 'accepted').count().get(),
      ]);

      final unreadSnap = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _unlocked = results[0].count ?? 0;
          _bids = results[1].count ?? 0;
          _messages = results[2].count ?? 0;
          _acceptedBids = results[3].count ?? 0;
          _unreadNotifications = unreadSnap.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;
    final isVerified = user?.verificationStatus == 'approved';
    final creditBalance = user?.creditBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(children: [
            TextSpan(text: 'Reno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
            TextSpan(text: 'Basics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFF97316))),
          ]),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black54),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ).then((_) => _loadStats()),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('Welcome, ${user?.fullName.split(' ').first ?? 'Contractor'}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Find renovation projects and grow your business', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            const SizedBox(height: 16),

            if (!isVerified)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Your account is pending verification. You can browse but cannot unlock projects.', style: TextStyle(fontSize: 13, color: Colors.amber[800]))),
                ]),
              ),

            if (isVerified && creditBalance <= 3)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/buy-credits'),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                  child: Row(children: [
                    Icon(Icons.credit_card_off, color: Colors.red[700], size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Low credit balance ($creditBalance credits remaining). Tap to buy more credits.', style: TextStyle(fontSize: 13, color: Colors.red[800]))),
                    Icon(Icons.chevron_right, color: Colors.red[400], size: 18),
                  ]),
                ),
              ),

            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
              children: [
                _statCard('Credits', '$creditBalance', Icons.token, const Color(0xFFF97316)),
                _statCard('My Bids', '$_bids', Icons.description, Colors.blue),
                _statCard('Messages', '$_messages', Icons.chat_bubble, Colors.green),
                _statCard('Unlocked', '$_unlocked', Icons.lock_open, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _actionTile(context, 'Browse Marketplace', 'Find renovation projects', Icons.store, const Color(0xFFF97316), onTap: () => Navigator.pushNamed(context, '/marketplace')),
            const SizedBox(height: 8),
            _actionTile(context, 'Buy Credits', 'Purchase credits to unlock projects', Icons.credit_card, Colors.green, onTap: () => Navigator.pushNamed(context, '/buy-credits')),
            const SizedBox(height: 8),
            _actionTile(context, 'My Bids', 'Track your submitted bids', Icons.description, Colors.blue, onTap: () => Navigator.pushNamed(context, '/contractor-bids')),
            const SizedBox(height: 8),
            _actionTile(context, 'Messages', 'Chat with homeowners', Icons.chat, Colors.purple, onTap: () => Navigator.pushNamed(context, '/contractor-messages')),
            const SizedBox(height: 8),
            _actionTile(context, 'Analytics', 'View bid stats and reviews', Icons.bar_chart, Colors.indigo, onTap: () => Navigator.pushNamed(context, '/contractor-analytics')),
            const SizedBox(height: 24),

            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_unlocked == 0 && _bids == 0 && _messages == 0)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No activity yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Browse the marketplace to find projects!', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]),
              )
            else
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  if (_unlocked > 0) _activityRow(Icons.lock_open, 'You have unlocked $_unlocked project${_unlocked != 1 ? 's' : ''}', Colors.purple),
                  if (_bids > 0) _activityRow(Icons.description, 'You have submitted $_bids bid${_bids != 1 ? 's' : ''}${_acceptedBids > 0 ? ' ($_acceptedBids accepted)' : ''}', Colors.blue),
                  if (_messages > 0) _activityRow(Icons.chat, 'You have $_messages active conversation${_messages != 1 ? 's' : ''}', Colors.green),
                ]),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, selectedItemColor: const Color(0xFFF97316), unselectedItemColor: Colors.grey, currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0: break;
            case 1: Navigator.pushNamed(context, '/marketplace'); break;
            case 2: Navigator.pushNamed(context, '/contractor-messages'); break;
            case 3: Navigator.pushNamed(context, '/buy-credits'); break;
            case 4: Navigator.pushNamed(context, '/settings'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Marketplace'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Credits'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 18)),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]),
    );
  }

  Widget _actionTile(BuildContext context, String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _activityRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
