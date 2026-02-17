import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';

class ContractorBidsScreen extends StatefulWidget {
  const ContractorBidsScreen({super.key});

  @override
  State<ContractorBidsScreen> createState() => _ContractorBidsScreenState();
}

class _ContractorBidsScreenState extends State<ContractorBidsScreen> {
  List<Map<String, dynamic>> _bids = [];
  bool _loading = true;

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _loadBids();
  }

  Future<void> _loadBids() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;

    try {
      final snap = await _db().child('bids').get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final bids = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          final bid = Map<String, dynamic>.from(value as Map);
          if (bid['contractorUid'] == uid) {
            bid['id'] = key;
            bids.add(bid);
          }
        });
        bids.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
        setState(() => _bids = bids);
      }
    } catch (e) {
      debugPrint('Error loading bids: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('My Bids')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : _bids.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No bids submitted yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Browse the marketplace to find projects', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bids.length,
                  itemBuilder: (ctx, i) {
                    final bid = _bids[i];
                    final status = bid['status'] ?? 'submitted';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316).withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(bid['projectCategory'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.attach_money, size: 18, color: Colors.grey[400]),
                              Text('\$${(bid['totalCost'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 16),
                              Icon(Icons.schedule, size: 18, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(bid['estimatedTimeline'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
