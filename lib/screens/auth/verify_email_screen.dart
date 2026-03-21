import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:renobasic/providers/auth_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _resending = false;
  bool _resent = false;
  bool _checking = false;
  String _error = '';

  String get _email =>
      FirebaseAuth.instance.currentUser?.email ?? 'your email address';

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _resending) return;
    setState(() { _resending = true; _error = ''; });
    try {
      await user.sendEmailVerification();
      setState(() => _resent = true);
    } catch (_) {
      setState(() => _error = 'Could not send email. Please wait and try again.');
    } finally {
      setState(() => _resending = false);
    }
  }

  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _checking) return;
    setState(() { _checking = true; _error = ''; });
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        if (!mounted) return;
        final authProvider = context.read<AuthProvider>();
        final profile = authProvider.userProfile;
        if (profile != null) {
          if (profile.isContractor) {
            Navigator.pushReplacementNamed(context, '/contractor-dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/homeowner-dashboard');
          }
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        setState(() => _error = 'Email not verified yet. Check your inbox and click the link.');
      }
    } catch (_) {
      setState(() => _error = 'Could not check status. Please try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Reno',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87),
              ),
              TextSpan(
                text: 'Basics',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFFF97316)),
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
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
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        size: 36, color: Color(0xFFF97316)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to:',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Click the link in your email to verify your account, then tap the button below.',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (_resent) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Verification email sent!',
                            style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _checkVerified,
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_checking ? 'Checking...' : "I've Verified — Continue"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: (_resending || _resent) ? null : _resendEmail,
                      icon: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFF97316)),
                            )
                          : const Icon(Icons.refresh, color: Color(0xFFF97316)),
                      label: Text(
                        _resent ? 'Email Sent!' : _resending ? 'Sending...' : 'Resend Email',
                        style: const TextStyle(color: Color(0xFFF97316)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF97316)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _logout,
                    child: Text(
                      'Log out and use a different account',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
}
