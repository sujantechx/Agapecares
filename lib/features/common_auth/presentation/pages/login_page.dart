// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:agapecares/app/routes/app_routes.dart';
import 'package:agapecares/core/utils/validators.dart';
import 'package:agapecares/core/widgets/common_button.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/theme/theme_cubit.dart';


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
  final _email_controller = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailMode = true;
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
    _email_controller.dispose();
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
    context.read<AuthBloc>().add(AuthLoginWithEmailRequested(email: _email_controller.text.trim(), password: _passwordController.text.trim()));
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
          if (state is AuthEmailVerificationSent) {
            // Show dialog with guidance and a button to attempt resending by re-attempting login.
            if (mounted) {
              setState(() => _isLoading = false);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Verify your email'),
                  content: Text('A verification email has been sent to ${state.email ?? _email_controller.text}. Please check your inbox and verify your email before logging in.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                    TextButton(
                      onPressed: () {
                        // Encourage the user to retry login which will trigger another verification email.
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Try logging in again to resend verification email.')));
                      },
                      child: const Text('Resend'),
                    ),
                  ],
                ),
              );
            }
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row with logo and theme toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 64,
                      child: Image.asset('assets/logos/app_logo.png', fit: BoxFit.contain),
                    ),
                    IconButton(
                      icon: const Icon(Icons.brightness_6),
                      onPressed: () {
                        try {
                          context.read<ThemeCubit>().toggle();
                        } catch (_) {
                          // ThemeCubit not provided in this context (tests or isolated usage).
                        }
                      },
                       tooltip: 'Toggle theme',
                     ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Welcome Back!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        // mode selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: const Text('Email'),
                              selected: _isEmailMode,
                              onSelected: (s) => setState(() => _isEmailMode = s),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (_isEmailMode) ...[
                          TextFormField(
                            controller: _email_controller,
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

                          const SizedBox(height: 12),
                          // Google sign-in only on Android or Web
                          if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) ...[
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : () {
                                setState(() => _isLoading = true);
                                context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
                              },
                              icon: const Icon(Icons.g_mobiledata),
                              label: Text(_isLoading ? 'Processing...' : 'Continue with Google'),
                            ),
                            const SizedBox(height: 8),
                          ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
