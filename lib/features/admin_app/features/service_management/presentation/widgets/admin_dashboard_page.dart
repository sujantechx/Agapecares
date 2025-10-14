// lib/features/admin_app/presentation/widgets/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';

class AdminDashboardPage extends StatelessWidget {
  final Widget child;
  const AdminDashboardPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      // A Drawer is more scalable for admin panels
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text('Agape Cares Admin',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => context.go(AppRoutes.adminDashboard),
            ),
            ListTile(
              leading: const Icon(Icons.miscellaneous_services),
              title: const Text('Services'),
              onTap: () => context.go(AppRoutes.adminServices),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('Orders'),
              onTap: () => context.go(AppRoutes.adminOrders),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users & Workers'),
              onTap: () => context.go(AppRoutes.adminUsers),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                // TODO: Add Logout Logic (call AuthBloc/AuthRepository)
                context.go(AppRoutes.login);
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}