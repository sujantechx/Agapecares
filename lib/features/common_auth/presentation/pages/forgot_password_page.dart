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
    final value = _inputCtrl.text.trim();
    setState(() => _isLoading = true);

    try {
      if (_looksLikeEmail(value)) {
        // Email reset
        await FirebaseAuth.instance.sendPasswordResetEmail(email: value);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
      } else {
        // Phone reset: start phone verification and navigate to OTP page
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: value,
          verificationCompleted: (credential) async {
            // Auto-signed in; navigate to new password page
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            context.push(AppRoutes.setNewPassword);
          },
          verificationFailed: (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone verification failed: ${e.message}')));
          },
          codeSent: (verificationId, resendToken) {
            if (!mounted) return;
            context.push(AppRoutes.phoneResetOtp, extra: {'verificationId': verificationId, 'phone': value});
          },
          codeAutoRetrievalTimeout: (verificationId) {},
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _inputValidator(String? v) {
    if (v == null || v.isEmpty) return 'Enter email or phone';
    if (_looksLikeEmail(v)) return Validators.validateEmail(v);
    return Validators.validatePhoneNumber(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter your registered email or phone number.\nIf you enter email you will receive a reset link. If you enter phone you will receive an OTP.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _inputCtrl,
                decoration: const InputDecoration(labelText: 'Email or Phone (include country code)'),
                validator: _inputValidator,
              ),
              const SizedBox(height: 16),
              CommonButton(onPressed: _submit, text: 'Continue', isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }
}
