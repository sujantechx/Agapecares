import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_bloc.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_state.dart';

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Profile')),
      body: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        if (state is Authenticated) {
          final user = state.user;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null ? const Icon(Icons.person, size: 48) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Name: ${user.name ?? '—'}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('Email: ${user.email ?? '—'}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Phone: ${user.phoneNumber ?? '—'}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Role: ${user.role.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: implement admin-specific profile editing flow.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit profile not implemented')));
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Optionally allow navigation to shared user profile if you need it.
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('To view shared profile, use User Profile screen')));
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Open User Profile (shared)'),
                ),
              ],
            ),
          );
        }

        if (state is AuthLoading || state is AuthInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You are not signed in.'),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
            ],
          ),
        );
      }),
    );
  }
}

