import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Prefer package imports so analyzer can resolve symbols reliably.
import 'package:agapecares/features/user_app/features/presentation/widgets/dashboard_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/user_home_page.dart';
import 'package:agapecares/features/user_app/features/cart/presentation/cart_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/order_list_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/profile_page.dart';
import 'package:agapecares/app/routes/app_routes.dart';

// Additional user pages
import 'package:agapecares/features/user_app/features/presentation/pages/cleaning_services_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/service_detail_page.dart';

final GlobalKey<NavigatorState> _userShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'userShell');

final List<RouteBase> userRoutes = [
  // User Dashboard Shell Route
  ShellRoute(
    navigatorKey: _userShellNavigatorKey,
    builder: (context, state, child) {
      return DashboardPage(child: child); // Your user dashboard UI
    },
    routes: [
      GoRoute(path: AppRoutes.home, builder: (context, state) => UserHomePage()),
      GoRoute(path: AppRoutes.cart, builder: (context, state) => CartPage()),
      GoRoute(path: AppRoutes.orders, builder: (context, state) => OrderListPage()),
      GoRoute(path: AppRoutes.profile, builder: (context, state) => UserProfilePage()),
      // Add cleaning services as a route inside the dashboard shell so it shows within the bottom-nav scaffold
      GoRoute(path: AppRoutes.cleaningServices, builder: (context, state) => const CleaningServicesPage()),
    ],
  ),

  // Service detail and other full-screen user pages that should be pushed on top of the dashboard
  GoRoute(
    path: AppRoutes.serviceDetail,
    builder: (context, state) => ServiceDetailPage(serviceId: state.pathParameters['id']!),
  ),
];