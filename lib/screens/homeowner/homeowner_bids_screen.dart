import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/bid_service.dart';

class HomeownerBidsScreen extends StatefulWidget {
  const HomeownerBidsScreen({super.key});

  @override
  State<HomeownerBidsScreen> createState() => _HomeownerBidsScreenState();
}

class _HomeownerBidsScreenState extends State<HomeownerBidsScreen> {
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
          if (bid['homeownerUid'] == uid) {
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

  Future<void> _updateBidStatus(String bidId, String status) async {
    try {
      await BidService.updateBidStatus(bidId, status);
      Fluttertoast.showToast(msg: 'Bid ${status}!');
      await _loadBids();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update bid');
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
      appBar: AppBar(title: const Text('Bids Received')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : _bids.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No bids received yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Post a project and contractors will submit bids', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bids.length,
                  itemBuilder: (ctx, i) {
                    final bid = _bids[i];
                    final status = bid['status'] ?? 'submitted';
                    final items = bid['itemizedCosts'] != null
                        ? List<Map<String, dynamic>>.from((bid['itemizedCosts'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                        : <Map<String, dynamic>>[];

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
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFF97316).withAlpha(25), borderRadius: BorderRadius.circular(20)),
                                    child: Text(bid['projectCategory'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: _statusColor(status).withAlpha(25), borderRadius: BorderRadius.circular(20)),
                                    child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              Text('\$${(bid['totalCost'] ?? 0).toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(bid['contractorName'] ?? 'Contractor', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Itemized costs
                          if (items.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                children: [
                                  ...items.map((item) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(item['description'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                                            Text('\$${(item['cost'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(bid['estimatedTimeline'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                          if (bid['notes'] != null && (bid['notes'] as String).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('"${bid['notes']}"', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[500])),
                          ],

                          // Accept/Reject
                          if (status == 'submitted') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateBidStatus(bid['id'], 'accepted'),
                                    icon: const Icon(Icons.check_circle, size: 18),
                                    label: const Text('Accept'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateBidStatus(bid['id'], 'rejected'),
                                    icon: const Icon(Icons.cancel, size: 18),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
