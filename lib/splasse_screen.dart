import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import 'app/routes/app_routes.dart';

class SplasseScreen extends StatefulWidget {
  const SplasseScreen({super.key});

  @override
  State<SplasseScreen> createState() => _SplasseScreenState();
}

class _SplasseScreenState extends State<SplasseScreen> {
  // Timer used for the delayed navigation; kept so we can cancel it in dispose
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('SPLASH_DEBUG: SplasseScreen.initState called');
    // Delay briefly to show the splash, then decide which route to take.
    _navigationTimer = Timer(const Duration(milliseconds: 900), () async {
      debugPrint('SPLASH_DEBUG: Deciding navigation');
      // Check FirebaseAuth for a signed-in user
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('SPLASH_DEBUG: currentUser = ${user?.uid}');
      if (user == null) {
        if (!mounted) return;
        // No signed-in user -> go to login
        debugPrint('SPLASH_DEBUG: routing to login');
        context.go(AppRoutes.login);
        return;
      }
      // Try to read user role from Firestore; fall back to user dashboard
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        final role = (data != null && data['role'] is String) ? (data['role'] as String) : 'user';
        debugPrint('SPLASH_DEBUG: role = $role');
        if (!mounted) return;
        if (role.toLowerCase() == 'worker') {
          debugPrint('SPLASH_DEBUG: routing to workerHome');
          context.go(AppRoutes.workerHome);
        } else {
          debugPrint('SPLASH_DEBUG: routing to home');
          context.go(AppRoutes.home);
        }
      } catch (e, st) {
        debugPrint('SPLASH_DEBUG: error fetching role: $e\n$st');
        if (!mounted) return;
        context.go(AppRoutes.home);
      }
    });
  }

  @override
  void dispose() {
    // Cancel the navigation timer if it's still pending to avoid test failures
    _navigationTimer?.cancel();
    _navigationTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SPLASH_DEBUG: SplasseScreen.build');
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/logos/ap_logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Loading…', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
