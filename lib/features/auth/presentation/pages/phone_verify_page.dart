import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/common_button.dart';
import '../../../../shared/services/session_service.dart';
import '../../../../shared/models/user_model.dart';
import 'package:agapecares/features/user_app/cart/data/repository/cart_repository.dart';
import 'package:agapecares/features/user_app/cart/bloc/cart_bloc.dart';
import 'package:agapecares/features/user_app/cart/bloc/cart_event.dart';

class PhoneVerifyPage extends StatefulWidget {
  final String verificationId;
  final String phone;
  final String? name;
  final String? email;
  final String? role;

  const PhoneVerifyPage({super.key, required this.verificationId, required this.phone, this.name, this.email, this.role});

  @override
  State<PhoneVerifyPage> createState() => _PhoneVerifyPageState();
}

class _PhoneVerifyPageState extends State<PhoneVerifyPage> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
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
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final Map<String, dynamic> userData = {
          'uid': user.uid,
          'name': widget.name ?? '',
          'email': widget.email ?? '',
          'phoneNumber': widget.phone,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (widget.role != null) userData['role'] = widget.role;
        await userDoc.set(userData, SetOptions(merge: true));
        // Save session to shared preferences
        try {
          final session = context.read<SessionService>();
          final um = UserModel(uid: user.uid, phoneNumber: widget.phone, name: widget.name ?? '', email: widget.email, role: widget.role ?? 'user');
          await session.saveUser(um);
          // Seed cart from remote if available and notify bloc
          try {
            final cartRepo = context.read<CartRepository>();
            await cartRepo.getCartItems();
          } catch (_) {}
          try {
            context.read<CartBloc>().add(CartStarted());
          } catch (_) {}
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified')));
        if (!mounted) return;
        // Navigate to appropriate dashboard depending on role
        if ((widget.role ?? '').toLowerCase() == 'worker') {
          context.go(AppRoutes.workerHome);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
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
            CommonButton(onPressed: _verify, text: 'Verify', isLoading: _isLoading),
          ],
        ),
      ),
    );
  }
}
