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
    // Standard BlocProvider setup (no changes needed here)
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
  // Removed _phoneController
  final _emailController = TextEditingController(); // Renamed for clarity
  final _passwordController = TextEditingController();
  // Removed _isEmailMode state variable
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Keep the initial redirect check based on session
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
    // Removed _phoneController.dispose()
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Removed _sendOtp function

  Future<void> _signInWithEmail() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      // Dispatch email/password login event
      context.read<AuthBloc>().add(AuthLoginWithEmailRequested(
        email: _emailController.text.trim(), // Use the email controller
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
          // --- Listener logic remains largely the same ---
          if (state is AuthLoading) {
            if (mounted) setState(() => _isLoading = true);
            return;
          }

          // Stop loading indicator on any non-loading state
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

          if (state is AuthEmailVerificationSent) {
            // Handle email verification required
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Verify your email'),
                  content: Text('A verification email has been sent to ${state.email ?? _emailController.text}. Please check your inbox and verify your email before logging in.'),
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
          // Removed AuthOtpSent handler as OTP login is not part of this form anymore

          if (state is Authenticated) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Login Successful!'),
                backgroundColor: Colors.green,
                duration: Duration(milliseconds: 1500),
              ));
              // AppRouter redirect handles navigation
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
                  Row( // Logo and Theme Toggle Row
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
                  Card( // Main Login Card
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Welcome Back!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: 24), // Increased spacing

                          // --- REMOVED ChoiceChip Row ---

                          // --- Email Input Field ---
                          TextFormField(
                            controller: _emailController, // Use email controller
                            decoration: const InputDecoration(
                              labelText: 'Email', // Label is Email
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail, // Validate as Email
                          ),
                          const SizedBox(height: 12), // Increased spacing

                          // --- Password Input Field ---
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                            ),
                            obscureText: true,
                            validator: Validators.validatePassword, // Use standard password validator
                          ),
                          const SizedBox(height: 20), // Increased spacing

                          // --- Login Button ---
                          CommonButton(
                              onPressed: _signInWithEmail, // Always call email sign in
                              text: 'Login',
                              isLoading: _isLoading
                          ),
                          const SizedBox(height: 16), // Increased spacing

                          // --- REMOVED Phone Number Input and Send OTP Button ---

                          // --- Google Sign In Button ---
                          if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) ...[
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : () {
                                setState(() => _isLoading = true);
                                context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
                              },
                              icon: const Image(image: AssetImage('assets/logos/google_logo.png'),
                                height: 35,width: 30,),
                              label: Text(_isLoading ? 'Processing...' : 'Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12), // Adjust padding
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                            ),
                            const SizedBox(height: 12), // Increased spacing
                          ],

                          // --- Register and Forgot Password Links ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _isLoading ? null : () => GoRouter.of(context).push(AppRoutes.forgotPassword),
                                child: const Text('Forgot password?'),
                              ),
                              TextButton(
                                onPressed: _isLoading ? null : () async {
                                  final result = await GoRouter.of(context).push(AppRoutes.register);
                                  if (result == true && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please check your email to verify.'), backgroundColor: Colors.green));
                                  }
                                },
                                child: const Text('Register'),
                              ),
                            ],
                          ),
                          // Removed extra SizedBox and TextButton duplication
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