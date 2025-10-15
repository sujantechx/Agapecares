// lib/features/common_auth/presentation/pages/phone_verify_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';


import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';

class PhoneVerifyPage extends StatelessWidget {
  /// The verificationId is passed from the previous screen (e.g., LoginPage).
  final String verificationId;

  const PhoneVerifyPage({super.key, required this.verificationId});

  void _verifyOtp(BuildContext context, String otp) {
    context.read<AuthBloc>().add(
      AuthVerifyOtpRequested(verificationId: verificationId, otp: otp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
          // On success, the central router will handle navigation automatically.
          // If this page was pushed, we can pop it.
          if (state is Authenticated) {
            if (context.canPop()) {
              context.pop();
            }
          }
        },
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Enter Code', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 48),
                  Pinput(
                    length: 6,
                    onCompleted: (pin) => _verifyOtp(context, pin),
                  ),
                  const SizedBox(height: 24),
                  if (state is AuthLoading)
                    const CircularProgressIndicator()
                  else
                    const SizedBox.shrink(), // Button is not needed as submission is automatic
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}