import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class BidService {
  static DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

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
    final bidRef = _db().child('bids').push();
    final now = DateTime.now().toIso8601String();

    await bidRef.set({
      'id': bidRef.key,
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
      'createdAt': now,
      'updatedAt': now,
    });

    return bidRef.key!;
  }

  /// Update bid status (e.g., accepted, rejected).
  static Future<void> updateBidStatus(String bidId, String status) async {
    final now = DateTime.now().toIso8601String();
    await _db().child('bids/$bidId').update({
      'status': status,
      'updatedAt': now,
    });
  }
}
