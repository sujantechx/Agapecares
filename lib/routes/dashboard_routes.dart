import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../features/user_app/cart/presentation/cart_page.dart';
import '../features/user_app/presentation/pages/message_page.dart';
import '../features/user_app/presentation/pages/profile_page.dart';
import '../features/user_app/presentation/pages/user_home_page.dart';
import '../features/user_app/presentation/pages/order_list_page.dart';
// Use package imports for worker pages
import '../features/worker_app/presentation/pages/worker_orders_page.dart';
import '../features/worker_app/presentation/pages/worker_home_page.dart';
import '../features/worker_app/presentation/pages/worker_profile_page.dart';
import '../shared/widgets/dashboard_page.dart';
import 'app_routes.dart';

// New worker dashboard widget
import '../features/worker_app/presentation/widgets/worker_dashboard_page.dart';
// Note: worker widget imports are relative to avoid package resolution issues during analysis

final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _workerShellNavigatorKey = GlobalKey<NavigatorState>();

final List<RouteBase> dashboardRoutes = [
  // User-facing shell route (unchanged)
  ShellRoute(
    navigatorKey: _shellNavigatorKey,
    builder: (context, state, child) {
      return DashboardPage(child: child);
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => UserHomePage(),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartPage(),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrderListPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const UserProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        builder: (context, state) => const MessagePage(),
      ),
    ],
  ),

  // Worker-facing shell route (separate bottom nav & drawer)
  ShellRoute(
    navigatorKey: _workerShellNavigatorKey,
    builder: (context, state, child) {
      return WorkerDashboardPage(child: child);
    },
    routes: [
      GoRoute(
        path: AppRoutes.workerHome,
        builder: (context, state) => const WorkerHomePage(),
      ),
      GoRoute(
        path: AppRoutes.workerOrders,
        builder: (context, state) => const WorkerOrdersPage(),
      ),
      GoRoute(
        path: AppRoutes.workerProfile,
        builder: (context, state) => const WorkerProfilePage(),
      ),
    ],
  ),
];