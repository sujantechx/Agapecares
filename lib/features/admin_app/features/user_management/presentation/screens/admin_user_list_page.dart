import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_user_bloc.dart';
import '../bloc/admin_user_event.dart';
import '../bloc/admin_user_state.dart';

class AdminUserListPage extends StatelessWidget {
  const AdminUserListPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<AdminUserBloc>().add(LoadUsers());
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
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
                return ListTile(
                  title: Text(u.name ?? u.email ?? u.uid),
                  subtitle: Text('Role: ${u.role} • Verified: ${u.isVerified ? 'Yes' : 'No'}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'role:user':
                          context.read<AdminUserBloc>().add(UpdateUserRoleEvent(uid: u.uid, role: 'user'));
                          break;
                        case 'role:worker':
                          context.read<AdminUserBloc>().add(UpdateUserRoleEvent(uid: u.uid, role: 'worker'));
                          break;
                        case 'role:admin':
                          context.read<AdminUserBloc>().add(UpdateUserRoleEvent(uid: u.uid, role: 'admin'));
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
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'role:user', child: Text('Make User')),
                      PopupMenuItem(value: 'role:worker', child: Text('Make Worker')),
                      PopupMenuItem(value: 'role:admin', child: Text('Make Admin')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'verify', child: Text('Verify')),
                      PopupMenuItem(value: 'unverify', child: Text('Unverify')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'disable', child: Text('Disable')),
                      PopupMenuItem(value: 'enable', child: Text('Enable')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
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

