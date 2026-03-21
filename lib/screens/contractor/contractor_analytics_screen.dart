import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/review_service.dart';

class ContractorAnalyticsScreen extends StatefulWidget {
  const ContractorAnalyticsScreen({super.key});

  @override
  State<ContractorAnalyticsScreen> createState() =>
      _ContractorAnalyticsScreenState();
}

class _ContractorAnalyticsScreenState
    extends State<ContractorAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  int _totalBids = 0;
  int _acceptedBids = 0;
  int _rejectedBids = 0;
  int _unlockedProjects = 0;
  int _creditsSpent = 0;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final uid =
        context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _firestore
            .collection('bids')
            .where('contractorUid', isEqualTo: uid)
            .get(),
        _firestore
            .collection('unlocks')
            .where('contractorUid', isEqualTo: uid)
            .count()
            .get(),
        _firestore
            .collection('transactions')
            .where('contractorUid', isEqualTo: uid)
            .get(),
      ]);

      final bidsSnap = results[0] as QuerySnapshot;
      int accepted = 0;
      int rejected = 0;
      for (final doc in bidsSnap.docs) {
        final s = (doc.data() as Map<String, dynamic>)['status'] as String?;
        if (s == 'accepted') accepted++;
        if (s == 'rejected') rejected++;
      }

      final unlocksCount =
          (results[1] as AggregateQuerySnapshot).count ?? 0;

      final txSnap = results[2] as QuerySnapshot;
      int creditsSpent = 0;
      for (final doc in txSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['type'] == 'unlock') {
          creditsSpent +=
              (data['creditAmount'] as num?)?.abs().toInt() ?? 0;
        }
      }

      final reviews =
          await ReviewService.getContractorReviews(uid);

      if (mounted) {
        setState(() {
          _totalBids = bidsSnap.size;
          _acceptedBids = accepted;
          _rejectedBids = rejected;
          _unlockedProjects = unlocksCount;
          _creditsSpent = creditsSpent;
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(
        0, (acc, r) => acc + ((r['rating'] as int?) ?? 0));
    return sum / _reviews.length;
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
    final creditBalance =
        context.watch<AuthProvider>().userProfile?.creditBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // ── Stat Cards Grid ──────────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _statCard('Credits Balance',
                            '$creditBalance', Icons.token,
                            const Color(0xFFF97316)),
                        _statCard('Projects Unlocked',
                            '$_unlockedProjects', Icons.lock_open,
                            Colors.blue),
                        _statCard('Total Bids', '$_totalBids',
                            Icons.description, Colors.purple),
                        _statCard('Accepted Bids', '$_acceptedBids',
                            Icons.check_circle, Colors.green),
                        _statCard(
                          'Avg Rating',
                          _reviews.isNotEmpty
                              ? _avgRating.toStringAsFixed(1)
                              : '—',
                          Icons.star,
                          Colors.amber,
                        ),
                        _statCard('Credits Spent', '$_creditsSpent',
                            Icons.credit_card_off, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Credit Usage Summary ─────────────────────────
                    if (_creditsSpent > 0) ...[
                      const Text(
                        'Credit Usage',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                                child: _summaryCell(
                                    'Credits Spent',
                                    '$_creditsSpent',
                                    const Color(0xFFF97316))),
                            Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.shade200),
                            Expanded(
                                child: _summaryCell(
                                    'Balance',
                                    '$creditBalance',
                                    Colors.green)),
                            Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.shade200),
                            Expanded(
                                child: _summaryCell(
                                    'Success Rate',
                                    _totalBids > 0
                                        ? '${((_acceptedBids / _totalBids) * 100).round()}%'
                                        : '0%',
                                    Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Charts ───────────────────────────────────────
                    const Text(
                      'Reports',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Bid Outcomes Pie Chart
                          const Text(
                            'Bid Outcomes',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          _totalBids > 0
                              ? _buildBidPieChart()
                              : Container(
                                  height: 160,
                                  alignment: Alignment.center,
                                  child: Text('No bid data yet',
                                      style: TextStyle(
                                          color: Colors.grey[400])),
                                ),
                          const SizedBox(height: 24),

                          const Divider(),
                          const SizedBox(height: 16),

                          // Credits Bar Chart
                          const Text(
                            'Credits Overview',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          _buildCreditsBarChart(creditBalance),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Reviews ──────────────────────────────────────
                    Row(
                      children: [
                        const Text(
                          'My Reviews',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        if (_reviews.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${_reviews.length}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_reviews.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.star_outline,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text('No reviews yet',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Reviews appear after homeowners rate your work.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Avg rating summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildStars(
                                    _avgRating.round(), size: 22),
                                const SizedBox(height: 4),
                                Text(
                                  'Based on ${_reviews.length} review${_reviews.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Individual reviews
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = _reviews[index];
                          final rating =
                              (r['rating'] as int?) ?? 0;
                          final comment =
                              r['comment'] as String? ?? '';
                          final homeownerName =
                              r['homeownerName'] as String? ?? '';
                          final projectCategory =
                              r['projectCategory'] as String? ?? '';
                          final createdAt = r['createdAt'];

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(homeownerName,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          if (projectCategory.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                        0xFFF97316)
                                                    .withAlpha(25),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                              ),
                                              child: Text(
                                                projectCategory,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(
                                                        0xFFF97316)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _buildStars(rating, size: 16),
                                        if (createdAt != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _timeAgo(createdAt),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '"$comment"',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildBidPieChart() {
    final pending =
        (_totalBids - _acceptedBids - _rejectedBids).clamp(0, _totalBids);
    final sections = <PieChartSectionData>[];
    if (_acceptedBids > 0) {
      sections.add(PieChartSectionData(
        value: _acceptedBids.toDouble(),
        color: Colors.green,
        title: '$_acceptedBids',
        radius: 52,
        titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ));
    }
    if (pending > 0) {
      sections.add(PieChartSectionData(
        value: pending.toDouble(),
        color: const Color(0xFFF97316),
        title: '$pending',
        radius: 52,
        titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ));
    }
    if (_rejectedBids > 0) {
      sections.add(PieChartSectionData(
        value: _rejectedBids.toDouble(),
        color: Colors.red,
        title: '$_rejectedBids',
        radius: 52,
        titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 40,
            sections: sections,
          )),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (_acceptedBids > 0)
              _legendItem(Colors.green, 'Accepted', _acceptedBids),
            if (pending > 0)
              _legendItem(
                  const Color(0xFFF97316), 'Pending', pending),
            if (_rejectedBids > 0)
              _legendItem(Colors.red, 'Rejected', _rejectedBids),
          ],
        ),
      ],
    );
  }

  Widget _buildCreditsBarChart(int creditBalance) {
    final maxY =
        (_creditsSpent > creditBalance ? _creditsSpent : creditBalance)
            .toDouble();
    final safeMax = maxY < 1 ? 1.0 : maxY;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: safeMax * 1.3,
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: _creditsSpent.toDouble(),
                  color: const Color(0xFFF97316),
                  width: 40,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: creditBalance.toDouble(),
                  color: Colors.green,
                  width: 40,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final labels = ['Spent', 'Balance'];
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[i],
                        style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text('$label ($value)',
            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildStars(int rating, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFFBBF24),
        );
      }),
    );
  }
}
