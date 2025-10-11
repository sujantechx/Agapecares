// lib/features/user_app/presentation/pages/user_profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../routes/app_routes.dart';
import 'package:go_router/go_router.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _loading = true;
  UserModel? _userModel;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      // No user signed in - navigate to login
      if (mounted) GoRouter.of(context).go(AppRoutes.login);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        final um = UserModel.fromFirestore(data);
        if (mounted) setState(() => _userModel = um);
      } else {
        // If user doc not present, fall back to auth info and create a doc
        final fallback = UserModel(
          uid: firebaseUser.uid,
          phoneNumber: firebaseUser.phoneNumber ?? '',
          name: firebaseUser.displayName ?? '',
        );
        if (mounted) setState(() => _userModel = fallback);
        // create the doc for future
        await _firestore.collection('users').doc(firebaseUser.uid).set(fallback.toFirestore());
      }
    } catch (e) {
      // show error snackbar
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) GoRouter.of(context).go(AppRoutes.login);
  }

  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _userModel?.name ?? '');
    final emailCtrl = TextEditingController(text: _userModel?.toMap()['email'] as String? ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    // update Firestore
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final updatedMap = {
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      };
      await _firestore.collection('users').doc(uid).set(updatedMap, SetOptions(merge: true));
      // update local model
      setState(() {
        _userModel = _userModel?.copyWith(name: nameCtrl.text.trim()) ?? UserModel(uid: uid, phoneNumber: _auth.currentUser?.phoneNumber ?? '', name: nameCtrl.text.trim());
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
  }

  Widget _buildAvatar(String name) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join()
        : '?';

    return CircleAvatar(
      radius: 44,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      child: Text(initials, style: TextStyle(fontSize: 28, color: Theme.of(context).primaryColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(onPressed: _loadUser, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUser,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            _buildAvatar(_userModel?.name ?? ''),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_userModel?.name ?? 'Unnamed', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(_userModel?.toMap()['email'] as String? ?? 'No email', style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Text(_userModel?.phoneNumber ?? _auth.currentUser?.phoneNumber ?? 'No phone', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(onPressed: _showEditDialog, icon: const Icon(Icons.edit)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick actions
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.book_online),
                            title: const Text('My Bookings'),
                            subtitle: const Text('View your bookings and orders'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => GoRouter.of(context).go('/bookings'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: const Text('Account Settings'),
                            subtitle: const Text('Change password, notification preferences'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => GoRouter.of(context).go('/profile/settings'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}