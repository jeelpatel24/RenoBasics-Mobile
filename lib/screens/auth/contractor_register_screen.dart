import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/validation_service.dart';
import 'package:renobasic/utils/app_toast.dart';

class ContractorRegisterScreen extends StatefulWidget {
  const ContractorRegisterScreen({super.key});

  @override
  State<ContractorRegisterScreen> createState() => _ContractorRegisterScreenState();
}

class _ContractorRegisterScreenState extends State<ContractorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyName = TextEditingController();
  final _contactName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _bn = TextEditingController();
  final _obr = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _companyName.dispose();
    _contactName.dispose();
    _email.dispose();
    _phone.dispose();
    _bn.dispose();
    _obr.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().registerContractor(
            email: _email.text.trim(),
            password: _password.text,
            companyName: _companyName.text.trim(),
            contactName: _contactName.text.trim(),
            phone: _phone.text.trim(),
            businessNumber: _bn.text.trim(),
            obrNumber: _obr.text.trim(),
          );
      AppToast.show(context, 'Account created! Verification pending admin review.');
      if (mounted) Navigator.pushReplacementNamed(context, '/verify-email');
    } catch (e) {
      final msg = e.toString().contains('email-already-in-use')
          ? 'An account with this email already exists'
          : 'Registration failed. Please try again.';
      AppToast.show(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Contractor Registration'), backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0.5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Register Your Business', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Get verified to access renovation projects', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Your BN and OBR will be verified by admin before marketplace access.', style: TextStyle(fontSize: 13, color: Colors.amber.shade900))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(controller: _companyName, decoration: _dec('Company Name'), validator: (v) => ValidationService.validateRequired(v, 'Company name')),
                  const SizedBox(height: 14),
                  TextFormField(controller: _contactName, decoration: _dec('Contact Name'), validator: (v) => ValidationService.validateRequired(v, 'Contact name')),
                  const SizedBox(height: 14),
                  TextFormField(controller: _email, decoration: _dec('Email Address'), keyboardType: TextInputType.emailAddress, validator: ValidationService.validateEmail),
                  const SizedBox(height: 14),
                  TextFormField(controller: _phone, decoration: _dec('Phone Number'), keyboardType: TextInputType.phone, validator: ValidationService.validatePhone),
                  const SizedBox(height: 14),
                  TextFormField(controller: _bn, decoration: _dec('Business Number (BN)'), validator: ValidationService.validateBusinessNumber),
                  const SizedBox(height: 14),
                  TextFormField(controller: _obr, decoration: _dec('Ontario Business Registry (OBR)'), validator: ValidationService.validateOBR),
                  const SizedBox(height: 14),
                  TextFormField(controller: _password, decoration: _dec('Password'), obscureText: true, validator: ValidationService.validatePassword),
                  const SizedBox(height: 14),
                  TextFormField(controller: _confirmPassword, decoration: _dec('Confirm Password'), obscureText: true, validator: (v) => ValidationService.validateConfirmPassword(v, _password.text)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Contractor Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Already have an account? ', style: TextStyle(color: Colors.grey[600])),
                    GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('Sign in', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 8),
                  Center(child: GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, '/register-homeowner'), child: const Text('Register as Homeowner', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316), width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
}
