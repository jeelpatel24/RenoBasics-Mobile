import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a new review for a contractor.
  static Future<void> submitReview({
    required String contractorUid,
    required String homeownerUid,
    required String homeownerName,
    required String projectId,
    required String bidId,
    required int rating,
    required String comment,
    required String projectCategory,
    required String contractorName,
  }) async {
    await _firestore.collection('reviews').add({
      'contractorUid': contractorUid,
      'homeownerUid': homeownerUid,
      'homeownerName': homeownerName,
      'projectId': projectId,
      'bidId': bidId,
      'rating': rating,
      'comment': comment,
      'projectCategory': projectCategory,
      'contractorName': contractorName,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Returns the set of bidIds that this homeowner has already reviewed.
  static Future<Set<String>> getHomeownerReviewedBidIds(
      String homeownerUid) async {
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('homeownerUid', isEqualTo: homeownerUid)
          .get();
      return snap.docs
          .map((d) => d.data()['bidId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Returns all reviews for a contractor, newest first.
  static Future<List<Map<String, dynamic>>> getContractorReviews(
      String contractorUid) async {
    try {
      final snap = await _firestore
          .collection('reviews')
          .where('contractorUid', isEqualTo: contractorUid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }
}
