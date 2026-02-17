import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/validation_service.dart';

class HomeownerRegisterScreen extends StatefulWidget {
  const HomeownerRegisterScreen({super.key});

  @override
  State<HomeownerRegisterScreen> createState() => _HomeownerRegisterScreenState();
}

class _HomeownerRegisterScreenState extends State<HomeownerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().registerHomeowner(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
          );
      Fluttertoast.showToast(msg: 'Account created! Check email for verification.');
      if (mounted) Navigator.pushReplacementNamed(context, '/homeowner-dashboard');
    } catch (e) {
      final msg = e.toString().contains('email-already-in-use')
          ? 'An account with this email already exists'
          : 'Registration failed. Please try again.';
      Fluttertoast.showToast(msg: msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Homeowner Registration'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Your Free Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Post renovation projects for free', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(controller: _fullName, decoration: _dec('Full Name'), validator: (v) => ValidationService.validateRequired(v, 'Full name')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _email, decoration: _dec('Email Address'), keyboardType: TextInputType.emailAddress, validator: ValidationService.validateEmail),
                  const SizedBox(height: 16),
                  TextFormField(controller: _phone, decoration: _dec('Phone Number'), keyboardType: TextInputType.phone, validator: ValidationService.validatePhone),
                  const SizedBox(height: 16),
                  TextFormField(controller: _password, decoration: _dec('Password'), obscureText: true, validator: ValidationService.validatePassword),
                  const SizedBox(height: 16),
                  TextFormField(controller: _confirmPassword, decoration: _dec('Confirm Password'), obscureText: true, validator: (v) => ValidationService.validateConfirmPassword(v, _password.text)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Homeowner Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ', style: TextStyle(color: Colors.grey[600])),
                      GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('Sign in', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/register-contractor'),
                      child: const Text('Register as Contractor', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                    ),
                  ),
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
