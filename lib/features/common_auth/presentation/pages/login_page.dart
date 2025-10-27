// lib/features/common_auth/presentation/pages/login_page.dart
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
    try {
      context.read<AuthBloc>();
      return const LoginView();
    } catch (_) {
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
    // This logic is good, but your AppRouter.redirect already handles this.
    // You can keep it for a faster redirect if you want.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final session = context.read<SessionService>();
        final u = session.getUser();
        if (u != null && mounted) {
          if (u.role == UserRole.worker) {
            GoRouter.of(context).go(AppRoutes.workerHome);
          } else if (u.role == UserRole.admin) {
            GoRouter.of(context).go(AppRoutes.adminDashboard);
          } else {
            GoRouter.of(context).go(AppRoutes.home);
          }
        }
      } catch (_) {}
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
    if (_formKey.currentState?.validate() ?? false) {
      final phoneNumber = _phoneController.text.trim();
      context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
    }
  }

  Future<void> _signInWithEmail() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      context.read<AuthBloc>().add(AuthLoginWithEmailRequested(
        email: _email_controller.text.trim(),
        password: _passwordController.text.trim(),
      ));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoading) {
            if (mounted) setState(() => _isLoading = true);
            return;
          }

          if (mounted) setState(() => _isLoading = false);

          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }

          if (state is AuthPasswordResetSent) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Password reset email sent. Check your inbox.'),
              backgroundColor: Colors.green,
            ));
          }

          // This is the "email-not-verified" state
          if (state is AuthEmailVerificationSent) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Verify your email'),
                  content: Text('A verification email has been sent to ${state.email ?? _email_controller.text}. Please check your inbox and verify your email before logging in.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _signInWithEmail(); // Re-dispatch login to resend email
                      },
                      child: const Text('Resend'),
                    ),
                  ],
                ),
              );
            }
          }
          if (state is AuthOtpSent) {
            GoRouter.of(context).push(AppRoutes.phoneVerify, extra: state.verificationId);
          }
          if (state is Authenticated) {
            // The AppRouter.redirect will handle navigation, no need to push here.
            // You can remove the GoRouter.of(context).go(...) lines
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
                          } catch (_) {}
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                label: const Text('Email'),
                                selected: _isEmailMode,
                                onSelected: (selected) {
                                  if (selected) setState(() => _isEmailMode = true);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Phone'),
                                selected: !_isEmailMode,
                                onSelected: (selected) {
                                  if (selected) setState(() => _isEmailMode = false);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (_isEmailMode) ...[
                            TextFormField(
                              controller: _email_controller,
                              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.validateEmail,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outlined)),
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
                                hintText: '+911234567890',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              validator: Validators.validatePhoneNumber,
                            ),
                            const SizedBox(height: 24),
                            CommonButton(onPressed: _sendOtp, text: 'Send OTP', isLoading: _isLoading),
                          ],

                          const SizedBox(height: 12),
                          if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) ...[
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : () {
                                setState(() => _isLoading = true);
                                context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
                              },
                              icon: const Icon(Icons.g_mobiledata), // Use a Google Icon Asset
                              label: Text(_isLoading ? 'Processing...' : 'Continue with Google'),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 12),
                          TextButton(onPressed: _isLoading ? null : () async {
                            final result = await GoRouter.of(context).push(AppRoutes.register);
                            if (result == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please check your email to verify.'), backgroundColor: Colors.green));
                            }
                          }, child: const Text('Don\'t have an account? Register')),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isLoading ? null : () => GoRouter.of(context).push(AppRoutes.forgotPassword),
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
      ),
    );
  }
}