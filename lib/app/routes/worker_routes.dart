import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/worker_app/presentation/widgets/worker_dashboard_page.dart';
import '../../features/worker_app/presentation/pages/worker_home_page.dart';
import '../../features/worker_app/presentation/pages/worker_orders_page.dart';
import '../../features/worker_app/presentation/pages/worker_profile_page.dart';
// TODO: Import your WorkerOrderDetailPage, etc.
import 'app_routes.dart';

final GlobalKey<NavigatorState> _workerShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'workerShell');

final List<RouteBase> workerRoutes = [
  // Worker Dashboard Shell Route
  ShellRoute(
    navigatorKey: _workerShellNavigatorKey,
    builder: (context, state, child) {
      return WorkerDashboardPage(child: child); // Your worker dashboard UI
    },
    routes: [
      GoRoute(path: AppRoutes.workerHome, builder: (context, state) => const WorkerHomePage()),
      GoRoute(path: AppRoutes.workerOrders, builder: (context, state) => const WorkerOrdersPage()),
      GoRoute(path: AppRoutes.workerProfile, builder: (context, state) => const WorkerProfilePage()),
    ],
  ),

  // Worker detail screens pushed on top of the dashboard
  // GoRoute(
  //   path: AppRoutes.workerOrderDetail,
  //   builder: (context, state) => WorkerOrderDetailPage(orderId: state.pathParameters['id']!),
  // ),
];