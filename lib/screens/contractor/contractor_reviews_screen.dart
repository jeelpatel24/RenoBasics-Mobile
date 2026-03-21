import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/review_service.dart';

class ContractorReviewsScreen extends StatefulWidget {
  const ContractorReviewsScreen({super.key});

  @override
  State<ContractorReviewsScreen> createState() =>
      _ContractorReviewsScreenState();
}

class _ContractorReviewsScreenState extends State<ContractorReviewsScreen> {
  String? _loadedUid;
  Future<List<Map<String, dynamic>>>? _reviewsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid != null && uid != _loadedUid) {
      _loadedUid = uid;
      _reviewsFuture = ReviewService.getContractorReviews(uid);
    }
  }

  Future<void> _reload() async {
    final uid = context.read<AuthProvider>().userProfile?.uid;
    if (uid == null) return;
    setState(() {
      _reviewsFuture = ReviewService.getContractorReviews(uid);
    });
  }

  Widget _buildStars(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < rating ? const Color(0xFFFBBF24) : Colors.grey[300],
          size: size,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Reviews')),
      body: _reviewsFuture == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewsFuture,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFF97316)));
                }

                final reviews = snapshot.data ?? [];

                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_outline_rounded,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Reviews appear after homeowners rate your work',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[400]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final avgRating = reviews.fold<double>(
                        0,
                        (sum, r) =>
                            sum + ((r['rating'] as num?)?.toDouble() ?? 0)) /
                    reviews.length;

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF97316)),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStars(avgRating.round(), size: 22),
                                const SizedBox(height: 6),
                                Text(
                                  '${reviews.length} review${reviews.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Review cards
                      ...reviews.map((r) {
                        final rating =
                            (r['rating'] as num?)?.toInt() ?? 0;
                        final comment = r['comment'] as String? ?? '';
                        final homeownerName =
                            r['homeownerName'] as String? ?? 'Homeowner';
                        final projectCategory =
                            r['projectCategory'] as String? ?? '';

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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person,
                                          size: 16,
                                          color: Colors.grey[400]),
                                      const SizedBox(width: 4),
                                      Text(
                                        homeownerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  _buildStars(rating),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (projectCategory.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF97316)
                                        .withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    projectCategory,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFF97316)),
                                  ),
                                ),
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '"$comment"',
                                  style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
