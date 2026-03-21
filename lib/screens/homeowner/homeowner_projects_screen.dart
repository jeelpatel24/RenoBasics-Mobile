import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/utils/app_toast.dart';

class HomeownerProjectsScreen extends StatefulWidget {
  const HomeownerProjectsScreen({super.key});

  @override
  State<HomeownerProjectsScreen> createState() => _HomeownerProjectsScreenState();
}

class _HomeownerProjectsScreenState extends State<HomeownerProjectsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filter = 'all'; // all | open | in_progress | completed | closed

  static const Map<String, String> _statusLabels = {
    'open': 'Open',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'closed': 'Closed',
  };

  static const Map<String, Color> _statusColors = {
    'open': Colors.green,
    'in_progress': Colors.blue,
    'completed': Colors.purple,
    'closed': Colors.grey,
  };

  Future<void> _updateStatus(String projectId, String newStatus) async {
    try {
      await _firestore.collection('projects').doc(projectId).update({
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) AppToast.show(context, 'Project status updated to ${_statusLabels[newStatus]}');
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to update project status', isError: true);
    }
  }

  void _showStatusMenu(BuildContext ctx, String projectId, String currentStatus) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Project Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statusLabels.entries.map((e) {
              final isSelected = e.key == currentStatus;
              return ListTile(
                dense: true,
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColors[e.key] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(e.value),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFF97316)) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isSelected) _updateStatus(projectId, e.key);
                },
              );
            }),
          ],
        ),
      ),
    );
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
    final uid = context.read<AuthProvider>().userProfile?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Projects'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFFF97316),
            tooltip: 'Post New Project',
            onPressed: () => Navigator.pushNamed(context, '/post-project'),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : Column(
              children: [
                // Filter tabs
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'open', 'in_progress', 'completed', 'closed']
                          .map((f) {
                            final label = f == 'all'
                                ? 'All'
                                : f == 'in_progress'
                                    ? 'In Progress'
                                    : f[0].toUpperCase() + f.substring(1);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _filter = f),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _filter == f
                                        ? const Color(0xFFF97316)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _filter == f
                                          ? const Color(0xFFF97316)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _filter == f
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('projects')
                        .where('homeownerUid', isEqualTo: uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
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
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      final docs = _filter == 'all'
                          ? allDocs
                          : allDocs.where((d) {
                              final s = (d.data() as Map<String, dynamic>)['status'] as String? ?? 'open';
                              return s == _filter;
                            }).toList();

                if (allDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No projects yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Post your first renovation project to start receiving bids from contractors.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/post-project'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Post a Project'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No $_filter projects',
                            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => setState(() => _filter = 'all'),
                          child: const Text('Show all projects',
                              style: TextStyle(color: Color(0xFFF97316))),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final projectId = docs[index].id;
                    final status = data['status'] as String? ?? 'open';
                    final categoryName = data['categoryName'] as String? ?? 'Project';
                    final projectTitle = data['projectTitle'] as String? ?? '';
                    final budgetLabel = data['budgetLabel'] as String? ?? '';
                    final city = data['city'] as String? ?? '';
                    final createdAt = data['createdAt'];
                    final creditCost = data['creditCost'] as int? ?? 0;
                    final statusColor = _statusColors[status] ?? Colors.grey;
                    final statusLabel = _statusLabels[status] ?? status;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/homeowner-project-detail',
                        arguments: {'projectId': projectId},
                      ),
                      child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row: title + status badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (projectTitle.isNotEmpty)
                                      Text(
                                        projectTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    Text(
                                      categoryName,
                                      style: TextStyle(
                                        color: projectTitle.isNotEmpty
                                            ? Colors.grey[600]
                                            : Colors.black87,
                                        fontWeight: projectTitle.isNotEmpty
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                        fontSize: projectTitle.isNotEmpty ? 13 : 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showStatusMenu(context, projectId, status),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor.withAlpha(100)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.expand_more, size: 14, color: statusColor),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Meta info row
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              if (budgetLabel.isNotEmpty)
                                _metaChip(Icons.attach_money, budgetLabel, Colors.green),
                              if (city.isNotEmpty)
                                _metaChip(Icons.location_on, city, Colors.red),
                              _metaChip(
                                Icons.token,
                                '$creditCost credits to unlock',
                                const Color(0xFFF97316),
                              ),
                              if (createdAt != null)
                                _metaChip(
                                  Icons.access_time,
                                  _timeAgo(createdAt),
                                  Colors.grey,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/post-project'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post Project'),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
