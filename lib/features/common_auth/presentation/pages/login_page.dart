// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agapecares/app/routes/app_routes.dart';
import 'package:agapecares/core/utils/validators.dart';
import 'package:agapecares/core/widgets/common_button.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';


class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the AuthBloc provided at the app level (injection_container.dart).
    // If none is available (tests or minimal app shells), provide a temporary
    // AuthBloc that uses the default Firebase instances so the page can build safely.
    try {
      // Try to read an existing AuthBloc. If it doesn't exist, this will throw.
      context.read<AuthBloc>();
      return const LoginView();
    } catch (_) {
      // Provide a local AuthBloc using the existing AuthRepository implementation.
      return BlocProvider(
        create: (context) {
          return AuthBloc(authRepository: AuthRepository(firebaseAuth: FirebaseAuth.instance, firestore: FirebaseFirestore.instance));
        },
        child: const LoginView(),
      );
    }
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If a session is already present, navigate to the correct dashboard automatically.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final session = context.read<SessionService>();
        final u = session.getUser();
        if (u != null) {
          if (mounted) {
            // Compare enum values, not strings. Route admins to admin dashboard.
            if (u.role == UserRole.worker) {
              GoRouter.of(context).go(AppRoutes.workerHome);
            } else if (u.role == UserRole.admin) {
              GoRouter.of(context).go(AppRoutes.adminDashboard);
            } else {
              GoRouter.of(context).go(AppRoutes.home);
            }
          }
        }
      } catch (_) {
        // No SessionService is provided (e.g., during lightweight tests). Ignore.
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    // Validate the form before proceeding.
    if (_formKey.currentState!.validate()) {
      final phoneNumber = _phoneController.text.trim();
      // Dispatch send OTP event
      context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
    }
  }

  Future<void> _signInWithEmail() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) return;
    // Dispatch login event to AuthBloc; the bloc/repository will handle sign-in and user fetching.
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(AuthLoginWithEmailRequested(email: _emailController.text.trim(), password: _passwordController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
            if (mounted) setState(() => _isLoading = false);
          }
          if (state is AuthOtpSent) {
            // navigate to OTP verification page. Extra can be a map or the verificationId itself.
            GoRouter.of(context).push(AppRoutes.phoneVerify, extra: state.verificationId);
          }
          if (state is Authenticated) {
            if (mounted) setState(() => _isLoading = false);
            final role = state.user.role;
            // Route based on enum role. Admins go to admin dashboard.
            if (role == UserRole.worker) {
              GoRouter.of(context).go(AppRoutes.workerHome);
            } else if (role == UserRole.admin) {
              GoRouter.of(context).go(AppRoutes.adminDashboard);
            } else {
              GoRouter.of(context).go(AppRoutes.home);
            }
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Phone'),
                        selected: !_isEmailMode,
                        onSelected: (s) => setState(() => _isEmailMode = !s),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Email'),
                        selected: _isEmailMode,
                        onSelected: (s) => setState(() => _isEmailMode = s),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isEmailMode) ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6) ? 'Enter min 6 chars' : null,
                    ),
                    const SizedBox(height: 16),
                    CommonButton(onPressed: _signInWithEmail, text: 'Login', isLoading: _isLoading),
                  ] else ...[
                    Text(
                      'Enter your phone number to continue',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                      ),
                      validator: Validators.validatePhoneNumber,
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
                      return CommonButton(onPressed: _sendOtp, text: 'Send OTP', isLoading: state is AuthLoading);
                    }),
                  ],

                  const SizedBox(height: 12),
                  // Inside _LoginViewState in login_page.dart

// Modify your TextButton for navigation to register page
                  TextButton(onPressed: () async {
                    final result = await GoRouter.of(context).push(AppRoutes.register);
                    if (result == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful!'), backgroundColor: Colors.green));
                    }
                  }, child: const Text('Don\'t have an account? Register')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => GoRouter.of(context).push(AppRoutes.forgotPassword),
                    child: const Text('Forgot password?'),
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


/*
// lib/features/common_auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';
import 'package:agapecares/core/utils/validators.dart';
import 'package:agapecares/core/widgets/common_button.dart';

import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEmailMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final authBloc = context.read<AuthBloc>();

    if (_isEmailMode) {
      authBloc.add(AuthLoginWithEmailRequested(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ));
    } else {
      // For phone login, first send OTP.
      // The BLoC will emit AuthOtpSent state, which we listen for to navigate.
      authBloc.add(AuthSendOtpRequested(_phoneController.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
          // When OTP is sent, navigate to the verification page.
          if (state is AuthOtpSent) {
            context.push(AppRoutes.phoneVerify, extra: state.verificationId);
          }
          // No need to listen for success, the router's redirect will handle it automatically.
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Welcome Back!', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    // ... [UI for switching between email and phone] ...
                    if (_isEmailMode)
                      _buildEmailForm(isLoading)
                    else
                      _buildPhoneForm(isLoading),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: const Text('Don\'t have an account? Register'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmailForm(bool isLoading) {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
          validator: Validators.validateEmail,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          validator: (v) => (v == null || v.length < 6) ? 'Enter min 6 chars' : null,
        ),
        const SizedBox(height: 16),
        CommonButton(onPressed: _submit, text: 'Login', isLoading: isLoading),
      ],
    );
  }

  Widget _buildPhoneForm(bool isLoading) {
    return Column(
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', prefixText: '+91 '),
          validator: Validators.validatePhoneNumber,
        ),
        const SizedBox(height: 24),
        CommonButton(onPressed: _submit, text: 'Send OTP', isLoading: isLoading),
      ],
    );
  }
}*/
