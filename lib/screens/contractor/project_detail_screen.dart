import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/project_service.dart';
import 'package:renobasic/services/message_service.dart';

class ContractorProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ContractorProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ContractorProjectDetailScreen> createState() => _ContractorProjectDetailScreenState();
}

class _ContractorProjectDetailScreenState extends State<ContractorProjectDetailScreen> {
  Map<String, dynamic>? _project;
  Map<String, dynamic>? _privateDetails;
  bool _loading = true;

  static const Color _orange = Color(0xFFF97316);

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

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    try {
      final snap = await _db().child('projects/${widget.projectId}').get();
      if (snap.exists && snap.value != null) {
        setState(() {
          _project = Map<String, dynamic>.from(snap.value as Map);
        });
        final details = await ProjectService.getProjectPrivateDetails(widget.projectId);
        setState(() => _privateDetails = details);
      }
    } catch (e) {
      debugPrint('Error loading project: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _startConversation() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userProfile;
    if (user == null || _project == null || _privateDetails == null) return;

    try {
      final convId = await MessageService.getOrCreateConversation(
        contractorUid: user.uid,
        projectId: widget.projectId,
        homeownerUid: _project!['homeownerUid'] ?? '',
        homeownerName: _privateDetails!['homeownerName'] ?? '',
        contractorName: user.fullName,
        projectCategory: _project!['categoryName'] ?? '',
      );
      if (mounted) {
        Navigator.pushNamed(context, '/chat', arguments: {
          'conversationId': convId,
          'otherName': _privateDetails!['homeownerName'] ?? 'Homeowner',
          'projectCategory': _project!['categoryName'] ?? '',
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to start conversation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Project Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _project == null
              ? const Center(child: Text('Project not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project Title
                      if ((_project!['projectTitle'] as String?)?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _project!['projectTitle'],
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),

                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tag(_project!['categoryName'] ?? '', _orange),
                          _tag(_project!['budgetLabel'] ?? '', Colors.blue),
                          if ((_project!['propertyType'] as String?)?.isNotEmpty ?? false)
                            _tag(
                              _propertyTypeLabels[_project!['propertyType']] ?? _project!['propertyType'],
                              Colors.purple,
                            ),
                          _tag(_project!['status'] == 'open' ? 'Open' : _project!['status'] ?? '', Colors.green),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Meta info
                      _infoRow(Icons.location_on, _project!['city'] ?? ''),
                      if ((_project!['preferredStartDate'] as String?)?.isNotEmpty ?? false)
                        _infoRow(
                          Icons.calendar_today,
                          'Start: ${_startDateLabels[_project!['preferredStartDate']] ?? _project!['preferredStartDate']}',
                        ),
                      _infoRow(Icons.monetization_on, '${_project!['creditCost'] ?? 0} credits', color: _orange),
                      const SizedBox(height: 20),

                      // Private Details
                      if (_privateDetails != null) ...[
                        // Full Description
                        _sectionCard(
                          icon: Icons.description,
                          title: 'Full Description',
                          child: Text(
                            _privateDetails!['fullDescription'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Scope of Work
                        if (_privateDetails!['scopeOfWork'] != null &&
                            (_privateDetails!['scopeOfWork'] as List).isNotEmpty)
                          ...[
                            _sectionCard(
                              icon: Icons.checklist,
                              title: 'Scope of Work',
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (_privateDetails!['scopeOfWork'] as List)
                                    .map<Widget>((item) => Chip(
                                          label: Text(item.toString(), style: const TextStyle(fontSize: 13)),
                                          backgroundColor: _orange.withAlpha(25),
                                          side: BorderSide(color: _orange.withAlpha(75)),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                        // Location Details
                        _sectionCard(
                          icon: Icons.home,
                          title: 'Location Details',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((_privateDetails!['streetAddress'] as String?)?.isNotEmpty ?? false)
                                _infoRow(
                                  Icons.location_on,
                                  '${_privateDetails!['streetAddress']}'
                                  '${(_privateDetails!['unit'] as String?)?.isNotEmpty == true ? ', Unit ${_privateDetails!['unit']}' : ''}',
                                ),
                              _infoRow(
                                Icons.location_city,
                                '${_project!['city'] ?? ''}'
                                '${(_privateDetails!['province'] as String?)?.isNotEmpty == true ? ', ${_privateDetails!['province']}' : ''}'
                                '${(_privateDetails!['postalCode'] as String?)?.isNotEmpty == true ? ' ${_privateDetails!['postalCode']}' : ''}',
                              ),
                              if ((_privateDetails!['parkingAvailable'] as String?)?.isNotEmpty ?? false)
                                _infoRow(Icons.local_parking, 'Parking: ${_privateDetails!['parkingAvailable']}'),
                              if ((_privateDetails!['buildingRestrictions'] as String?)?.isNotEmpty ?? false)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.warning_amber, size: 18, color: Colors.amber.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Building Restrictions: ${_privateDetails!['buildingRestrictions']}',
                                          style: TextStyle(fontSize: 13, color: Colors.amber.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Project Specifications
                        _sectionCard(
                          icon: Icons.verified,
                          title: 'Project Specifications',
                          child: Column(
                            children: [
                              if ((_privateDetails!['hasDrawings'] as String?)?.isNotEmpty ?? false)
                                _specRow('Drawings / Plans', _privateDetails!['hasDrawings']),
                              if ((_privateDetails!['hasPermits'] as String?)?.isNotEmpty ?? false)
                                _specRow('Permits Obtained', (_privateDetails!['hasPermits'] as String).replaceAll('_', ' ')),
                              if ((_privateDetails!['materialsProvider'] as String?)?.isNotEmpty ?? false)
                                _specRow('Materials Provider', _privateDetails!['materialsProvider']),
                              if ((_privateDetails!['deadline'] as String?)?.isNotEmpty ?? false)
                                _specRow('Hard Deadline', _privateDetails!['deadline']),
                              if ((_privateDetails!['contactPreference'] as String?)?.isNotEmpty ?? false)
                                _specRow('Preferred Contact', (_privateDetails!['contactPreference'] as String).replaceAll('_', ' ')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Homeowner Contact
                        _sectionCard(
                          icon: Icons.person,
                          title: 'Homeowner Contact',
                          child: Column(
                            children: [
                              _infoRow(Icons.person, _privateDetails!['homeownerName'] ?? ''),
                              _infoRow(Icons.email, _privateDetails!['homeownerEmail'] ?? ''),
                              _infoRow(Icons.phone, _privateDetails!['homeownerPhone'] ?? ''),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Actions
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _startConversation,
                            icon: const Icon(Icons.chat),
                            label: const Text('Message Homeowner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/submit-bid', arguments: {
                                'projectId': widget.projectId,
                                'project': _project,
                                'privateDetails': _privateDetails,
                              });
                            },
                            icon: const Icon(Icons.description),
                            label: const Text('Submit a Bid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _orange,
                              side: const BorderSide(color: _orange),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Text(
                            'You need to unlock this project to see full details.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.amber),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: color ?? Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value[0].toUpperCase() + value.substring(1),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
            children: [
              Icon(icon, size: 20, color: _orange),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
