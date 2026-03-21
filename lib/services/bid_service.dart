import 'package:cloud_firestore/cloud_firestore.dart';

class BidService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a bid on a project. Returns the bid ID.
  static Future<String> submitBid({
    required String contractorUid,
    required String homeownerUid,
    required String projectId,
    required String contractorName,
    required String projectCategory,
    required List<Map<String, dynamic>> itemizedCosts,
    required double totalCost,
    required String estimatedTimeline,
    required String notes,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final ref = await _firestore.collection('bids').add({
      'contractorUid': contractorUid,
      'homeownerUid': homeownerUid,
      'projectId': projectId,
      'contractorName': contractorName,
      'projectCategory': projectCategory,
      'itemizedCosts': itemizedCosts,
      'totalCost': totalCost,
      'estimatedTimeline': estimatedTimeline,
      'notes': notes,
      'status': 'submitted',
      'submittedAt': nowIso,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    });

    return ref.id;
  }

  /// Get bids for a specific project.
  static Future<List<DocumentSnapshot>> getBidsForProject(String projectId) async {
    try {
      final query = await _firestore
          .collection('bids')
          .where('projectId', isEqualTo: projectId)
          .get();
      return query.docs;
    } catch (_) {
      return [];
    }
  }

  /// Get all bids submitted by a contractor.
  static Future<List<DocumentSnapshot>> getContractorBids(String contractorUid) async {
    try {
      final query = await _firestore
          .collection('bids')
          .where('contractorUid', isEqualTo: contractorUid)
          .orderBy('submittedAt', descending: true)
          .get();
      return query.docs;
    } catch (_) {
      return [];
    }
  }

  /// Get all bids received by a homeowner.
  static Future<List<DocumentSnapshot>> getHomeownerBids(String homeownerUid) async {
    try {
      final query = await _firestore
          .collection('bids')
          .where('homeownerUid', isEqualTo: homeownerUid)
          .orderBy('submittedAt', descending: true)
          .get();
      return query.docs;
    } catch (_) {
      return [];
    }
  }

  /// Update bid status (e.g., accepted, rejected).
  static Future<void> updateBidStatus(String bidId, String status) async {
    await _firestore.collection('bids').doc(bidId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Withdraw (delete) a submitted bid. Only call when status == 'submitted'.
  static Future<void> withdrawBid(String bidId) async {
    await _firestore.collection('bids').doc(bidId).delete();
  }
}
