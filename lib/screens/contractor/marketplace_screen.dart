import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:renobasic/utils/app_toast.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/notification_service.dart';
import 'package:renobasic/services/project_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<String> _unlockedIds = [];
  bool _unlocking = false;
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'newest'; // newest | credits_low | credits_high
  final _searchController = TextEditingController();

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> projects) {
    var list = projects;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final title = (p['projectTitle'] as String? ?? '').toLowerCase();
        final catName = (p['categoryName'] as String? ?? '').toLowerCase();
        final cityVal = (p['city'] as String? ?? '').toLowerCase();
        return title.contains(q) || catName.contains(q) || cityVal.contains(q);
      }).toList();
    }
    if (_selectedCategory != null) {
      list = list.where((p) => (p['category'] as String?) == _selectedCategory).toList();
    }
    if (_sortBy == 'credits_low') {
      list.sort((a, b) => ((a['creditCost'] as num?)?.toInt() ?? 0).compareTo((b['creditCost'] as num?)?.toInt() ?? 0));
    } else if (_sortBy == 'credits_high') {
      list.sort((a, b) => ((b['creditCost'] as num?)?.toInt() ?? 0).compareTo((a['creditCost'] as num?)?.toInt() ?? 0));
    }
    // 'newest' keeps Firestore order (descending createdAt from stream)
    return list;
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

    final creditCost = (project['creditCost'] as num?)?.toInt() ?? 0;
    final creditBalance = user.creditBalance;
    final projectId = project['id'] as String? ?? '';

    if (!user.isVerified) {
      AppToast.show(context, 'Your account must be verified to unlock projects.', isError: true);
      return;
    }
    if (creditBalance < creditCost) {
      AppToast.show(context, 'Not enough credits. Please buy more credits.', isError: true);
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
      // Notify homeowner their project was unlocked (non-fatal)
      final homeownerUid = project['homeownerUid'] as String? ?? '';
      if (homeownerUid.isNotEmpty) {
        await NotificationService.createNotification(
          recipientUid: homeownerUid,
          type: 'project_unlocked',
          title: 'Your Project Was Viewed',
          message:
              '${user.fullName} unlocked your ${project['categoryName'] ?? 'project'} and can now view the full details.',
          relatedId: projectId,
        );
      }
      if (mounted) AppToast.show(context, 'Project unlocked! You can now view full details.');
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to unlock project.', isError: true);
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

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, category, city…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                // Category dropdown
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                      ..._categoryIcons.keys.map((k) => DropdownMenuItem<String?>(
                            value: k,
                            child: Text(
                              k[0].toUpperCase() + k.substring(1).replaceAll('_', ' '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                ),
                const SizedBox(width: 10),
                // Sort dropdown
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('Newest')),
                        DropdownMenuItem(value: 'credits_low', child: Text('Low Credits')),
                        DropdownMenuItem(value: 'credits_high', child: Text('High Credits')),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Projects List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ProjectService.subscribeToProjects(),
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _emptyState();
                }

                final rawProjects = snapshot.data!.docs.map((doc) {
                  final p = doc.data() as Map<String, dynamic>;
                  p['id'] = doc.id;
                  return p;
                }).toList();

                final projects = _applyFilters(rawProjects);

                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No projects match your filters',
                            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedCategory = null;
                              _sortBy = 'newest';
                            });
                          },
                          child: const Text('Clear filters', style: TextStyle(color: Color(0xFFF97316))),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      return _projectCard(projects[index], isVerified, user?.creditBalance ?? 0);
                    },
                  ),
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
    final creditCost = (project['creditCost'] as num?)?.toInt() ?? 0;
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
