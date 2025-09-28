// lib/features/auth/presentation/pages/otp_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/common_button.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';


class OtpPage extends StatelessWidget {
  final String phoneNumber;
  const OtpPage({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC here as well. In a larger app, this would be inherited.
    return BlocProvider(
      create: (context) => AuthBloc(
        authRepository: AuthRepositoryImpl(
          remoteDataSource: AuthDummyDataSourceImpl(),
        ),
      ),
      child: OtpView(phoneNumber: phoneNumber),
    );
  }
}

class OtpView extends StatelessWidget {
  final String phoneNumber;
  const OtpView({super.key, required this.phoneNumber});

  void _verifyOtp(BuildContext context, String otp) {
    context.read<AuthBloc>().add(AuthVerifyOtpRequested(otp));
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: AppTheme.textColor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textColor,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoggedIn) {
            // On successful login, navigate to the home screen and remove
            // the auth pages from the navigation stack.
            context.go('/home');
          } else if (state is AuthFailure) {
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Enter Code',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'We have sent an OTP to +91 $phoneNumber',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Pinput(
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: AppTheme.primaryColor),
                    ),
                  ),
                  onCompleted: (pin) => _verifyOtp(context, pin),
                ),
                const SizedBox(height: 24),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return CommonButton(
                      // The button is disabled as verification is auto-triggered on completion.
                      onPressed: null,
                      text: 'Verify',
                      isLoading: state is AuthLoading,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}