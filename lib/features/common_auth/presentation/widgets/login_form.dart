// File: lib/features/auth/presentation/widgets/login_form.dart
// language: dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../logic/blocs/auth_bloc.dart';
import '../../logic/blocs/auth_event.dart';
import '../../logic/blocs/auth_state.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_button.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    // Dispatch event to send OTP
    context.read<AuthBloc>().add(AuthSendOtpRequested(phone));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          // Navigate to OTP verification page, pass the verificationId as extra
          if (mounted) context.push(AppRoutes.phoneVerify, extra: state.verificationId);
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Welcome', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          Text('Enter your phone number to continue', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone (include country code)',
                              hintText: '+911234567890',
                              prefixIcon: const Icon(Icons.phone),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter phone number';
                              return Validators.validatePhoneNumber(v.trim());
                            },
                          ),
                          const SizedBox(height: 20),
                          CommonButton(onPressed: isLoading ? null : _submit, text: 'Send OTP', isLoading: isLoading),
                          const SizedBox(height: 12),
                          Center(child: Text('Or', style: Theme.of(context).textTheme.bodyMedium)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.g_mobiledata), label: const Text('Continue with Google')),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.apple), label: const Text('Continue with Apple')),
                        ],
                      ),
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