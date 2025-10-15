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
    // Dispatch an event to send OTP; UI will navigate when AuthState changes to AuthOtpSent
    context.read<AuthBloc>().add(AuthSendOtpRequested(phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
          if (state is AuthLoading) {
            setState(() => _isLoading = true);
          } else {
            if (mounted) setState(() => _isLoading = false);
          }
          if (state is Authenticated) {
            // Registration succeeded and repo emitted the authenticated user; navigate via router
            if (Navigator.of(context).canPop()) {
              context.pop(true);
            } else {
              if (_role == UserRole.worker) {
                context.go(AppRoutes.workerHome);
              } else {
                context.go(AppRoutes.home);
              }
            }
          }
          if (state is AuthOtpSent) {
            // When OTP is sent, navigate to OTP screen with arguments including name/email/role
            context.push(AppRoutes.phoneVerify, extra: {
              'verificationId': state.verificationId,
              'phone': _phoneCtrl.text.trim(),
              'name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'role': _role,
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
