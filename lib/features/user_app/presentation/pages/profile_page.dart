import 'package:flutter/material.dart';

// Added simple UserProfilePage and ProfilePage widgets used by router and dashboard routes
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('User Profile Page')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Reuse the UserProfilePage UI for backwards compatibility
    return const UserProfilePage();
  }
}
