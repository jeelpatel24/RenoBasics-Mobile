import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Unlock a project for a contractor. Deducts credits, creates unlock record and transaction.
  /// Returns true on success, false on failure.
  static Future<bool> unlockProject(
      String contractorUid, String projectId, int creditCost) async {
    try {
      final unlockKey = '${contractorUid}_$projectId';

      if (creditCost <= 0) return false;

      // Check if already unlocked
      final unlockDoc =
          await _firestore.collection('unlocks').doc(unlockKey).get();
      if (unlockDoc.exists) return true; // already unlocked

      // Use transaction for atomic operations
      final result = await _firestore.runTransaction((transaction) async {
        // Get current credit balance
        final userDoc = await transaction.get(
            _firestore.collection('users').doc(contractorUid));
        final currentBalance = (userDoc.data()?['creditBalance'] as num?)?.toInt() ?? 0;

        if (currentBalance < creditCost) return false;

        // Get homeownerUid from the project
        final projectDoc =
            await transaction.get(_firestore.collection('projects').doc(projectId));
        final homeownerUid = projectDoc.data()?['homeownerUid'] as String? ?? '';

        final now = DateTime.now();
        final nowIso = now.toIso8601String();

        // Update user credit balance
        transaction.update(_firestore.collection('users').doc(contractorUid),
            {'creditBalance': currentBalance - creditCost});

        // Create unlock record
        transaction.set(
            _firestore.collection('unlocks').doc(unlockKey),
            {
              'contractorUid': contractorUid,
              'projectId': projectId,
              'homeownerUid': homeownerUid,
              'creditCost': creditCost,
              'unlockedAt': nowIso,
            });

        // Create transaction record (pre-generate the ID so we can store it)
        final txRef = _firestore.collection('transactions').doc();
        transaction.set(txRef, {
          'id': txRef.id,
          'contractorUid': contractorUid,
          'creditAmount': creditCost,
          'cost': 0,
          'type': 'unlock',
          'relatedProjectId': projectId,
          'timestamp': nowIso,
        });

        return true;
      });

      return result;
    } catch (_) {
      return false;
    }
  }

  /// Get the set of project IDs this contractor has unlocked.
  static Future<Set<String>> getContractorUnlocks(String contractorUid) async {
    try {
      final query = await _firestore
          .collection('unlocks')
          .where('contractorUid', isEqualTo: contractorUid)
          .get();

      final projectIds = <String>{};
      for (final doc in query.docs) {
        final pid = doc.data()['projectId'] as String?;
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
      final doc = await _firestore.collection('projects').doc(projectId).get();
      if (!doc.exists) return null;
      return doc.data()?['privateDetails'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Get all projects, ordered by creation date.
  static Future<List<DocumentSnapshot>> getProjects() async {
    try {
      final query = await _firestore
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .get();
      return query.docs;
    } catch (_) {
      return [];
    }
  }

  /// Subscribe to open projects stream for real-time updates.
  /// Only returns projects with status == 'open' (matches the marketplace filter).
  static Stream<QuerySnapshot> subscribeToProjects() {
    return _firestore
        .collection('projects')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Create a new project.
  static Future<String> createProject(Map<String, dynamic> data) async {
    try {
      final ref = await _firestore.collection('projects').add(data);
      return ref.id;
    } catch (_) {
      rethrow;
    }
  }

  /// Update project status.
  static Future<void> updateProjectStatus(String projectId, String status) async {
    try {
      await _firestore.collection('projects').doc(projectId).update({
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      rethrow;
    }
  }
}
