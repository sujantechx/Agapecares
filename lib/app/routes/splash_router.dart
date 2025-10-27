// lib/routes/splash_router.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

/// A small splash router that only decides if onboarding is needed.
/// Auth redirection is handled by the main AppRouter.redirect logic.
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

    try {
      // 1. Check if onboarding has been seen
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_onboarding') ?? false;

      if (!seen) {
        if (!mounted) return;
        if (kDebugMode) debugPrint('SplashRouter: routing to onboarding');
        GoRouter.of(context).go(AppRoutes.onboarding);
      } else {
        if (!mounted) return;
        // 2. If onboarding IS seen, just go to the login route.
        // The AppRouter.redirect logic will IMMEDIATELY catch this.
        // - If user is Authenticated, redirect will send them to AppRoutes.home.
        // - If user is Unauthenticated, redirect will allow them to see AppRoutes.login.
        if (kDebugMode) debugPrint('SplashRouter: routing to login (AppRouter will redirect if needed)');
        GoRouter.of(context).go(AppRoutes.login);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SplashRouter: prefs error $e');
      if (mounted) {
        GoRouter.of(context).go(AppRoutes.login);
      }
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