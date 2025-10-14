import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/routes/app_routes.dart';

/// UserProfilePage - shows the currently saved session user and allows logout.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    try {
      try {
        final session = context.read<SessionService>();
        await session.clear();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // ignore errors; proceed to navigate to login
    }
    if (context.mounted) GoRouter.of(context).go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    UserModel? u;
    try {
      final session = context.read<SessionService>();
      u = session.getUser();
    } catch (_) {
      u = null;
    }

    final displayName = u?.name ?? 'Guest User';
    final email = u?.email ?? 'Not provided';
    final phone = u?.phoneNumber ?? '';
    final role = u?.role ?? 'user';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    displayName.isNotEmpty ? displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join() : 'G',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(email),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(phone),
                      ],
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Role'),
                subtitle: Text(role),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_edu_outlined),
                title: const Text('Orders'),
                subtitle: const Text('View your past orders'),
                onTap: () {
                  GoRouter.of(context).go(AppRoutes.orders);
                },
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Backwards-compatible alias for older imports
class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const UserProfilePage();
}
