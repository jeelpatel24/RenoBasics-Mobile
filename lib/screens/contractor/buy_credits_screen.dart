import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:renobasic/providers/auth_provider.dart';

class BuyCreditsScreen extends StatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  State<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends State<BuyCreditsScreen> {
  static const List<Map<String, dynamic>> _packages = [
    {'name': 'Starter', 'credits': 10, 'price': 49, 'perCredit': '4.90', 'badge': null},
    {'name': 'Professional', 'credits': 25, 'price': 99, 'perCredit': '3.96', 'badge': 'POPULAR'},
    {'name': 'Business', 'credits': 50, 'price': 179, 'perCredit': '3.58', 'badge': null},
    {'name': 'Enterprise', 'credits': 100, 'price': 299, 'perCredit': '2.99', 'badge': null},
  ];

  String? _buyingId;
  List<Map<String, dynamic>> _transactions = [];
  bool _txLoading = true;

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;
    try {
      final snap = await _db().child('transactions').get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final txs = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          final tx = Map<String, dynamic>.from(value as Map);
          if (tx['contractorUid'] == uid) {
            tx['id'] = key;
            txs.add(tx);
          }
        });
        txs.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        if (mounted) setState(() => _transactions = txs);
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      if (mounted) setState(() => _txLoading = false);
    }
  }

  Future<void> _buyCredits(Map<String, dynamic> pkg) async {
    final auth = context.read<AuthProvider>();
    final user = auth.userProfile;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Purchase'),
        content: Text(
          'Buy ${pkg['credits']} credits for \$${pkg['price']}?\n\n'
          '(Simulated \u2014 Stripe integration in Iteration 2)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _buyingId = pkg['name']);
    try {
      final balanceSnap = await _db().child('users/${user.uid}/creditBalance').get();
      final currentBalance = (balanceSnap.value as int?) ?? 0;
      final txRef = _db().child('transactions').push();
      final now = DateTime.now().toIso8601String();

      await _db().update({
        'users/${user.uid}/creditBalance': currentBalance + (pkg['credits'] as int),
        'transactions/${txRef.key}': {
          'id': txRef.key,
          'contractorUid': user.uid,
          'creditAmount': pkg['credits'],
          'cost': pkg['price'],
          'type': 'purchase',
          'timestamp': now,
        },
      });

      await auth.refreshProfile();
      Fluttertoast.showToast(msg: '${pkg['credits']} credits added!');
      await _loadTransactions();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to purchase credits');
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Buy Credits'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${user?.creditBalance ?? 0} Credits',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('Choose a Package', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Select a credit package that suits your needs', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 16),

            ..._packages.map((pkg) => _packageCard(pkg)),

            const SizedBox(height: 28),

            // Transaction History
            const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_txLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Color(0xFFF97316))))
            else if (_transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No transactions yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Purchase credits to see history here', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  ],
                ),
              )
            else
              ..._transactions.map((tx) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tx['type'] == 'purchase' ? Colors.green.withAlpha(25) : const Color(0xFFF97316).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            tx['type'] == 'purchase' ? Icons.arrow_upward : Icons.arrow_downward,
                            color: tx['type'] == 'purchase' ? Colors.green : const Color(0xFFF97316),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx['type'] == 'purchase' ? 'Credit Purchase' : 'Project Unlock', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(_formatDate(tx['timestamp'] ?? ''), style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ],
                          ),
                        ),
                        Text(
                          '${tx['type'] == 'purchase' ? '+' : '-'}${tx['creditAmount'] ?? 0}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: tx['type'] == 'purchase' ? Colors.green : const Color(0xFFF97316)),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _packageCard(Map<String, dynamic> pkg) {
    final isPopular = pkg['badge'] != null;
    final isBuying = _buyingId == pkg['name'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPopular ? const Color(0xFFF97316) : Colors.grey.shade200, width: isPopular ? 2 : 1),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pkg['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(text: '${pkg['credits']} Credits', style: const TextStyle(fontSize: 15, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                          TextSpan(text: '  (\$${pkg['perCredit']}/credit)', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        ]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${pkg['price']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton(
                        onPressed: isBuying ? null : () => _buyCredits(pkg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: isBuying
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Buy Now', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPopular)
            Positioned(
              top: -10,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(20)),
                child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
