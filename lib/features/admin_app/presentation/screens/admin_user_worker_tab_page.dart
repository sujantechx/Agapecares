import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/user_management/presentation/bloc/admin_user_bloc.dart';
import '../../features/worker_management/presentation/bloc/admin_worker_bloc.dart';
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

