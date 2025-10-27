// lib/features/common_auth/presentation/pages/phone_verify_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/routes/app_routes.dart';

import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';

class PhoneVerifyPage extends StatelessWidget {
  /// The verificationId is passed from the previous screen.
  final String verificationId;
  final String? name;
  final String? email;
  final String? phone;
  final String? password;
  final UserRole? role;

  const PhoneVerifyPage({
    super.key,
    required this.verificationId,
    this.name,
    this.email,
    this.phone,
    this.password,
    this.role
  });

  factory PhoneVerifyPage.fromExtras({ dynamic extra}) {
    String verId = '';
    String? name, email, phone, password;
    UserRole? role;

    if (extra is String) {
      verId = extra;
    } else if (extra is Map<String, dynamic>) {
      verId = extra['verificationId'] ?? '';
      name = extra['name'] as String?;
      email = extra['email'] as String?;
      phone = extra['phone'] as String?;
      password = extra['password'] as String?;
      final r = extra['role'];
      if (r is UserRole) role = r;
      // You might also need to parse role from string if it comes as text
    }

    return PhoneVerifyPage(
      verificationId: verId,
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: role,
    );
  }

  void _verifyOtp(BuildContext context, String otp) {
    // If email and password are present, this OTP is part of the registration flow
    if ((email != null && email!.isNotEmpty) && (password != null && password!.isNotEmpty)) {
      context.read<AuthBloc>().add(
        AuthRegisterWithPhoneOtpRequested(
          verificationId: verificationId,
          otp: otp,
          email: email!,
          password: password!,
          name: name ?? '',
          phone: phone ?? '',
          role: role ?? UserRole.user,
        ),
      );
    } else {
      // phone-only verification (login or standalone)
      context.read<AuthBloc>().add(
        AuthVerifyOtpRequested(verificationId: verificationId, otp: otp, name: name, email: email, role: role),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red),);
          }
          if (state is AuthEmailVerificationSent) {
            // Registration via phone linked to email requires email verification next.
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification email sent to ${state.email ?? email ?? ''}. Please verify to complete registration.'), backgroundColor: Colors.orange));
            // Go back to the login page
            GoRouter.of(context).go(AppRoutes.login);
            return;
          }
          if (state is Authenticated) {
            // On success, the main AppRouter redirect will handle navigation
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification successful'), backgroundColor: Colors.green),);
            // The router will automatically move user to home
          }
        },
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Enter Code', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Pinput(length: 6, onCompleted: (pin) => _verifyOtp(context, pin)),
                        const SizedBox(height: 18),
                        if (state is AuthLoading) const CircularProgressIndicator() else const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}