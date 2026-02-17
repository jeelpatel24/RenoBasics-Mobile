import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:renobasic/providers/auth_provider.dart';

class PostProjectScreen extends StatefulWidget {
  const PostProjectScreen({super.key});

  @override
  State<PostProjectScreen> createState() => _PostProjectScreenState();
}

class _PostProjectScreenState extends State<PostProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // ── Section 1: Basic Project Information ──
  final _projectTitle = TextEditingController();
  String? _selectedCategory;
  String? _selectedPropertyType;
  String _ownershipStatus = 'own';

  // ── Section 2: Location Details ──
  final _streetAddress = TextEditingController();
  final _unit = TextEditingController();
  final _city = TextEditingController();
  String? _selectedProvince;
  final _postalCode = TextEditingController();
  String _parkingAvailable = 'yes';
  final _buildingRestrictions = TextEditingController();

  // ── Section 3: Project Details ──
  final _description = TextEditingController();
  final List<String> _selectedScopes = [];
  String _hasDrawings = 'no';
  String _hasPermits = 'not_sure';
  String _materialsProvider = 'either';

  // ── Section 4: Budget & Timeline ──
  String? _selectedBudget;
  String? _selectedStartDate;
  final _deadline = TextEditingController();

  // ── Section 5: Communication Preferences ──
  String _contactPreference = 'in_app';

  // ── Static Data Maps ──

  static const Map<String, String> _categories = {
    'kitchen': 'Kitchen Renovation',
    'bathroom': 'Bathroom Renovation',
    'basement': 'Basement Finishing',
    'roofing': 'Roofing',
    'flooring': 'Flooring',
    'painting': 'Painting',
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
    'landscaping': 'Landscaping',
    'general': 'General Renovation',
    'addition': 'Home Addition',
    'deck_patio': 'Deck / Patio',
    'windows_doors': 'Windows & Doors',
    'hvac': 'HVAC',
    'home_extension': 'Home Extension',
    'adu': 'ADU (Accessory Dwelling Unit)',
    'garage_conversion': 'Garage Conversion',
    'full_renovation': 'Full House Renovation',
    'commercial': 'Commercial Renovation',
    'other': 'Other',
  };

  static const Map<String, String> _budgetRanges = {
    'under_5000': 'Under \$5,000',
    '5000_15000': '\$5,000 \u2013 \$15,000',
    '15000_30000': '\$15,000 \u2013 \$30,000',
    '30000_50000': '\$30,000 \u2013 \$50,000',
    '50000_100000': '\$50,000 \u2013 \$100,000',
    '100000_250000': '\$100,000 \u2013 \$250,000',
    'over_250000': 'Over \$250,000',
  };

  static const Map<String, int> _creditCosts = {
    'under_5000': 2,
    '5000_15000': 3,
    '15000_30000': 5,
    '30000_50000': 7,
    '50000_100000': 10,
    '100000_250000': 15,
    'over_250000': 20,
  };

  static const Map<String, String> _startDates = {
    'immediately': 'Immediately',
    'within_2_weeks': 'Within 2 Weeks',
    'within_month': 'Within a Month',
    'within_3_months': 'Within 3 Months',
    'flexible': 'Flexible',
  };

  static const Map<String, String> _propertyTypes = {
    'house': 'House',
    'condo': 'Condo / Apartment',
    'townhouse': 'Townhouse',
    'commercial': 'Commercial',
    'other': 'Other',
  };

  static const List<String> _scopeOptions = [
    'Demolition',
    'Framing',
    'Drywall',
    'Electrical',
    'Plumbing',
    'Painting',
    'Flooring',
    'Fixture Installation',
    'Cleanup / Disposal',
  ];

  static const List<String> _provinces = [
    'Alberta',
    'British Columbia',
    'Manitoba',
    'New Brunswick',
    'Newfoundland and Labrador',
    'Northwest Territories',
    'Nova Scotia',
    'Nunavut',
    'Ontario',
    'Prince Edward Island',
    'Quebec',
    'Saskatchewan',
    'Yukon',
  ];

  static const Color _orange = Color(0xFFF97316);

  @override
  void dispose() {
    _projectTitle.dispose();
    _streetAddress.dispose();
    _unit.dispose();
    _city.dispose();
    _postalCode.dispose();
    _buildingRestrictions.dispose();
    _description.dispose();
    _deadline.dispose();
    super.dispose();
  }

  DatabaseReference _dbRef() {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
    ).ref();
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().userProfile;
      if (user == null) throw Exception('User not found');

      final projectRef = _dbRef().child('projects').push();
      final now = DateTime.now().toIso8601String();

      final publicData = <String, dynamic>{
        'id': projectRef.key,
        'homeownerUid': user.uid,
        'projectTitle': _projectTitle.text.trim(),
        'category': _selectedCategory,
        'categoryName': _categories[_selectedCategory],
        'propertyType': _selectedPropertyType,
        'ownershipStatus': _ownershipStatus,
        'budgetRange': _selectedBudget,
        'budgetLabel': _budgetRanges[_selectedBudget],
        'creditCost': _creditCosts[_selectedBudget],
        'preferredStartDate': _selectedStartDate,
        'city': _city.text.trim(),
        'status': 'open',
        'createdAt': now,
        'updatedAt': now,
      };

      final privateData = <String, dynamic>{
        'homeownerName': user.fullName,
        'homeownerEmail': user.email,
        'homeownerPhone': user.phone,
        'fullDescription': _description.text.trim(),
        'streetAddress': _streetAddress.text.trim(),
        'unit': _unit.text.trim(),
        'province': _selectedProvince ?? '',
        'postalCode': _postalCode.text.trim(),
        'scopeOfWork': _selectedScopes,
        'hasDrawings': _hasDrawings,
        'hasPermits': _hasPermits,
        'materialsProvider': _materialsProvider,
        'deadline': _deadline.text.trim(),
        'contactPreference': _contactPreference,
        'parkingAvailable': _parkingAvailable,
        'buildingRestrictions': _buildingRestrictions.text.trim(),
        'photos': <String>[],
      };

      publicData['privateDetails'] = privateData;
      await projectRef.set(publicData);

      Fluttertoast.showToast(msg: 'Project posted successfully!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to post project. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Post a Project'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection1BasicInfo(),
              const SizedBox(height: 16),
              _buildSection2Location(),
              const SizedBox(height: 16),
              _buildSection3ProjectDetails(),
              const SizedBox(height: 16),
              _buildSection4BudgetTimeline(),
              const SizedBox(height: 16),
              _buildSection5Communication(),
              const SizedBox(height: 16),
              _buildSection6FileUploads(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // SECTION 1 — Basic Project Information
  // ════════════════════════════════════════════════

  Widget _buildSection1BasicInfo() {
    return _sectionCard(
      icon: Icons.assignment_outlined,
      title: 'Basic Project Information',
      children: [
        // Project Title
        TextFormField(
          controller: _projectTitle,
          decoration: _dec('Project Title'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a project title' : null,
        ),
        const SizedBox(height: 16),

        // Project Type (Category)
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: _dec('Project Type'),
          isExpanded: true,
          items: _categories.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
          validator: (v) => v == null ? 'Please select a project type' : null,
        ),
        const SizedBox(height: 16),

        // Property Type
        DropdownButtonFormField<String>(
          initialValue: _selectedPropertyType,
          decoration: _dec('Property Type'),
          isExpanded: true,
          items: _propertyTypes.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _selectedPropertyType = v),
          validator: (v) => v == null ? 'Please select a property type' : null,
        ),
        const SizedBox(height: 16),

        // Ownership Status
        _fieldLabel('Ownership Status'),
        const SizedBox(height: 4),
        _radioTile<String>(
          value: 'own',
          groupValue: _ownershipStatus,
          label: 'I own this property',
          onChanged: (v) => setState(() => _ownershipStatus = v!),
        ),
        _radioTile<String>(
          value: 'renting',
          groupValue: _ownershipStatus,
          label: "I'm renting",
          onChanged: (v) => setState(() => _ownershipStatus = v!),
        ),
        _radioTile<String>(
          value: 'property_manager',
          groupValue: _ownershipStatus,
          label: "I'm a property manager",
          onChanged: (v) => setState(() => _ownershipStatus = v!),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════
  // SECTION 2 — Location Details
  // ════════════════════════════════════════════════

  Widget _buildSection2Location() {
    return _sectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location Details',
      children: [
        // Street Address
        TextFormField(
          controller: _streetAddress,
          decoration: _dec('Street Address'),
        ),
        const SizedBox(height: 16),

        // Unit / Suite
        TextFormField(
          controller: _unit,
          decoration: _dec('Unit / Suite (optional)'),
        ),
        const SizedBox(height: 16),

        // City (PUBLIC)
        TextFormField(
          controller: _city,
          decoration: _dec('City').copyWith(
            helperText: 'This field is visible to contractors',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a city' : null,
        ),
        const SizedBox(height: 16),

        // Province
        DropdownButtonFormField<String>(
          initialValue: _selectedProvince,
          decoration: _dec('Province'),
          isExpanded: true,
          items: _provinces
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _selectedProvince = v),
        ),
        const SizedBox(height: 16),

        // Postal Code
        TextFormField(
          controller: _postalCode,
          decoration: _dec('Postal Code'),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),

        // Parking Available
        _fieldLabel('Parking Available?'),
        const SizedBox(height: 4),
        _radioTile<String>(
          value: 'yes',
          groupValue: _parkingAvailable,
          label: 'Yes',
          onChanged: (v) => setState(() => _parkingAvailable = v!),
        ),
        _radioTile<String>(
          value: 'no',
          groupValue: _parkingAvailable,
          label: 'No',
          onChanged: (v) => setState(() => _parkingAvailable = v!),
        ),
        _radioTile<String>(
          value: 'street_only',
          groupValue: _parkingAvailable,
          label: 'Street parking only',
          onChanged: (v) => setState(() => _parkingAvailable = v!),
        ),
        const SizedBox(height: 16),

        // Building Restrictions
        TextFormField(
          controller: _buildingRestrictions,
          decoration: _dec('Building Restrictions (optional)'),
          maxLines: 3,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════
  // SECTION 3 — Project Details
  // ════════════════════════════════════════════════

  Widget _buildSection3ProjectDetails() {
    return _sectionCard(
      icon: Icons.construction_outlined,
      title: 'Project Details',
      children: [
        // Description
        TextFormField(
          controller: _description,
          decoration: _dec('Description'),
          maxLines: 5,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter a description';
            if (v.trim().length < 20) return 'Description must be at least 20 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Scope of Work
        _fieldLabel('Scope of Work'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _scopeOptions.map((scope) {
            final selected = _selectedScopes.contains(scope);
            return FilterChip(
              label: Text(scope),
              selected: selected,
              selectedColor: _orange.withAlpha(51),
              checkmarkColor: _orange,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedScopes.add(scope);
                  } else {
                    _selectedScopes.remove(scope);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Do you have drawings/plans?
        _fieldLabel('Do you have drawings/plans?'),
        const SizedBox(height: 4),
        _radioTile<String>(
          value: 'yes',
          groupValue: _hasDrawings,
          label: 'Yes',
          onChanged: (v) => setState(() => _hasDrawings = v!),
        ),
        _radioTile<String>(
          value: 'no',
          groupValue: _hasDrawings,
          label: 'No',
          onChanged: (v) => setState(() => _hasDrawings = v!),
        ),
        _radioTile<String>(
          value: 'partial',
          groupValue: _hasDrawings,
          label: 'Partial',
          onChanged: (v) => setState(() => _hasDrawings = v!),
        ),
        const SizedBox(height: 16),

        // Have permits been obtained?
        _fieldLabel('Have permits been obtained?'),
        const SizedBox(height: 4),
        _radioTile<String>(
          value: 'yes',
          groupValue: _hasPermits,
          label: 'Yes',
          onChanged: (v) => setState(() => _hasPermits = v!),
        ),
        _radioTile<String>(
          value: 'no',
          groupValue: _hasPermits,
          label: 'No',
          onChanged: (v) => setState(() => _hasPermits = v!),
        ),
        _radioTile<String>(
          value: 'not_sure',
          groupValue: _hasPermits,
          label: 'Not Sure',
          onChanged: (v) => setState(() => _hasPermits = v!),
        ),
        const SizedBox(height: 16),

        // Who provides materials?
        _fieldLabel('Who provides materials?'),
        const SizedBox(height: 4),
        _radioTile<String>(
          value: 'homeowner',
          groupValue: _materialsProvider,
          label: 'I will provide',
          onChanged: (v) => setState(() => _materialsProvider = v!),
        ),
        _radioTile<String>(
          value: 'contractor',
          groupValue: _materialsProvider,
          label: 'Contractor provides',
          onChanged: (v) => setState(() => _materialsProvider = v!),
        ),
        _radioTile<String>(
          value: 'either',
          groupValue: _materialsProvider,
          label: 'Either',
          onChanged: (v) => setState(() => _materialsProvider = v!),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════
  // SECTION 4 — Budget & Timeline
  // ════════════════════════════════════════════════

  Widget _buildSection4BudgetTimeline() {
    return _sectionCard(
      icon: Icons.attach_money_outlined,
      title: 'Budget & Timeline',
      children: [
        // Estimated Budget
        DropdownButtonFormField<String>(
          initialValue: _selectedBudget,
          decoration: _dec('Estimated Budget'),
          isExpanded: true,
          items: _budgetRanges.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _selectedBudget = v),
          validator: (v) => v == null ? 'Please select a budget range' : null,
        ),
        const SizedBox(height: 16),

        // Preferred Start Date
        DropdownButtonFormField<String>(
          initialValue: _selectedStartDate,
          decoration: _dec('Preferred Start Date'),
          isExpanded: true,
          items: _startDates.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _selectedStartDate = v),
          validator: (v) => v == null ? 'Please select a start date preference' : null,
        ),
        const SizedBox(height: 16),

        // Hard Deadline
        TextFormField(
          controller: _deadline,
          decoration: _dec('Hard Deadline (optional)'),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════
  // SECTION 5 — Communication Preferences
  // ════════════════════════════════════════════════

  Widget _buildSection5Communication() {
    return _sectionCard(
      icon: Icons.chat_bubble_outline,
      title: 'Communication Preferences',
      children: [
        _fieldLabel('Preferred Contact Method'),
        const SizedBox(height: 4),
        _radioTile<String>(
          value: 'in_app',
          groupValue: _contactPreference,
          label: 'In-App Messaging',
          onChanged: (v) => setState(() => _contactPreference = v!),
        ),
        _radioTile<String>(
          value: 'email',
          groupValue: _contactPreference,
          label: 'Email',
          onChanged: (v) => setState(() => _contactPreference = v!),
        ),
        _radioTile<String>(
          value: 'phone',
          groupValue: _contactPreference,
          label: 'Phone',
          onChanged: (v) => setState(() => _contactPreference = v!),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════
  // SECTION 6 — File Uploads (Placeholder)
  // ════════════════════════════════════════════════

  Widget _buildSection6FileUploads() {
    return _sectionCard(
      icon: Icons.cloud_upload_outlined,
      title: 'File Uploads',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'File uploads coming in Iteration 2',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════
  // Submit Button
  // ════════════════════════════════════════════════

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _submitProject,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Post Project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // Shared Helpers
  // ════════════════════════════════════════════════

  /// Wraps children inside a styled Card with an orange section header.
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Standard InputDecoration used by all TextFormFields and Dropdowns.
  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  /// A small bold label above radio groups / chip groups.
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  /// Themed RadioListTile with dense layout and orange active colour.
  Widget _radioTile<T>({
    required T value,
    required T groupValue,
    required String label,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: _orange,
      visualDensity: VisualDensity.compact,
    );
  }
}
