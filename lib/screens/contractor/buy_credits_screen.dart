import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:renobasic/utils/app_toast.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:renobasic/providers/auth_provider.dart';

class BuyCreditsScreen extends StatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  State<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends State<BuyCreditsScreen> {
  static const List<Map<String, dynamic>> _defaultPackages = [
    {'name': 'Starter Pack', 'credits': 5, 'price': 29.99, 'perCredit': '6.00'},
    {'name': 'Standard Pack', 'credits': 15, 'price': 79.99, 'perCredit': '5.33'},
    {'name': 'Pro Pack', 'credits': 30, 'price': 149.99, 'perCredit': '5.00'},
    {'name': 'Enterprise Pack', 'credits': 60, 'price': 279.99, 'perCredit': '4.67'},
  ];

  List<Map<String, dynamic>> _packages = [];
  String? _buyingId;
  Future<List<DocumentSnapshot>>? _transactionsFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _packages = List.from(_defaultPackages);
    _loadPackages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_transactionsFuture == null) {
      _refreshTransactions();
    }
  }

  void _refreshTransactions() {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid != null) {
      setState(() {
        _transactionsFuture = _firestore
            .collection('transactions')
            .where('contractorUid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .get()
            .then((snap) => snap.docs);
      });
    }
  }

  Future<void> _loadPackages() async {
    try {
      final snap = await _firestore.collection('settings').doc('creditPackages').get();
      if (snap.exists) {
        final data = snap.data()!;
        final rawList = data['packages'] as List<dynamic>?;
        if (rawList != null && rawList.isNotEmpty) {
          final pkgs = rawList.map((p) {
            final map = p as Map<String, dynamic>;
            final credits = (map['credits'] as num).toInt();
            final price = (map['price'] as num).toDouble();
            final perCredit = credits > 0 ? (price / credits).toStringAsFixed(2) : '0.00';
            return <String, dynamic>{
              'name': map['label'] as String,
              'credits': credits,
              'price': price,
              'perCredit': perCredit,
            };
          }).toList();
          if (mounted) setState(() => _packages = pkgs);
        }
      }
    } catch (_) {
      // Fall back to defaults silently
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
      final now = DateTime.now();
      final userRef = _firestore.collection('users').doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentBalance = (userDoc.data()?['creditBalance'] as num?)?.toInt() ?? 0;

        transaction.update(userRef, {
          'creditBalance': currentBalance + (pkg['credits'] as int),
        });

        transaction.set(_firestore.collection('transactions').doc(), {
          'contractorUid': user.uid,
          'creditAmount': pkg['credits'],
          'cost': pkg['price'],
          'type': 'purchase',
          'timestamp': now.toIso8601String(),
        });
      });

      await auth.refreshProfile();
      _refreshTransactions();
      if (mounted) AppToast.show(context, '${pkg['credits']} credits added!');
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to purchase credits', isError: true);
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

            ...List.generate(_packages.length, (i) => _packageCard(_packages[i], isPopular: i == 1)),

            const SizedBox(height: 28),

            // Credit Usage Chart + Transaction History (shared FutureBuilder)
            FutureBuilder<List<DocumentSnapshot>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Color(0xFFF97316))));
                }

                final transactions = snapshot.data ?? [];
                int totalPurchased = 0;
                int totalSpent = 0;
                for (final txDoc in transactions) {
                  final txData = txDoc.data() as Map<String, dynamic>;
                  final amount = (txData['creditAmount'] as num?)?.toInt() ?? 0;
                  if (txData['type'] == 'purchase') { totalPurchased += amount; }
                  else if (txData['type'] == 'unlock') { totalSpent += amount; }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Credit Usage Summary Card
                    if (totalPurchased > 0 || totalSpent > 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Credit Usage Summary',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 40,
                                        sections: [
                                          if (totalPurchased > 0)
                                            PieChartSectionData(
                                              value: totalPurchased.toDouble(),
                                              color: const Color(0xFF22c55e),
                                              title: '$totalPurchased',
                                              radius: 52,
                                              titleStyle: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                          if (totalSpent > 0)
                                            PieChartSectionData(
                                              value: totalSpent.toDouble(),
                                              color: const Color(0xFFF97316),
                                              title: '$totalSpent',
                                              radius: 52,
                                              titleStyle: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _legendItem(const Color(0xFF22c55e), 'Purchased', totalPurchased),
                                      const SizedBox(height: 12),
                                      _legendItem(const Color(0xFFF97316), 'Spent', totalSpent),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Transaction History
                    const Text('Transaction History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long, size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('No transactions yet',
                                style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Purchase credits to see history here',
                                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: transactions.map((txDoc) {
                          final txData = txDoc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: txData['type'] == 'purchase'
                                        ? Colors.green.withAlpha(25)
                                        : const Color(0xFFF97316).withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    txData['type'] == 'purchase'
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: txData['type'] == 'purchase'
                                        ? Colors.green
                                        : const Color(0xFFF97316),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          txData['type'] == 'purchase'
                                              ? 'Credit Purchase'
                                              : 'Project Unlock',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(
                                          _formatDate(txData['timestamp']),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[400])),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${txData['type'] == 'purchase' ? '+' : '-'}${txData['creditAmount'] ?? 0}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: txData['type'] == 'purchase'
                                          ? Colors.green
                                          : const Color(0xFFF97316)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, int value) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text('$label: $value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _packageCard(Map<String, dynamic> pkg, {bool isPopular = false}) {
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

  String _formatDate(dynamic value) {
    try {
      DateTime dt;
      if (value is Timestamp) {
        dt = value.toDate();
      } else {
        dt = DateTime.parse(value.toString());
      }
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
