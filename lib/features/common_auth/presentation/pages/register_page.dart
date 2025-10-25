import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false; // true when user started email registration
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
    // mark that this flow is an email registration so that on success we pop back to login
    _isRegistering = true;
    setState(() => _isLoading = true);
    // dispatch registration event to AuthBloc which will handle Firebase and Firestore writes
    context.read<AuthBloc>().add(AuthRegisterRequested(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      role: _role,
    ));
  }

  void _startPhoneRegistration() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number')));
      return;
    }

    // Enforce email-only registration: if the user filled name/email/password and now attempts
    // phone registration, instruct them to use email registration instead. Phone flow is for
    // login/OTP only in this app configuration.
    final hasFilledRegistrationFields = _nameCtrl.text.trim().isNotEmpty || _emailCtrl.text.trim().isNotEmpty || _passwordCtrl.text.trim().isNotEmpty;
    if (hasFilledRegistrationFields) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Phone cannot be used to create a new account. Please use "Register with Email".'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Dispatch an event to send OTP; UI will navigate when AuthState changes to AuthOtpSent
    context.read<AuthBloc>().add(AuthSendOtpRequested(phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Reset loading flag on any non-loading state
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
            _isRegistering = false;
            return;
          }

          if (state is Authenticated) {
            // If we initiated an email registration flow, return to the login screen so the user
            // can sign in (and to avoid automatically logging in newly created users).
            if (_isRegistering) {
              if (mounted) {
                // Show success snackbar, then pop back to Login with true.
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Registration successful. Please login.'),
                  backgroundColor: Colors.green,
                ));

                // Small delay so the user notices the snackbar before the screen closes.
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (!mounted) return;
                  // If this page was pushed, pop with a positive result so callers can show success.
                  if (Navigator.of(context).canPop()) {
                    context.pop(true);
                  } else {
                    // As a fallback, route to login explicitly.
                    GoRouter.of(context).go(AppRoutes.login);
                  }
                });

                // Ensure loading state is reset.
                if (mounted) setState(() => _isLoading = false);
              }
              _isRegistering = false;
              return;
            }

            // If this screen was pushed and we weren't the one who initiated registration, simply pop.
            if (Navigator.of(context).canPop()) {
              context.pop(true);
            } else {
              // Route admins to admin dashboard explicitly if not a registration flow
              if (state.user.role == UserRole.admin) {
                GoRouter.of(context).go(AppRoutes.adminDashboard);
              } else if (state.user.role == UserRole.worker) {
                GoRouter.of(context).go(AppRoutes.workerHome);
              } else {
                GoRouter.of(context).go(AppRoutes.home);
              }
            }
          }

          if (state is AuthOtpSent) {
            // When OTP is sent, navigate to OTP screen with arguments including name/email/role
            GoRouter.of(context).push(AppRoutes.phoneVerify, extra: {
              'verificationId': state.verificationId,
              // For phone-only login we don't pass name/email/role because registration is email-only
              'phone': _phoneCtrl.text.trim(),
            });
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Role selector: user or worker (ChoiceChips - no deprecated APIs)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('User'),
                      selected: _role == UserRole.user,
                      onSelected: (s) => setState(() => _role = UserRole.user),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Worker'),
                      selected: _role == UserRole.worker,
                      onSelected: (s) => setState(() => _role = UserRole.worker),
                    ),
                  ],
                ),
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
                  decoration: const InputDecoration(labelText: 'Phone (include country code)'),
                  keyboardType: TextInputType.phone,
                  validator: Validators.validatePhoneNumberOptional,
                ),
                const SizedBox(height: 16),
                CommonButton(onPressed: _registerWithEmail, text: 'Register with Email', isLoading: _isLoading),
                const SizedBox(height: 8),
                CommonButton(onPressed: _startPhoneRegistration, text: 'Register / Sign in with Phone', isLoading: _isLoading),
              ],
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
