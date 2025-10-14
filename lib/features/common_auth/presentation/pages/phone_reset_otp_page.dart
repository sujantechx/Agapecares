import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';


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
          final um = UserModel(uid: user.uid, phoneNumber: widget.phone, name: user.displayName ?? '', email: user.email);
          await session.saveUser(um);
          // Seed cart and notify CartBloc
          try {
            final cartRepo = context.read<CartRepository>();
            await cartRepo.getCartItems();
          } catch (_) {}
          try {
            context.read<CartBloc>().add(CartStarted());
          } catch (_) {}
        } catch (_) {}
        if (!mounted) return;
        // Navigate to set new password page where user can set a new password
        // Use literal path to avoid any constant lookup issue in analyzer
        context.push('/set-new-password');
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Enter the SMS code sent to ${widget.phone}'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Verification Code'),
            ),
            const SizedBox(height: 16),
            CommonButton(onPressed: _verifyAndProceed, text: 'Verify & Set New Password', isLoading: _isLoading),
          ],
        ),
      ),
    );
  }
}