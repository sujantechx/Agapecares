import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/utils/validators.dart';

import '../../../../core/widgets/common_button.dart';


class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _inputCtrl = TextEditingController();
  bool _isLoading = false;

  String _friendlyErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account exists with this email.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection and try again.';
        default:
          return error.message ?? 'Failed to send reset email. Please try again.';
      }
    }
    return error.toString();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String input) {
    return input.contains('@');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _inputCtrl.text.trim();
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyErrorMessage(e)), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${_friendlyErrorMessage(e)}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _inputValidator(String? v) {
    if (v == null || v.isEmpty) return 'Enter email';
    return Validators.validateEmail(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Enter your registered email. A reset link will be sent to this email.', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _inputCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: _inputValidator,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      CommonButton(onPressed: _submit, text: 'Continue', isLoading: _isLoading),
                      const SizedBox(height: 12),
                      // Social buttons left as placeholders if you plan to support them later.
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
