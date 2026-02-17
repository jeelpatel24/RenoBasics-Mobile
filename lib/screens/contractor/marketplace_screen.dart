import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/project_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  DatabaseReference _dbRef() {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
    ).ref();
  }

  List<String> _unlockedIds = [];
  bool _unlocking = false;

  static const Map<String, IconData> _categoryIcons = {
    'kitchen': Icons.kitchen,
    'bathroom': Icons.bathtub,
    'basement': Icons.stairs,
    'roofing': Icons.roofing,
    'flooring': Icons.grid_on,
    'painting': Icons.format_paint,
    'plumbing': Icons.plumbing,
    'electrical': Icons.electrical_services,
    'landscaping': Icons.grass,
    'general': Icons.home_repair_service,
    'addition': Icons.add_home,
    'deck_patio': Icons.deck,
    'windows_doors': Icons.window,
    'hvac': Icons.ac_unit,
    'home_extension': Icons.add_home_work,
    'adu': Icons.cottage,
    'garage_conversion': Icons.garage,
    'full_renovation': Icons.construction,
    'commercial': Icons.business,
    'other': Icons.build,
  };

  static const Map<String, String> _propertyTypeLabels = {
    'house': 'House',
    'condo': 'Condo / Apartment',
    'townhouse': 'Townhouse',
    'commercial': 'Commercial',
    'other': 'Other',
  };

  static const Map<String, String> _startDateLabels = {
    'immediately': 'Immediately',
    'within_2_weeks': 'Within 2 Weeks',
    'within_month': 'Within a Month',
    'within_3_months': 'Within 3 Months',
    'flexible': 'Flexible',
  };

  @override
  void initState() {
    super.initState();
    _loadUnlocks();
  }

  Future<void> _loadUnlocks() async {
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;
    try {
      final ids = await ProjectService.getContractorUnlocks(user.uid);
      if (mounted) setState(() => _unlockedIds = ids.toList());
    } catch (e) {
      debugPrint('Error loading unlocks: $e');
    }
  }

  Future<void> _handleUnlock(Map<String, dynamic> project) async {
    final auth = context.read<AuthProvider>();
    final user = auth.userProfile;
    if (user == null) return;

    final creditCost = project['creditCost'] as int? ?? 0;
    final creditBalance = user.creditBalance;
    final projectId = project['id'] as String? ?? '';

    if (!user.isVerified) {
      Fluttertoast.showToast(msg: 'Your account must be verified to unlock projects.');
      return;
    }
    if (creditBalance < creditCost) {
      Fluttertoast.showToast(msg: 'Not enough credits. Please buy more credits.');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Unlock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock "${project['projectTitle'] ?? project['categoryName'] ?? 'this project'}" for $creditCost credits?',
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll get access to full description, address, scope of work, and contact details.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining balance: ${creditBalance - creditCost} credits',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _unlocking = true);
    try {
      await ProjectService.unlockProject(user.uid, projectId, creditCost);
      await auth.refreshProfile();
      setState(() => _unlockedIds.add(projectId));
      Fluttertoast.showToast(msg: 'Project unlocked! You can now view full details.');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to unlock project.');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;
    final isVerified = user?.isVerified ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Credit Balance Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFFB923C)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Credit Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${user?.creditBalance ?? 0} Credits',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/buy-credits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFF97316),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Buy More', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Projects List
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _dbRef().child('projects').orderByChild('status').equalTo('open').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF97316)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load projects',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data?.snapshot.value;
                if (data == null) {
                  return _emptyState();
                }

                final projectsMap = Map<String, dynamic>.from(data as Map);
                final projects = projectsMap.entries.toList()
                  ..sort((a, b) {
                    final aTime = (a.value as Map)['createdAt'] ?? '';
                    final bTime = (b.value as Map)['createdAt'] ?? '';
                    return bTime.toString().compareTo(aTime.toString());
                  });

                if (projects.isEmpty) {
                  return _emptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = Map<String, dynamic>.from(projects[index].value as Map);
                    return _projectCard(project, isVerified, user?.creditBalance ?? 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No projects available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new renovation projects',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(Map<String, dynamic> project, bool isVerified, int creditBalance) {
    final category = project['category'] as String? ?? 'other';
    final categoryName = project['categoryName'] as String? ?? 'Other';
    final budgetLabel = project['budgetLabel'] as String? ?? 'N/A';
    final city = project['city'] as String? ?? 'N/A';
    final projectTitle = project['projectTitle'] as String? ?? '';
    final propertyType = project['propertyType'] as String? ?? '';
    final preferredStartDate = project['preferredStartDate'] as String? ?? '';
    final creditCost = project['creditCost'] as int? ?? 0;
    final projectId = project['id'] as String? ?? '';
    final icon = _categoryIcons[category] ?? Icons.build;
    final isUnlocked = _unlockedIds.contains(projectId);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isUnlocked ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Title
            if (projectTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  projectTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Header Row: Category Icon + Name + Budget
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFFF97316), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        budgetLabel,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFF97316), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Text(
                      'Unlocked',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Text(
                      '$creditCost Credits',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF97316)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Tags: Property Type
            if (propertyType.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _propertyTypeLabels[propertyType] ?? propertyType,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                  ),
                ),
              ),

            // City & Start Date (public info only)
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(city, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                if (preferredStartDate.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _startDateLabels[preferredStartDate] ?? preferredStartDate,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),

            // Lock notice for locked projects
            if (!isUnlocked)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unlock to view full description, address, and contact details.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isUnlocked
                  ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/project-detail', arguments: {'projectId': projectId});
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: (isVerified && !_unlocking)
                          ? () => _handleUnlock(project)
                          : null,
                      icon: Icon(isVerified ? Icons.lock_open : Icons.lock, size: 18),
                      label: Text(
                        isVerified ? 'Unlock for $creditCost Credits' : 'Verification Required',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
