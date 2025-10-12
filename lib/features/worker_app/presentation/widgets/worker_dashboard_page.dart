// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\widgets\worker_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/routes/app_routes.dart';
import 'package:agapecares/shared/theme/app_theme.dart';
import 'worker_drawer.dart';

/// A simple Shell widget used by the worker ShellRoute.
/// It shows a worker-focused BottomNavigationBar with two tabs:
/// - Home -> `AppRoutes.workerHome`
/// - Profile -> `AppRoutes.workerProfile`
/// The nested `child` provided by GoRouter is rendered above the BottomNavigationBar.
class WorkerDashboardPage extends StatelessWidget {
  final Widget child;
  const WorkerDashboardPage({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.workerProfile)) return 1;
    // Default to workerHome for any other worker route (including workerOrders)
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go(AppRoutes.workerHome);
        break;
      case 1:
        GoRouter.of(context).go(AppRoutes.workerProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker'),
        centerTitle: true,
        elevation: 0,
      ),
      // Worker-specific drawer
      drawer: const WorkerDrawer(),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => _onItemTapped(i, context),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.subtitleColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
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
