import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/widgets/common_button.dart';
import '../../../user_app/features/cart/bloc/cart_bloc.dart';
import '../../../user_app/features/cart/bloc/cart_event.dart';
import '../../../user_app/features/cart/data/repositories/cart_repository.dart';


class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key});

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _setPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final pwd = _passwordCtrl.text.trim();
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No authenticated user found. Please verify via OTP first.')));
        return;
      }
      // user is signed in (OTP-based reset or auto sign-in). Update password.
      await user.updatePassword(pwd);
      // Refresh and save session (email/phone/name may be updated by auth)

    try {
    final session = context.read<SessionService>();
    final um = UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email,
      phoneNumber: user.phoneNumber ?? '',
      photoUrl: null,
      role: UserRole.user,
      addresses: null,
      createdAt: Timestamp.now(),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
      if (!mounted) return;
      // After changing password, redirect to login or home
      context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update password: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validatePassword(String? v) {
    if (v == null || v.length < 6) return 'Enter min 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        obscureText: true,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirm password';
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CommonButton(onPressed: _setPassword, text: 'Set Password', isLoading: _isLoading),
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