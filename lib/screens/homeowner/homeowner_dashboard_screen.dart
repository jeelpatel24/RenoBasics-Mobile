import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:renobasic/providers/auth_provider.dart';

class HomeownerDashboardScreen extends StatefulWidget {
  const HomeownerDashboardScreen({super.key});

  @override
  State<HomeownerDashboardScreen> createState() => _HomeownerDashboardScreenState();
}

class _HomeownerDashboardScreenState extends State<HomeownerDashboardScreen> {
  int _projects = 0;
  int _messages = 0;
  int _views = 0;
  int _bids = 0;

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;
    try {
      final results = await Future.wait([
        _db().child('projects').get(),
        _db().child('conversations').get(),
        _db().child('unlocks').get(),
        _db().child('bids').get(),
      ]);

      int projects = 0;
      if (results[0].exists && results[0].value != null) {
        final data = Map<String, dynamic>.from(results[0].value as Map);
        for (final v in data.values) {
          final p = Map<String, dynamic>.from(v as Map);
          if (p['homeownerUid'] == uid) projects++;
        }
      }

      int conversations = 0;
      if (results[1].exists && results[1].value != null) {
        final data = Map<String, dynamic>.from(results[1].value as Map);
        for (final v in data.values) {
          final c = Map<String, dynamic>.from(v as Map);
          if (c['homeownerUid'] == uid) conversations++;
        }
      }

      int views = 0;
      if (results[2].exists && results[2].value != null) {
        final data = Map<String, dynamic>.from(results[2].value as Map);
        for (final v in data.values) {
          final u = Map<String, dynamic>.from(v as Map);
          if (u['homeownerUid'] == uid) views++;
        }
      }

      int bids = 0;
      if (results[3].exists && results[3].value != null) {
        final data = Map<String, dynamic>.from(results[3].value as Map);
        for (final v in data.values) {
          final b = Map<String, dynamic>.from(v as Map);
          if (b['homeownerUid'] == uid) bids++;
        }
      }

      if (mounted) setState(() { _projects = projects; _messages = conversations; _views = views; _bids = bids; });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;

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
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back, ${user?.fullName.split(' ').first ?? 'Homeowner'}!', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Manage your renovation projects', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            const SizedBox(height: 24),

            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
              children: [
                _statCard('Active Projects', '$_projects', Icons.assignment, const Color(0xFFF97316)),
                _statCard('Messages', '$_messages', Icons.chat_bubble, Colors.blue),
                _statCard('Project Views', '$_views', Icons.visibility, Colors.green),
                _statCard('Bids Received', '$_bids', Icons.description, Colors.purple),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _actionTile(context, 'Post a New Project', 'Create a renovation project', Icons.add_circle, const Color(0xFFF97316), onTap: () => Navigator.pushNamed(context, '/post-project')),
            const SizedBox(height: 8),
            _actionTile(context, 'View Messages', 'Check contractor conversations', Icons.chat, Colors.blue, onTap: () => Navigator.pushNamed(context, '/homeowner-messages')),
            const SizedBox(height: 8),
            _actionTile(context, 'View Bids', 'Review bids from contractors', Icons.description, Colors.purple, onTap: () => Navigator.pushNamed(context, '/homeowner-bids')),
            const SizedBox(height: 24),

            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_projects == 0 && _bids == 0 && _messages == 0)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  Icon(Icons.assignment, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No activity yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Post your first project to get started!', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]),
              )
            else
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  if (_projects > 0) _activityRow(Icons.assignment, 'You have $_projects project${_projects != 1 ? 's' : ''} posted', const Color(0xFFF97316)),
                  if (_bids > 0) _activityRow(Icons.description, 'You have $_bids bid${_bids != 1 ? 's' : ''} to review', Colors.purple),
                  if (_messages > 0) _activityRow(Icons.chat, 'You have $_messages active conversation${_messages != 1 ? 's' : ''}', Colors.blue),
                ]),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, selectedItemColor: const Color(0xFFF97316), unselectedItemColor: Colors.grey, currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0: break;
            case 1: Navigator.pushNamed(context, '/post-project'); break;
            case 2: Navigator.pushNamed(context, '/homeowner-messages'); break;
            case 3: Navigator.pushNamed(context, '/settings'); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Projects'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
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
