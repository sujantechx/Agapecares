// lib/features/common_auth/presentation/pages/phone_verify_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:agapecares/core/models/user_model.dart';

import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';

class PhoneVerifyPage extends StatelessWidget {
  /// The verificationId is passed from the previous screen (e.g., LoginPage).
  final String verificationId;
  final String? name;
  final String? email;
  final String? phone;
  final UserRole? role;

  const PhoneVerifyPage({super.key, required this.verificationId, this.name, this.email, this.phone, this.role});

  void _verifyOtp(BuildContext context, String otp) {
    context.read<AuthBloc>().add(
      AuthVerifyOtpRequested(verificationId: verificationId, otp: otp, name: name, email: email, role: role),
    );
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
          if (state is Authenticated) {
            if (context.canPop()) {
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification successful'), backgroundColor: Colors.green),);
            }
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