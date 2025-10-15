// Minimal WorkerProfilePage implementation to satisfy router references
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/routes/app_routes.dart';

class WorkerProfilePage extends StatelessWidget {
  const WorkerProfilePage({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    try {
      // Clear local session if available
      try {
        final session = context.read<SessionService>();
        await session.clear();
      } catch (_) {}
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[WorkerProfilePage] signOut failed: $e');
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

    final displayName = u?.name ?? 'Worker';
    final email = u?.email ?? 'Not provided';
    final phone = u?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
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
                    displayName.isNotEmpty ? displayName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join() : 'W',
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
                subtitle: Text(u?.role.name ?? UserRole.worker.name),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.history_edu_outlined),
                title: const Text('Created Services'),
                subtitle: const Text('View and manage services you created'),
                onTap: () {
                  // Navigate to create/service management if exists
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
