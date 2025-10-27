// lib/features/common_auth/presentation/pages/phone_reset_otp_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- FIX: Added import for AppRoutes ---
import 'package:agapecares/app/routes/app_routes.dart';
// --- End Fix ---

import '../../../../core/models/user_model.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/widgets/common_button.dart';
import '../../../user_app/features/cart/bloc/cart_bloc.dart';
import '../../../user_app/features/cart/bloc/cart_event.dart';
import '../../../user_app/features/cart/data/repositories/cart_repository.dart';

class PhoneResetOtpPage extends StatefulWidget {
  final String verificationId;
  final String phone;

  const PhoneResetOtpPage({super.key, required this.verificationId, required this.phone});

  @override
  State<PhoneResetOtpPage> createState() => _PhoneResetOtpPageState();
}

class _PhoneResetOtpPageState extends State<PhoneResetOtpPage> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAndProceed() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter verification code')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = PhoneAuthProvider.credential(verificationId: widget.verificationId, smsCode: code);
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final user = userCred.user;
      if (user != null) {
        // Save session so user remains logged in
        try {
          final session = context.read<SessionService>();
          final um = UserModel(
            uid: user.uid,
            phoneNumber: widget.phone,
            name: user.displayName ?? '',
            email: user.email,
            role: UserRole.user,
            createdAt: Timestamp.fromDate(user.metadata.creationTime ?? DateTime.now()),
          );
          await session.saveUser(um);
          // Try to seed cart
          try {
            context.read<CartRepository>().getCartItems();
            context.read<CartBloc>().add(CartStarted());
          } catch (_) {}
        } catch (_) {}
        if (!mounted) return;

        // --- FIX: Use AppRoutes constant ---
        context.push(AppRoutes.setNewPassword);
        // --- End Fix ---

      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Enter the SMS code sent to ${widget.phone}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CommonButton(onPressed: _verifyAndProceed, text: 'Verify & Set New Password', isLoading: _isLoading),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}