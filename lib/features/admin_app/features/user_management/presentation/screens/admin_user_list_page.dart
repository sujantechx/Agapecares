// Admin User List Page
// Purpose: Presentation UI to display users and perform admin actions (change role, verify, disable, delete).
// Notes: Reads `UserModel` and triggers `AdminUserBloc` events; does not change models.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/user_model.dart';
import '../bloc/admin_user_bloc.dart';
import '../bloc/admin_user_event.dart';
import '../bloc/admin_user_state.dart';

class AdminUserListPage extends StatefulWidget {
  const AdminUserListPage({super.key});

  @override
  State<AdminUserListPage> createState() => _AdminUserListPageState();
}

class _AdminUserListPageState extends State<AdminUserListPage> {
  UserRole? _filterRole;

  @override
  void initState() {
    super.initState();
    // load initial unfiltered list
    context.read<AdminUserBloc>().add(LoadUsers());
  }

  void _onRoleChanged(UserRole? role) {
    setState(() => _filterRole = role);
    context.read<AdminUserBloc>().add(LoadUsers(role: role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UserRole?>(
                value: _filterRole,
                hint: const Text('Filter'),
                items: [
                  const DropdownMenuItem<UserRole?>(value: null, child: Text('All')),
                  DropdownMenuItem<UserRole?>(value: UserRole.user, child: const Text('Customers')),
                  DropdownMenuItem<UserRole?>(value: UserRole.worker, child: const Text('Workers')),
                  DropdownMenuItem<UserRole?>(value: UserRole.admin, child: const Text('Admins')),
                ],
                onChanged: _onRoleChanged,
                dropdownColor: Theme.of(context).appBarTheme.backgroundColor,
                style: Theme.of(context).appBarTheme.toolbarTextStyle?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white),
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.read<AdminUserBloc>().add(LoadUsers(role: _filterRole)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<AdminUserBloc, AdminUserState>(
        builder: (context, state) {
          if (state is AdminUserLoading) return const Center(child: CircularProgressIndicator());
          if (state is AdminUserError) return Center(child: Text('Error: ${state.message}'));
          if (state is AdminUserLoaded) {
            if (state.users.isEmpty) return const Center(child: Text('No users'));
            return ListView.builder(
              itemCount: state.users.length,
              itemBuilder: (context, i) {
                final u = state.users[i];
                // Fetch the latest flags (isVerified / disabled) from Firestore per user so UI reflects exact stored state.
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('users').doc(u.uid).get(),
                  builder: (context, snap) {
                    bool isVerified = false;
                    bool disabled = false;
                    if (snap.hasData && snap.data!.exists) {
                      final data = snap.data!.data();
                      isVerified = data?['isVerified'] as bool? ?? false;
                      disabled = data?['disabled'] as bool? ?? false;
                    }
                    return ListTile(
                      title: Text(u.name ?? u.email ?? u.uid),
                      subtitle: Text('Role: ${u.role.name} • Verified: ${isVerified ? 'Yes' : 'No'} • Disabled: ${disabled ? 'Yes' : 'No'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'role:user':
                              context.read<AdminUserBloc>().add(UpdateUserRoleEvent(uid: u.uid, role: UserRole.user));
                              break;
                            case 'role:worker':
                              context.read<AdminUserBloc>().add(UpdateUserRoleEvent(uid: u.uid, role: UserRole.worker));
                              break;
                            case 'role:admin':
                              context.read<AdminUserBloc>().add(UpdateUserRoleEvent(uid: u.uid, role: UserRole.admin));
                              break;
                            case 'verify':
                              context.read<AdminUserBloc>().add(SetUserVerificationEvent(uid: u.uid, isVerified: true));
                              break;
                            case 'unverify':
                              context.read<AdminUserBloc>().add(SetUserVerificationEvent(uid: u.uid, isVerified: false));
                              break;
                            case 'disable':
                              context.read<AdminUserBloc>().add(SetUserDisabledEvent(uid: u.uid, disabled: true));
                              break;
                            case 'enable':
                              context.read<AdminUserBloc>().add(SetUserDisabledEvent(uid: u.uid, disabled: false));
                              break;
                            case 'delete':
                              context.read<AdminUserBloc>().add(DeleteUserEvent(u.uid));
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'role:user', child: Text('Make User')),
                          const PopupMenuItem(value: 'role:worker', child: Text('Make Worker')),
                          const PopupMenuItem(value: 'role:admin', child: Text('Make Admin')),
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'verify', child: Text(isVerified ? 'Already Verified' : 'Verify')),
                          PopupMenuItem(value: 'unverify', child: Text(isVerified ? 'Unverify' : 'Not Verified')),
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'disable', child: Text(disabled ? 'Already Disabled' : 'Disable')),
                          PopupMenuItem(value: 'enable', child: Text(disabled ? 'Enable' : 'Already Enabled')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
