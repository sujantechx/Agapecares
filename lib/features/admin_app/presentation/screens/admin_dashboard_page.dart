// lib/features/admin_app/presentation/widgets/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_bloc.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_event.dart';

class AdminDashboardPage extends StatefulWidget {
  final Widget child;
  const AdminDashboardPage({super.key, required this.child});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // Keep a stable mapping of bottom navigation index to admin routes.
  static const _indexToRoute = <int, String>{
    0: AppRoutes.adminDashboard, // Home
    1: AppRoutes.adminServices, // Services
    2: AppRoutes.adminOrders, // Orders
    3: AppRoutes.adminUsers, // Users & Workers (tabbed)
    4: AppRoutes.adminProfile, // Admin-specific profile (separate from user profile)
  };

  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update selected index from current router location so the shell reflects navigation changes
    _currentIndex = _indexFromLocation(GoRouterState.of(context).uri.toString());
  }

  int _indexFromLocation(String location) {
    // Compare path startsWith to determine which tab is active. Order matters.
    if (location.startsWith('/admin/services')) return 1;
    if (location.startsWith('/admin/orders')) return 2;
    if (location.startsWith('/admin/users')) return 3;
    if (location.startsWith('/admin/profile')) return 4;
    // Default to admin home/dashboard
    return 0;
  }

  void _onTap(int index) {
    final route = _indexToRoute[index];
    if (route == null) return;
    if (_currentIndex == index) return; // avoid redundant navigation
    setState(() => _currentIndex = index);
    // Use go_router to navigate to the selected admin route
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
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
                // Sign out via AuthBloc so the central router (AppRouter) can
                // observe the auth state change and redirect appropriately.
                try {
                  context.read<AuthBloc>().add(AuthSignOutRequested());
                } catch (_) {
                  context.go(AppRoutes.login);
                }
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      ),
      // The router provides the actual page content in the `child` parameter.
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.miscellaneous_services), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}