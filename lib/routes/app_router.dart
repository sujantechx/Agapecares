import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Import the route constants and the separated route lists
import 'app_routes.dart';
import 'auth_routes.dart';
import 'dashboard_routes.dart';
import 'main_routes.dart';

class AppRouter {
  /// A private key for the root navigator.
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// The main GoRouter instance for the application.
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    navigatorKey: _rootNavigatorKey,
    routes: [
      // Use the spread operator '...' to combine all route lists.
      ...authRoutes,
      ...dashboardRoutes,
      ...mainRoutes,
    ],
    // Optional: Add error handling for routes that are not found.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text('Error: ${state.error?.message}'),
      ),
    ),
  );
}