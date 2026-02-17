import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:renobasic/providers/auth_provider.dart';
import 'package:renobasic/services/validation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) {
        final user = context.read<AuthProvider>().userProfile;
        if (user != null) {
          if (user.isHomeowner) {
            Navigator.pushReplacementNamed(context, '/homeowner-dashboard');
          } else if (user.isContractor) {
            Navigator.pushReplacementNamed(context, '/contractor-dashboard');
          }
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(text: 'Reno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
              TextSpan(text: 'Basics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFF97316))),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Center(
        child: SingleChildScrollView(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Welcome Back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Sign in to your account', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration('Email Address'),
                      keyboardType: TextInputType.emailAddress,
                      validator: ValidationService.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: _inputDecoration('Password'),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/reset-password'),
                        child: const Text('Forgot password?', style: TextStyle(color: Color(0xFFF97316))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register-homeowner'),
                          child: const Text('Sign up', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
