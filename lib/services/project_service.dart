import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class ProjectService {
  static DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  /// Unlock a project for a contractor. Deducts credits, creates unlock record and transaction.
  /// Returns true on success, false on failure.
  static Future<bool> unlockProject(
      String contractorUid, String projectId, int creditCost) async {
    try {
      final unlockKey = '${contractorUid}_$projectId';

      // Check if already unlocked
      final unlockSnap =
          await _db().child('unlocks/$unlockKey').get();
      if (unlockSnap.exists) return true; // already unlocked

      // Get current credit balance
      final userSnap =
          await _db().child('users/$contractorUid/creditBalance').get();
      final currentBalance = (userSnap.value as int?) ?? 0;

      if (currentBalance < creditCost) return false;

      // Get homeownerUid from the project
      final projectSnap =
          await _db().child('projects/$projectId/homeownerUid').get();
      final homeownerUid = projectSnap.value as String? ?? '';

      final now = DateTime.now().toIso8601String();
      final transactionRef = _db().child('transactions').push();

      // Multi-path update: deduct credits + create unlock + create transaction
      final updates = <String, dynamic>{
        'users/$contractorUid/creditBalance': currentBalance - creditCost,
        'unlocks/$unlockKey': {
          'contractorUid': contractorUid,
          'projectId': projectId,
          'homeownerUid': homeownerUid,
          'creditCost': creditCost,
          'unlockedAt': now,
        },
        'transactions/${transactionRef.key}': {
          'id': transactionRef.key,
          'uid': contractorUid,
          'type': 'unlock',
          'amount': -creditCost,
          'description': 'Unlocked project $projectId',
          'projectId': projectId,
          'createdAt': now,
        },
      };

      await _db().update(updates);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the set of project IDs this contractor has unlocked.
  static Future<Set<String>> getContractorUnlocks(String contractorUid) async {
    try {
      final snap = await _db()
          .child('unlocks')
          .orderByChild('contractorUid')
          .equalTo(contractorUid)
          .get();

      if (!snap.exists || snap.value == null) return {};

      final data = Map<String, dynamic>.from(snap.value as Map);
      final projectIds = <String>{};
      for (final entry in data.values) {
        final map = Map<String, dynamic>.from(entry as Map);
        final pid = map['projectId'] as String?;
        if (pid != null) projectIds.add(pid);
      }
      return projectIds;
    } catch (_) {
      return {};
    }
  }

  /// Get private details for a project (only accessible after unlock).
  static Future<Map<String, dynamic>?> getProjectPrivateDetails(
      String projectId) async {
    try {
      final snap =
          await _db().child('projects/$projectId/privateDetails').get();
      if (!snap.exists || snap.value == null) return null;
      return Map<String, dynamic>.from(snap.value as Map);
    } catch (_) {
      return null;
    }
  }
}
