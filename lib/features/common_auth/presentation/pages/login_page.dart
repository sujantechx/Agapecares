// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agapecares/app/routes/app_routes.dart';
import 'package:agapecares/core/utils/validators.dart';
import 'package:agapecares/core/widgets/common_button.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/datasources/auth_remote_ds.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/features/user_app/features/cart/data/repository/cart_repository.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_bloc.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_event.dart';


class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the AuthBloc provided at the app level (injection_container.dart).
    // If none is available (tests or minimal app shells), provide a temporary
    // AuthBloc that uses the dummy data source so the page can build safely.
    try {
      // Try to read an existing AuthBloc. If it doesn't exist, this will throw.
      context.read<AuthBloc>();
      return const LoginView();
    } catch (_) {
      // Provide a local AuthBloc built from the dummy remote datasource.
      return BlocProvider(
        create: (context) => AuthBloc(
          authRepository: AuthRepositoryImpl(
            // Provide real Firebase instances so the fallback bloc can be used
            // in simple/test shells without altering the constructor signature.
            remoteDataSource: AuthRemoteDataSourceImpl(
              firebaseAuth: FirebaseAuth.instance,
              firestore: FirebaseFirestore.instance,
            ),
            // Try to read a SessionService if available; if not, this will
            // throw and the caller's catch will handle it. In most app runs
            // a SessionService is registered at the top level.
            sessionService: context.read<SessionService>(),
          ),
        ),
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
    // If a session is already present, navigate to home automatically.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final session = context.read<SessionService>();
        final u = session.getUser();
        if (u != null) {
          if (mounted) {
            if (u.role == 'worker') {
              context.go(AppRoutes.workerHome);
            } else {
              context.go(AppRoutes.home);
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
      // Add the event to the BLoC.
      context.read<AuthBloc>().add(AuthSendOtpRequested(phoneNumber));
    }
  }

  Future<void> _signInWithEmail() async {
    // Fix: return early if form is invalid
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // Read session service before any await to avoid using context across async gaps
    final sessionService = context.read<SessionService>();
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = cred.user;
      if (user != null) {
        // Determine role from Firestore user doc (fallback to 'user')
        String role = 'user';
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data();
          if (data != null && data['role'] is String) role = data['role'] as String;
        } catch (e) {
          debugPrint('[LoginPage] failed to read user role from Firestore: $e');
        }
        // Save session (fire-and-forget is fine here)
        try {
          final um = UserModel(uid: user.uid, phoneNumber: user.phoneNumber ?? '', name: user.displayName ?? '', email: user.email, role: role);
          // Await saving the session to ensure persistence before navigation.
          await sessionService.saveUser(um);
          // Seed cart and notify CartBloc so the UI updates immediately
          try {
            final cartRepo = context.read<CartRepository>();
            await cartRepo.getCartItems();
          } catch (_) {}
          try {
            context.read<CartBloc>().add(CartStarted());
          } catch (_) {}
        } catch (_) {}
        if (!mounted) return;
        // Navigate to the correct dashboard based on role
        if (role == 'worker') {
          context.go(AppRoutes.workerHome);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        // Listen for state changes to handle navigation or show snackbars.
        listener: (context, state) {
          if (state is AuthCodeSentSuccess) {
            // Navigate to OTP page on success
            context.push(AppRoutes.otp, extra: _phoneController.text.trim());
          } else if (state is AuthFailure) {
            // Show an error message on failure
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
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
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return CommonButton(
                          onPressed: _sendOtp,
                          text: 'Send OTP',
                          isLoading: state is AuthLoading,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  // Inside _LoginViewState in login_page.dart

// Modify your TextButton for navigation to register page
                  TextButton(
                    onPressed: () async {
                      // Navigate and wait for a result
                      final result = await context.push(AppRoutes.register);
                      if (result == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registration successful! Please log in.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text('Don\'t have an account? Register'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.forgotPassword),
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
