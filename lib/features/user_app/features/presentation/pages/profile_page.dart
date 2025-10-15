import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/app/routes/app_routes.dart';

/// UserProfilePage - shows the currently saved session user and allows logout.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _addressController = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Load latest user doc from Firestore and update session/UI
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          String? uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            try {
              final session = context.read<SessionService>();
              uid = session.getUser()?.uid;
            } catch (_) {}
          }
          if (uid == null) return;
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (!doc.exists) return;
          final data = doc.data();
          if (data == null) return;

          // Update UI fields safely
          final fetchedName = data['name'] as String?;
          final fetchedEmail = data['email'] as String?;
          final fetchedPhone = (data['phoneNumber'] ?? data['phone']) as String?;
          final dynamic addr = (data['addresses'] is List && (data['addresses'] as List).isNotEmpty) ? (data['addresses'] as List).first : null;
          if (addr is String) _addressController.text = addr;
          else if (addr is Map && addr['address'] is String) _addressController.text = addr['address'] as String;

          // Update SessionService with freshest values
          try {
            final session = context.read<SessionService>();
            final cur = session.getUser();
            // Parse role from Firestore (string) into UserRole enum
            UserRole roleFromDoc = UserRole.user;
            try {
              final dynamic r = data['role'];
              if (r is String) roleFromDoc = UserRole.values.firstWhere((e) => e.name == r, orElse: () => UserRole.user);
            } catch (_) {
              roleFromDoc = UserRole.user;
            }
            final updated = UserModel(
              uid: uid,
              name: fetchedName ?? cur?.name,
              email: fetchedEmail ?? cur?.email,
              phoneNumber: fetchedPhone ?? cur?.phoneNumber,
              role: cur?.role ?? roleFromDoc,
              photoUrl: cur?.photoUrl,
              addresses: (data['addresses'] is List) ? List<Map<String, dynamic>>.from(data['addresses'] as List) : cur?.addresses,
              createdAt: cur?.createdAt ?? Timestamp.now(),
            );
            await session.saveUser(updated);
          } catch (_) {}
          if (mounted) setState(() {});
        } catch (_) {}
      });
    }
  }

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

  Future<void> _saveAddress(String address) async {
    setState(() => _isSaving = true);
    try {
      // Determine uid: prefer firebase currentUser, fallback to session
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        try {
          final session = context.read<SessionService>();
          final u = session.getUser();
          uid = u?.uid;
        } catch (_) {}
      }
      if (uid == null) throw Exception('User not logged in');

      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await userDoc.get();
      List<dynamic> addresses = [];
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['addresses'] is List) addresses = List<dynamic>.from(data['addresses']);
      }

      // Create a simple address entry - future: expand to structured address fields
      final newEntry = {'label': 'home', 'address': address};

      if (addresses.isNotEmpty) {
        // replace first entry
        addresses[0] = newEntry;
      } else {
        addresses.add(newEntry);
      }

      await userDoc.set({'addresses': addresses}, SetOptions(merge: true));

      // Update local session
      try {
        final session = context.read<SessionService>();
        final current = session.getUser();
        final updated = UserModel(
          uid: current?.uid ?? uid,
          name: current?.name,
          email: current?.email,
          phoneNumber: current?.phoneNumber,
          role: current?.role ?? UserRole.user,
          photoUrl: current?.photoUrl,
          addresses: addresses.cast<Map<String, dynamic>>(),
          createdAt: current?.createdAt ?? Timestamp.now(),
        );
        await session.saveUser(updated);
      } catch (_) {}

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save address: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
    final roleStr = u?.role.name ?? UserRole.user.name;

    // Pre-fill address controller with first saved address if available
    if (_addressController.text.isEmpty) {
      try {
        final dynamic addr = (u?.addresses != null && u!.addresses!.isNotEmpty) ? u.addresses!.first : null;
        if (addr != null) {
          if (addr is String) _addressController.text = addr;
          else if (addr is Map && addr['address'] is String) _addressController.text = addr['address'] as String;
        }
      } catch (_) {}
    }

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
                subtitle: Text(roleStr),
              ),
            ),
            const SizedBox(height: 12),
            // Address editor
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Primary Address',
                hintText: 'Enter your address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveAddress(_addressController.text.trim()),
                  child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Address'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Go to orders
                    GoRouter.of(context).go(AppRoutes.orders);
                  },
                  child: const Text('My Orders'),
                ),
              ],
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
