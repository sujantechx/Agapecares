import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text('Welcome, Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Overview'),
              subtitle: const Text('Quick stats and recent activity'),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.miscellaneous_services),
              title: const Text('Manage Services'),
              subtitle: const Text('Add or edit cleaning services'),
              onTap: () => context.go(AppRoutes.adminServices),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: const Text('Orders'),
              subtitle: const Text('View and manage orders'),
              onTap: () => context.go(AppRoutes.adminOrders),
            ),
          ),
        ],
      ),
    );
  }
}
