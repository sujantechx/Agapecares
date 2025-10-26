import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';
import '../../core/models/user_model.dart';

/// A small splash router that decides where to send the user after a brief delay.
/// It shows onboarding on first launch, otherwise performs the same auth+role
/// checks as the original splash screen and navigates accordingly.
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 700), _decide);
  }

  Future<void> _decide() async {
    if (!mounted) return;
    if (kDebugMode) debugPrint('SplashRouter: deciding navigation');

    // 1) onboarding
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_onboarding') ?? false;
      if (!seen) {
        if (!mounted) return;
        if (kDebugMode) debugPrint('SplashRouter: routing to onboarding');
        GoRouter.of(context).go(AppRoutes.onboarding);
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SplashRouter: prefs error $e');
      // continue
    }

    // 2) auth check
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('SplashRouter: routing to login');
      GoRouter.of(context).go(AppRoutes.login);
      return;
    }

    // 3) fetch role
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final role = (data != null && data['role'] is String) ? (data['role'] as String) : UserRole.user.name;
      final normalized = role.trim().toLowerCase();
      if (!mounted) return;
      if (normalized == UserRole.worker.name) {
        GoRouter.of(context).go(AppRoutes.workerHome);
      } else if (normalized == UserRole.admin.name) {
        GoRouter.of(context).go(AppRoutes.adminDashboard);
      } else {
        GoRouter.of(context).go(AppRoutes.home);
      }
      return;
    } catch (e, st) {
      if (kDebugMode) debugPrint('SplashRouter: role fetch error $e\n$st');
      if (!mounted) return;
      GoRouter.of(context).go(AppRoutes.home);
      return;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/logos/ap_logo.png', width: 180, height: 180, fit: BoxFit.contain),
          const SizedBox(height: 12),
          const Text('Loading…', style: TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}

