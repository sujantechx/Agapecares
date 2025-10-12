// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\widgets\worker_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agapecares/routes/app_routes.dart';
import 'package:agapecares/shared/services/session_service.dart';
import 'package:agapecares/shared/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkerDrawer extends StatelessWidget {
  const WorkerDrawer({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      // Clear session and sign out from Firebase
      try {
        final session = context.read<SessionService>();
        await session.clear();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // ignore
    }
    // Navigate to login
    if (context.mounted) GoRouter.of(context).go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                CircleAvatar(radius: 28, child: Icon(Icons.person, size: 32)),
                SizedBox(height: 8),
                Text('Worker', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              Navigator.of(context).pop();
              GoRouter.of(context).go(AppRoutes.workerHome);
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('Orders'),
            onTap: () {
              Navigator.of(context).pop();
              GoRouter.of(context).go(AppRoutes.workerOrders);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.of(context).pop();
              GoRouter.of(context).go(AppRoutes.workerProfile);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Logout'),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}

