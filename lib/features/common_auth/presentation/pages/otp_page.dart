// lib/features/auth/presentation/pages/otp_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:agapecares/core/widgets/common_button.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_bloc.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_event.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';


class OtpPage extends StatelessWidget {
  final String phoneNumber;
  const OtpPage({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    // Use existing AuthBloc provided at the app level (from injection_container)
    return OtpView(phoneNumber: phoneNumber);
  }
}

// Converted to StatefulWidget to allow use of `mounted` in async listeners
class OtpView extends StatefulWidget {
  final String phoneNumber;
  const OtpView({super.key, required this.phoneNumber});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  void _verifyOtp(BuildContext context, String otp) {
    context.read<AuthBloc>().add(AuthVerifyOtpRequested(verificationId: '', otp: otp));
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, ),
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
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is Authenticated) {
            // Save session
            try {
              final session = context.read<SessionService>();
              await session.saveUser(state.user);
            } catch (_) {}
            // If cart repository is available, attempt to seed local DB from remote.
            try {
              final cartRepo = context.read<CartRepository>();
              // Fire-and-forget: getCartItems may seed the local DB
              await cartRepo.getCartItems();
            } catch (_) {}

            // Ensure CartBloc recalculates its state from the repository so UI updates immediately
            try {
              context.read<CartBloc>().add(CartStarted());
            } catch (_) {}

            // On successful login, navigate to the home screen and remove
            // the auth pages from the navigation stack.
            if (!mounted) return;
            GoRouter.of(context).go('/home');
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
                      Text('We have sent an OTP to +91 ${widget.phoneNumber}', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Pinput(
                        length: 6,
                        defaultPinTheme: defaultPinTheme.copyWith(
                          width: 50,
                          height: 56,
                          textStyle: const TextStyle(fontSize: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onCompleted: (pin) => _verifyOtp(context, pin),
                      ),
                      const SizedBox(height: 24),
                      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
                        return CommonButton(onPressed: null, text: 'Verify', isLoading: state is AuthLoading);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
