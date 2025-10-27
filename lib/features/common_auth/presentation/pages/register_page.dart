// lib/features/common_auth/presentation/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_button.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+91');
  bool _isLoading = false;
  UserRole _role = UserRole.user;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _registerWithEmail() {
    if (!_formKey.currentState!.validate()) return;
    String phone = _phoneCtrl.text.trim();
    if (!phone.startsWith('+')) {
      phone = '+91$phone';
    }
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(AuthRegisterRequested(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      phone: phone,
      role: _role,
    ));
  }

  void _registerAndVerifyPhone() {
    if (!_formKey.currentState!.validate()) return;
    String phone = _phoneCtrl.text.trim();
    if (!phone.startsWith('+')) phone = '+91$phone';
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(AuthSendOtpRequested(phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            if (mounted) setState(() => _isLoading = true);
            return;
          } else {
            if (mounted) setState(() => _isLoading = false);
          }

          if (state is AuthFailure) {
            final msg = state.message.isNotEmpty ? state.message : 'Registration failed.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
            return;
          }

          // This is the success state for Email Registration
          if (state is AuthEmailVerificationSent) {
            if (mounted) {
              // Pop back to login, passing 'true' so login page can show snackbar
              context.pop(true);
            }
            return;
          }

          if (state is AuthOtpSent) {
            // This is for the *phone* registration flow
            GoRouter.of(context).push(AppRoutes.phoneVerify, extra: {
              'verificationId': state.verificationId,
              'phone': _phoneCtrl.text.trim(),
              'name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'password': _passwordCtrl.text.trim(),
              'role': _role,
            });
          }
        },
        child: Center(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(label: const Text('User'), selected: _role == UserRole.user, onSelected: (s) => setState(() => _role = UserRole.user)),
                            const SizedBox(width: 8),
                            ChoiceChip(label: const Text('Worker'), selected: _role == UserRole.worker, onSelected: (s) => setState(() => _role = UserRole.worker)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                          ),
                          obscureText: true,
                          validator: (v) => (v == null || v.length < 6) ? 'Enter min 6 chars' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: const Icon(Icons.phone),
                            hintText: '+91 9876543210',
                            filled: true,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => Validators.validatePhoneNumber(v?.trim() ?? ''),
                        ),
                        const SizedBox(height: 20),
                        CommonButton(onPressed: _registerWithEmail, text: 'Register (Email Verify)', isLoading: _isLoading),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: _isLoading ? null : _registerAndVerifyPhone, child: const Text('Register & Verify Phone (OTP)'), ),
                        const SizedBox(height: 12),
                        if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) ...[
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : () {
                              context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
                            },
                            icon: const Icon(Icons.g_mobiledata),
                            label: Text(_isLoading ? 'Processing...' : 'Continue with Google'),
                          ),
                        ],
                      ],
                    ),
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