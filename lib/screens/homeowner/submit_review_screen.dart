import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/review_service.dart';
import 'package:renobasic/services/notification_service.dart';
import 'package:renobasic/utils/app_toast.dart';

class SubmitReviewScreen extends StatefulWidget {
  final String bidId;
  final String contractorUid;
  final String contractorName;
  final String projectId;
  final String projectCategory;

  const SubmitReviewScreen({
    super.key,
    required this.bidId,
    required this.contractorUid,
    required this.contractorName,
    required this.projectId,
    required this.projectCategory,
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _loading = false;

  static const List<String> _labels = [
    '',
    'Poor',
    'Fair',
    'Good',
    'Very Good',
    'Excellent',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppToast.show(context, 'Please select a star rating', isError: true);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final homeownerUid = authProvider.userProfile?.uid ?? '';
    final homeownerName = authProvider.userProfile?.fullName ?? 'Homeowner';

    if (homeownerUid.isEmpty) {
      AppToast.show(
        context,
        'You must be logged in to submit a review',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ReviewService.submitReview(
        contractorUid: widget.contractorUid,
        homeownerUid: homeownerUid,
        homeownerName: homeownerName,
        projectId: widget.projectId,
        bidId: widget.bidId,
        rating: _rating,
        comment: _commentController.text.trim(),
        projectCategory: widget.projectCategory,
        contractorName: widget.contractorName,
      );
      // Notify the contractor they received a new review
      await NotificationService.createNotification(
        recipientUid: widget.contractorUid,
        type: 'new_review',
        title: 'New Review Received!',
        message:
            '$homeownerName rated you $_rating star${_rating != 1 ? 's' : ''} for ${widget.projectCategory}.',
        relatedId: widget.projectId,
      );
      if (!mounted) return;
      AppToast.show(context, 'Review submitted successfully!');
      Navigator.of(context).pop(true); // true signals that a review was submitted
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Failed to submit review. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Leave a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contractor info card ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contractor',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.contractorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.projectCategory,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Star rating ───────────────────────────────────────────
            const Text(
              'Your Rating *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.star_rounded,
                      size: 44,
                      color: star <= _rating
                          ? const Color(0xFFFBBF24)
                          : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _labels[_rating],
                style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Comment ───────────────────────────────────────────────
            const Text(
              'Comment (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Share your experience with this contractor...',
              ),
            ),

            const SizedBox(height: 32),

            // ── Submit button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
