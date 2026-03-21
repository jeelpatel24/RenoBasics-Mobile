import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/bid_service.dart';
import 'package:renobasic/services/notification_service.dart';
import 'package:renobasic/services/review_service.dart';
import 'package:renobasic/screens/homeowner/submit_review_screen.dart';
import 'package:renobasic/utils/app_toast.dart';

class HomeownerProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const HomeownerProjectDetailScreen({super.key, required this.projectId});

  @override
  State<HomeownerProjectDetailScreen> createState() =>
      _HomeownerProjectDetailScreenState();
}

class _HomeownerProjectDetailScreenState
    extends State<HomeownerProjectDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _project;
  List<DocumentSnapshot> _bids = [];
  Set<String> _reviewedBidIds = {};
  bool _loading = true;
  bool _deleting = false;

  static const Map<String, String> _statusLabels = {
    'open': 'Open',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'closed': 'Closed',
  };

  static const Map<String, Color> _statusColors = {
    'open': Colors.green,
    'in_progress': Colors.blue,
    'completed': Colors.purple,
    'closed': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final projectDoc = await _firestore
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final bids = await BidService.getBidsForProject(widget.projectId);
      final uid =
          context.read<AuthProvider>().userProfile?.uid ?? '';
      final reviewedIds =
          await ReviewService.getHomeownerReviewedBidIds(uid);

      if (mounted) {
        setState(() {
          _project =
              projectDoc.exists ? projectDoc.data() as Map<String, dynamic> : null;
          _bids = bids;
          _reviewedBidIds = reviewedIds;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.show(context, 'Failed to load project', isError: true);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await _firestore
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      setState(() {
        _project?['status'] = newStatus;
      });
      if (mounted) {
        AppToast.show(
            context, 'Status updated to ${_statusLabels[newStatus]}');
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Failed to update status', isError: true);
      }
    }
  }

  void _showStatusMenu() {
    final currentStatus = _project?['status'] as String? ?? 'open';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Project Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statusLabels.entries.map((e) {
              final isSelected = e.key == currentStatus;
              return ListTile(
                dense: true,
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColors[e.key] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(e.value),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Color(0xFFF97316))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (!isSelected) _updateStatus(e.key);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
            'This will permanently delete the project and all associated bids. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      // Delete all bids for this project
      final batch = _firestore.batch();
      for (final bid in _bids) {
        batch.delete(bid.reference);
      }
      batch.delete(
          _firestore.collection('projects').doc(widget.projectId));
      await batch.commit();

      if (mounted) {
        AppToast.show(context, 'Project deleted');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        AppToast.show(context, 'Failed to delete project', isError: true);
      }
    }
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
          title:
              status == 'accepted' ? 'Bid Accepted!' : 'Bid Rejected',
          message:
              'Your bid for "$projectCategory" has been $status.',
          relatedId: widget.projectId,
        );
      }
      if (mounted) AppToast.show(context, 'Bid $status!');
      await _loadData();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Failed to update bid', isError: true);
      }
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
          contractorName:
              bid['contractorName'] as String? ?? 'Contractor',
          projectId: widget.projectId,
          projectCategory:
              bid['projectCategory'] as String? ?? '',
        ),
      ),
    );
    if (result == true && mounted) {
      final uid =
          context.read<AuthProvider>().userProfile?.uid ?? '';
      final ids =
          await ReviewService.getHomeownerReviewedBidIds(uid);
      if (mounted) setState(() => _reviewedBidIds = ids);
    }
  }

  Color _bidStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  String _timeAgo(dynamic value) {
    try {
      DateTime dt;
      if (value is String) {
        dt = DateTime.parse(value).toLocal();
      } else if (value is Timestamp) {
        dt = value.toDate().toLocal();
      } else {
        return '';
      }
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 30) return '${dt.day}/${dt.month}/${dt.year}';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return '${diff.inMinutes}m ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFFF97316))),
      );
    }

    if (_project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const Center(child: Text('Project not found')),
      );
    }

    final status = _project!['status'] as String? ?? 'open';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final statusLabel = _statusLabels[status] ?? status;
    final projectTitle = _project!['projectTitle'] as String? ?? '';
    final categoryName = _project!['categoryName'] as String? ?? '';
    final budgetLabel = _project!['budgetLabel'] as String? ?? '';
    final city = _project!['city'] as String? ?? '';
    final creditCost = _project!['creditCost'] as int? ?? 0;
    final createdAt = _project!['createdAt'];

    // Private details (embedded in the project document)
    final privateDetails =
        _project!['privateDetails'] as Map<String, dynamic>?;
    final description =
        privateDetails?['fullDescription'] as String? ?? '';
    final scopeRaw = privateDetails?['scopeOfWork'];
    final scopeList = scopeRaw is List
        ? scopeRaw.map((e) => e.toString()).toList()
        : <String>[];
    final streetAddress = privateDetails?['streetAddress'] as String? ?? '';
    final unit = privateDetails?['unit'] as String? ?? '';
    final fullAddress = [
      if (unit.isNotEmpty) unit,
      if (streetAddress.isNotEmpty) streetAddress,
    ].join(', ');

    // Bid comparison: only submitted bids
    final submittedBids = _bids
        .where((b) => (b.data() as Map<String, dynamic>)['status'] == 'submitted')
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
            projectTitle.isNotEmpty ? projectTitle : categoryName,
            overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          if (_deleting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Color(0xFFF97316), strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Project',
              onPressed: _deleteProject,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Project Info Card ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (projectTitle.isNotEmpty)
                                Text(
                                  projectTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                              Text(
                                categoryName,
                                style: TextStyle(
                                  color: projectTitle.isNotEmpty
                                      ? Colors.grey[600]
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showStatusMenu,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withAlpha(100)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.expand_more,
                                    size: 14, color: statusColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Meta chips
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (budgetLabel.isNotEmpty)
                          _metaChip(Icons.attach_money, budgetLabel,
                              Colors.green),
                        if (city.isNotEmpty)
                          _metaChip(
                              Icons.location_on, city, Colors.red),
                        _metaChip(Icons.token,
                            '$creditCost credits to unlock', const Color(0xFFF97316)),
                        if (createdAt != null)
                          _metaChip(Icons.access_time,
                              _timeAgo(createdAt), Colors.grey),
                      ],
                    ),

                    if (fullAddress.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.home,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(fullAddress,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600]))),
                        ],
                      ),
                    ],

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Description',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(description,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[700])),
                    ],

                    if (scopeList.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Scope of Work',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: scopeList
                            .map((s) => Chip(
                                  label: Text(s,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor:
                                      const Color(0xFFF97316).withAlpha(25),
                                  side: BorderSide(
                                      color: const Color(0xFFF97316)
                                          .withAlpha(75)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Bid Comparison Table (2+ submitted bids) ────────────
              if (submittedBids.length >= 2) ...[
                const Text(
                  'Bid Comparison',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text('Contractor',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 2,
                                child: Text('Amount',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 2,
                                child: Text('Timeline',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...submittedBids.asMap().entries.map((entry) {
                        final i = entry.key;
                        final bid = entry.value.data()
                            as Map<String, dynamic>;
                        final isLast = i == submittedBids.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      bid['contractorName'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '\$${(bid['totalCost'] as num? ?? 0).toStringAsFixed(0)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF97316)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      bid['estimatedTimeline'] ?? '',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              const Divider(height: 1, indent: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Bids ────────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'Bids',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_bids.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF97316),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_bids.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text(
                        'No bids yet',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contractors will submit bids once they unlock this project.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bids.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final bid =
                        _bids[index].data() as Map<String, dynamic>;
                    final bidId = _bids[index].id;
                    final bidStatus =
                        bid['status'] as String? ?? 'submitted';
                    final items = bid['itemizedCosts'] != null
                        ? List<Map<String, dynamic>>.from(
                            (bid['itemizedCosts'] as List).map(
                                (e) => Map<String, dynamic>.from(e as Map)))
                        : <Map<String, dynamic>>[];
                    final alreadyReviewed =
                        _reviewedBidIds.contains(bidId);

                    return Container(
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
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _bidStatusColor(bidStatus)
                                      .withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  bidStatus[0].toUpperCase() +
                                      bidStatus.substring(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _bidStatusColor(bidStatus),
                                  ),
                                ),
                              ),
                              Text(
                                '\$${(bid['totalCost'] as num? ?? 0).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF97316),
                                ),
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
                                bid['contractorName'] ?? 'Contractor',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),

                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: items
                                    .map((item) => Padding(
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
                                                          .grey[600]),
                                                ),
                                              ),
                                              Text(
                                                '\$${(item['cost'] as num? ?? 0).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],

                          if ((bid['estimatedTimeline'] as String? ?? '')
                              .isNotEmpty) ...[
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
                          ],

                          if ((bid['notes'] as String? ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '"${bid['notes']}"',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[500]),
                            ),
                          ],

                          // Accept / Reject
                          if (bidStatus == 'submitted') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateBidStatus(
                                        bidId, 'accepted', bid),
                                    icon: const Icon(Icons.check_circle,
                                        size: 18),
                                    label: const Text('Accept'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateBidStatus(
                                        bidId, 'rejected', bid),
                                    icon: const Icon(Icons.cancel, size: 18),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Review for accepted bids
                          if (bidStatus == 'accepted') ...[
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
                                          color: const Color(0xFFFBBF24)),
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
                                                color: Color(0xFFB45309),
                                                fontWeight: FontWeight.w600,
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
                                              color: Color(0xFFF97316))),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: Color(0xFFF97316)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
