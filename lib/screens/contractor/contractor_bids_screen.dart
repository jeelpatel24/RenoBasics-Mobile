import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/bid_service.dart';
import 'package:renobasic/utils/app_toast.dart';

class ContractorBidsScreen extends StatefulWidget {
  const ContractorBidsScreen({super.key});

  @override
  State<ContractorBidsScreen> createState() => _ContractorBidsScreenState();
}

class _ContractorBidsScreenState extends State<ContractorBidsScreen> {
  String? _loadedUid;
  Future<List<dynamic>>? _bidsFuture;
  String _filter = 'all'; // all | submitted | accepted | rejected

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid != null && uid != _loadedUid) {
      _loadedUid = uid;
      _bidsFuture = BidService.getContractorBids(uid);
    }
  }

  Future<void> _loadBids() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;
    setState(() {
      _bidsFuture = BidService.getContractorBids(uid);
    });
  }

  Future<void> _withdrawBid(String bidId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Bid'),
        content: const Text(
            'Are you sure you want to withdraw this bid? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await BidService.withdrawBid(bidId);
      if (mounted) {
        AppToast.show(context, 'Bid withdrawn successfully.');
        _loadBids();
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Failed to withdraw bid.', isError: true);
      }
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Bids'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/contractor-reviews'),
            icon: const Icon(Icons.star_rounded,
                size: 18, color: Color(0xFFF97316)),
            label: const Text('Reviews',
                style:
                    TextStyle(color: Color(0xFFF97316), fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter tabs ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['all', 'submitted', 'accepted', 'rejected']
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _filter = f),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _filter == f
                                        ? const Color(0xFFF97316)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(20),
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
                    child: CircularProgressIndicator(
                        color: Color(0xFFF97316)))
                : FutureBuilder(
                    future: _bidsFuture,
                    builder: (ctx, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFF97316)));
                      }
                      if (!snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return _emptyState(
                          'No bids submitted yet',
                          'Browse the marketplace to find projects',
                        );
                      }

                      final allBids = snapshot.data!;
                      final filtered = _filter == 'all'
                          ? allBids
                          : allBids.where((b) {
                              final s = (b.data() as Map<String,
                                      dynamic>)['status']
                                  as String? ??
                                  'submitted';
                              return s == _filter;
                            }).toList();

                      if (filtered.isEmpty) {
                        return _emptyState(
                          'No ${_filter} bids',
                          'No bids with this status yet.',
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _loadBids,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final doc = filtered[i];
                            final bid = doc.data()
                                as Map<String, dynamic>;
                            final bidId = doc.id;
                            final status = bid['status'] as String? ??
                                'submitted';
                            final projectId =
                                bid['projectId'] as String? ?? '';

                            return GestureDetector(
                              onTap: () {
                                if (projectId.isNotEmpty) {
                                  Navigator.pushNamed(
                                    context,
                                    '/project-detail',
                                    arguments: {
                                      'projectId': projectId
                                    },
                                  );
                                }
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _badge(
                                            bid['projectCategory'] ??
                                                '',
                                            const Color(0xFFF97316)),
                                        const SizedBox(width: 8),
                                        _badge(
                                          status[0].toUpperCase() +
                                              status.substring(1),
                                          _statusColor(status),
                                          icon: _statusIcon(status),
                                        ),
                                        const Spacer(),
                                        if (status == 'submitted')
                                          GestureDetector(
                                            onTap: () =>
                                                _withdrawBid(bidId),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(
                                                      6),
                                              decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withAlpha(25),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8),
                                              ),
                                              child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 18),
                                            ),
                                          ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right,
                                            color: Colors.grey[400],
                                            size: 18),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.attach_money,
                                            size: 18,
                                            color: Colors.grey[400]),
                                        Text(
                                          '\$${(bid['totalCost'] as num? ?? 0).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(Icons.schedule,
                                            size: 18,
                                            color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            bid['estimatedTimeline'] ??
                                                '',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((bid['submittedAt'] as String?)
                                            ?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Submitted ${_formatDate(bid['submittedAt'] as String)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[400]),
                                      ),
                                    ],
                                  ],
                                ),
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

  Widget _badge(String label, Color color, {IconData? icon}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
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
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
