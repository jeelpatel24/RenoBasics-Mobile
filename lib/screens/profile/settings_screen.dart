import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:renobasic/providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _companyName = TextEditingController();
  final _businessNumber = TextEditingController();
  final _obrNumber = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().userProfile;
    if (user != null) {
      _fullName.text = user.fullName;
      _email.text = user.email;
      _phone.text = user.phone;
      if (user.isContractor) {
        _companyName.text = user.companyName ?? '';
        _businessNumber.text = user.businessNumber ?? '';
        _obrNumber.text = user.obrNumber ?? '';
      }
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _companyName.dispose();
    _businessNumber.dispose();
    _obrNumber.dispose();
    super.dispose();
  }

  DatabaseReference _dbRef() {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://renobasics-d33a1-default-rtdb.firebaseio.com',
    ).ref();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().userProfile;
      if (user == null) throw Exception('User not found');

      final updates = <String, dynamic>{
        'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _dbRef().child('users/${user.uid}').update(updates);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();

      Fluttertoast.showToast(msg: 'Profile updated successfully!');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update profile. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userProfile;
    final isContractor = user?.isContractor ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Info Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Role Badge
                    Row(
                      children: [
                        Text('Role:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (user?.role ?? 'homeowner').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Email
                    Row(
                      children: [
                        Text('Email:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Member Since
                    Row(
                      children: [
                        Text('Member since:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(user?.createdAt ?? ''),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    // Verification Status (Contractors only)
                    if (isContractor) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Verification:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          const SizedBox(width: 8),
                          _verificationBadge(user?.verificationStatus ?? 'pending'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Edit Profile Form
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      TextFormField(
                        controller: _fullName,
                        decoration: _dec('Full Name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email (read-only)
                      TextFormField(
                        controller: _email,
                        decoration: _dec('Email').copyWith(
                          suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                        ),
                        readOnly: true,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phone,
                        decoration: _dec('Phone Number'),
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
                      ),

                      // Contractor-only fields
                      if (isContractor) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _companyName,
                          decoration: _dec('Company Name').copyWith(
                            suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                          ),
                          readOnly: true,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _businessNumber,
                          decoration: _dec('Business Number').copyWith(
                            suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                          ),
                          readOnly: true,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _obrNumber,
                          decoration: _dec('OBR Number').copyWith(
                            suffixIcon: const Icon(Icons.lock, size: 18, color: Colors.grey),
                          ),
                          readOnly: true,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Update Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Update Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verificationBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'approved':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        label = 'Verified';
        break;
      case 'rejected':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = 'Rejected';
        break;
      default:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(isoDate);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
