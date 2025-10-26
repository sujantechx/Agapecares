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
    // Normalize phone: if user entered without country code, prefix +91
    String phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return; // validator should have caught this
    if (!phone.startsWith('+')) {
      phone = '+91$phone';
    }
    // mark that this flow is an email registration so that on success we pop back to login
    setState(() => _isLoading = true);
    // dispatch registration event to AuthBloc which will handle Firebase and Firestore writes
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
    if (phone.isEmpty) return;
    if (!phone.startsWith('+')) phone = '+91$phone';
    setState(() => _isLoading = true);
    // Send OTP; when AuthOtpSent is emitted the listener will navigate to PhoneVerifyPage
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
            // Explicit server-friendly message and reset register flag so subsequent success flows behave correctly
            final msg = state.message.isNotEmpty ? state.message : 'Registration failed. Please try again.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
            return;
          }

          if (state is AuthEmailVerificationSent) {
            // Inform user to check their email for verification and route to login
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification email sent to ${state.email ?? _emailCtrl.text}. Please verify before logging in.'), backgroundColor: Colors.green));
              // Small delay then navigate to login
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!mounted) return;
                if (Navigator.of(context).canPop()) context.pop(true);
                else GoRouter.of(context).go(AppRoutes.login);
              });
            }
            return;
          }

          if (state is AuthOtpSent) {
            // When OTP is sent for a registration flow, navigate to OTP screen with arguments including name/email/password/role
            GoRouter.of(context).push(AppRoutes.phoneVerify, extra: {
              'verificationId': state.verificationId,
              'phone': _phoneCtrl.text.trim(),
              'name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'password': _passwordCtrl.text.trim(),
              'role': _role,
            });
          }

          if (state is Authenticated) {
            // Authenticated case (shouldn't normally reach here during registration flow)
            if (Navigator.of(context).canPop()) {
              context.pop(true);
            } else {
              if (state.user.role == UserRole.admin) GoRouter.of(context).go(AppRoutes.adminDashboard);
              else if (state.user.role == UserRole.worker) GoRouter.of(context).go(AppRoutes.workerHome);
              else GoRouter.of(context).go(AppRoutes.home);
            }
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
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => Validators.validatePhoneNumber(v?.trim() ?? ''),
                        ),
                        const SizedBox(height: 20),
                        CommonButton(onPressed: _registerWithEmail, text: 'Register', isLoading: _isLoading),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: _isLoading ? null : _registerAndVerifyPhone, child: const Text('Register & Verify Phone (OTP)'), ),
                        const SizedBox(height: 12),
                        // Show Google sign-in only on Android or Web
                        if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) ...[
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : () {
                              // Trigger Google Sign-In via BLoC
                              context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
                            },
                            icon: const Icon(Icons.g_mobiledata),
                            label: Text(_isLoading ? 'Processing...' : 'Continue with Google'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 16),
                        Center(child: Text('Or', style: Theme.of(context).textTheme.bodyMedium)),
                        const SizedBox(height: 12),
                        // Social buttons left as placeholders; registration must be done via email verification.
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


/*
// lib/features/common_auth/presentation/pages/register_page.dart

import 'package:go_router/go_router.dart';

import '../../../../core/models/user_model.dart'; // For UserRole enum
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final _phoneCtrl = TextEditingController();
  UserRole _role = UserRole.user;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submitRegistration() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
          // On success, the central router redirect will handle navigation automatically.
          // We can optionally pop here if we know this screen was pushed.
          if (state is Authenticated) {
            if (context.canPop()) context.pop();
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ... [Role selector UI] ...
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Enter min 6 chars' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone (optional)'),
                    keyboardType: TextInputType.phone,
                    validator: Validators.validatePhoneNumberOptional,
                  ),
                  const SizedBox(height: 16),
                  CommonButton(
                    onPressed: _submitRegistration,
                    text: 'Register',
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}*/
