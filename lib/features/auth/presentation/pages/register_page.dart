import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/common_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/services/session_service.dart';
import '../../../../shared/models/user_model.dart';
import 'package:agapecares/features/user_app/cart/data/repository/cart_repository.dart';
import 'package:agapecares/features/user_app/cart/bloc/cart_bloc.dart';

import '../../../user_app/cart/bloc/cart_event.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      final user = cred.user;
      if (user != null) {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDoc.set({
          'uid': user.uid,
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phoneNumber': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Save session
        try {
          final session = context.read<SessionService>();
          final um = UserModel(uid: user.uid, phoneNumber: _phoneCtrl.text.trim().isEmpty ? '' : _phoneCtrl.text.trim(), name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim());
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered successfully')));
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startPhoneRegistration() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          // Auto sign-in (rare). Create user doc if needed.
          await FirebaseAuth.instance.signInWithCredential(credential);
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
            await userDoc.set({
              'uid': user.uid,
              'name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
              'phoneNumber': user.phoneNumber,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            // Save session so the user stays logged in
            try {
              final session = context.read<SessionService>();
              final um = UserModel(uid: user.uid, phoneNumber: user.phoneNumber ?? '', name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim());
              await session.saveUser(um);
              // Seed cart and notify bloc
              try {
                final cartRepo = context.read<CartRepository>();
                await cartRepo.getCartItems();
              } catch (_) {}
              try {
                context.read<CartBloc>().add(CartStarted());
              } catch (_) {}
            } catch (_) {}
          }
          if (!mounted) return;
          try {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in automatically')));
          } catch (_) {}
          if (!mounted) return;
          context.go(AppRoutes.home);
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone verification failed: ${e.message}')));
        },
        codeSent: (verificationId, resendToken) {
          // Navigate to phone verify page with verificationId and phone
          context.push(AppRoutes.phoneVerify, extra: {
            'verificationId': verificationId,
            'phone': phone,
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim()
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start phone auth: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.validateEmail,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Enter min 6 chars' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone (include country code)'),
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhoneNumberOptional,
              ),
              const SizedBox(height: 16),
              CommonButton(onPressed: _registerWithEmail, text: 'Register with Email', isLoading: _isLoading),
              const SizedBox(height: 8),
              CommonButton(onPressed: _startPhoneRegistration, text: 'Register / Sign in with Phone', isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }
}
