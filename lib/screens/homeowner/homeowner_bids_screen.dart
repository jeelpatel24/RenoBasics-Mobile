import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/utils/app_toast.dart';
import 'package:renobasic/services/bid_service.dart';
import 'package:renobasic/services/notification_service.dart';
import 'package:renobasic/services/review_service.dart';
import 'package:renobasic/screens/homeowner/submit_review_screen.dart';

class HomeownerBidsScreen extends StatefulWidget {
  const HomeownerBidsScreen({super.key});

  @override
  State<HomeownerBidsScreen> createState() => _HomeownerBidsScreenState();
}

class _HomeownerBidsScreenState extends State<HomeownerBidsScreen> {
  String? _loadedUid;
  Future<List<dynamic>>? _bidsFuture;
  Set<String> _reviewedBidIds = {};
  String _filter = 'all'; // all | submitted | accepted | rejected

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid != null && uid != _loadedUid) {
      _loadedUid = uid;
      _bidsFuture = BidService.getHomeownerBids(uid);
      _loadReviewedBidIds(uid);
    }
  }

  Future<void> _loadReviewedBidIds(String uid) async {
    final ids = await ReviewService.getHomeownerReviewedBidIds(uid);
    if (!mounted) return;
    setState(() => _reviewedBidIds = ids);
  }

  Future<void> _loadBids() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;
    setState(() {
      _bidsFuture = BidService.getHomeownerBids(uid);
    });
    _loadReviewedBidIds(uid);
  }

  Future<void> _updateBidStatus(
      String bidId, String status, Map<String, dynamic> bid) async {
    try {
      await BidService.updateBidStatus(bidId, status);
      final contractorUid = bid['contractorUid'] as String?;
      if (contractorUid != null) {
        final projectCategory =
            bid['projectCategory'] as String? ?? 'your project';
        await NotificationService.createNotification(
          recipientUid: contractorUid,
          type: status == 'accepted' ? 'bid_accepted' : 'bid_rejected',
          title: status == 'accepted' ? 'Bid Accepted!' : 'Bid Rejected',
          message: 'Your bid for "$projectCategory" has been $status.',
          relatedId: bid['projectId'] as String?,
        );
      }
      if (mounted) AppToast.show(context, 'Bid $status!');
      await _loadBids();
    } catch (_) {
      if (mounted) AppToast.show(context, 'Failed to update bid', isError: true);
    }
  }

  Future<void> _navigateToReview(
      String bidId, Map<String, dynamic> bid) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SubmitReviewScreen(
          bidId: bidId,
          contractorUid: bid['contractorUid'] as String? ?? '',
          contractorName: bid['contractorName'] as String? ?? 'Contractor',
          projectId: bid['projectId'] as String? ?? '',
          projectCategory: bid['projectCategory'] as String? ?? '',
        ),
      ),
    );
    if (result == true && mounted && _loadedUid != null) {
      _loadReviewedBidIds(_loadedUid!);
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
    context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Bids Received')),
      body: Column(
        children: [
          // ── Filter tabs ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'submitted', 'accepted', 'rejected']
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _filter == f
                                    ? const Color(0xFFF97316)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _filter == f
                                      ? const Color(0xFFF97316)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                f[0].toUpperCase() + f.substring(1),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _filter == f
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Bid list ─────────────────────────────────────────────
          Expanded(
            child: _bidsFuture == null
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFF97316)))
                : FutureBuilder(
                    future: _bidsFuture,
                    builder: (ctx, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFF97316)));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _emptyState(
                          'No bids received yet',
                          'Post a project and contractors will submit bids',
                        );
                      }

                      final allBids = snapshot.data!;
                      final filtered = _filter == 'all'
                          ? allBids
                          : allBids.where((b) {
                              final s = (b.data()
                                      as Map<String, dynamic>)['status']
                                  as String? ??
                                  'submitted';
                              return s == _filter;
                            }).toList();

                      if (filtered.isEmpty) {
                        return _emptyState(
                          'No ${_filter == 'all' ? '' : _filter} bids',
                          'No bids with this status yet.',
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _loadBids,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final bid = filtered[i].data()
                                as Map<String, dynamic>;
                            final bidId = filtered[i].id;
                            final status =
                                bid['status'] as String? ?? 'submitted';
                            final items = bid['itemizedCosts'] != null
                                ? List<Map<String, dynamic>>.from(
                                    (bid['itemizedCosts'] as List).map(
                                        (e) => Map<String, dynamic>.from(
                                            e as Map)))
                                : <Map<String, dynamic>>[];
                            final alreadyReviewed =
                                _reviewedBidIds.contains(bidId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Wrap(
                                          spacing: 8,
                                          children: [
                                            _badge(
                                                bid['projectCategory'] ?? '',
                                                const Color(0xFFF97316)),
                                            _badge(
                                              status[0].toUpperCase() +
                                                  status.substring(1),
                                              _statusColor(status),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${(bid['totalCost'] as num? ?? 0).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFF97316)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.person,
                                          size: 16, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                          bid['contractorName'] ??
                                              'Contractor',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Itemized costs
                                  if (items.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Column(
                                        children: [
                                          ...items.map((item) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                        child: Text(
                                                            item['description'] ??
                                                                '',
                                                            style: TextStyle(
                                                                fontSize: 13,
                                                                color: Colors
                                                                    .grey[600]))),
                                                    Text(
                                                        '\$${(item['cost'] as num? ?? 0).toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                  ],
                                                ),
                                              )),
                                          const Divider(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Total',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                '\$${(bid['totalCost'] as num? ?? 0).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFF97316)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule,
                                          size: 16, color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(bid['estimatedTimeline'] ?? '',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  if (bid['notes'] != null &&
                                      (bid['notes'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('"${bid['notes']}"',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[500])),
                                  ],

                                  // Accept / Reject buttons
                                  if (status == 'submitted') ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _updateBidStatus(
                                                    bidId, 'accepted', bid),
                                            icon: const Icon(
                                                Icons.check_circle,
                                                size: 18),
                                            label: const Text('Accept'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10))),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _updateBidStatus(
                                                    bidId, 'rejected', bid),
                                            icon: const Icon(Icons.cancel,
                                                size: 18),
                                            label: const Text('Reject'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10))),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Review for accepted bids
                                  if (status == 'accepted') ...[
                                    const SizedBox(height: 12),
                                    alreadyReviewed
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: const Color(
                                                      0xFFFBBF24)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star_rounded,
                                                    size: 16,
                                                    color: Color(0xFFF59E0B)),
                                                SizedBox(width: 6),
                                                Text('Reviewed',
                                                    style: TextStyle(
                                                        color: Color(
                                                            0xFFB45309),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13)),
                                              ],
                                            ),
                                          )
                                        : SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _navigateToReview(bidId, bid),
                                              icon: const Icon(
                                                  Icons.star_outline_rounded,
                                                  size: 18,
                                                  color: Color(0xFFF97316)),
                                              label: const Text('Leave Review',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFFF97316))),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: Color(0xFFF97316)),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                            ),
                                          ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  color: Colors.grey[500], fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
