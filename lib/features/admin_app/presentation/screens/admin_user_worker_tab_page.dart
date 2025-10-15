// Admin app: Tab screen to switch between admin user and worker lists.
// Purpose: Presentation widget that hosts admin user and worker management tabs.
// Note: Updated to align with the project's `UserModel` and routing — no model changes applied.

import 'package:flutter/material.dart';
import '../../features/user_management/presentation/screens/admin_user_list_page.dart';
import '../../features/worker_management/presentation/screens/admin_worker_list_page.dart';

class AdminUserWorkerTabPage extends StatelessWidget {
  const AdminUserWorkerTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Users & Workers'),
          bottom: const TabBar(tabs: [Tab(text: 'Users'), Tab(text: 'Workers')]),
        ),
        body: const TabBarView(children: [
          AdminUserListPage(),
          AdminWorkerListPage(),
        ]),
      ),
    );
  }
}
