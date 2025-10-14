// lib/features/worker_app/presentation/widgets/worker_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/routes/app_routes.dart';

class WorkerDashboardPage extends StatelessWidget {
  final Widget child;
  const WorkerDashboardPage({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.workerHome)) return 0;
    if (location.startsWith(AppRoutes.workerOrders)) return 1;
    if (location.startsWith(AppRoutes.workerProfile)) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go(AppRoutes.workerHome);
        break;
      case 1:
        GoRouter.of(context).go(AppRoutes.workerOrders);
        break;
      case 2:
        GoRouter.of(context).go(AppRoutes.workerProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          "assets/logos/ap_logo.png",
          fit: BoxFit.contain,
          height: 140,
        ),
        centerTitle: true,
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed, // Important for more than 3 items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'My Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}