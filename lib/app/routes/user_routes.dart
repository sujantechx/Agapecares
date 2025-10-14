import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/user_app/presentation/widgets/dashboard_page.dart';
import '../../features/user_app/presentation/pages/user_home_page.dart';
import '../../features/user_app/cart/presentation/cart_page.dart';
import '../../features/user_app/orders/presentation/pages/order_list_page.dart';
import '../../features/user_app/presentation/pages/profile_page.dart';
// TODO: Import your ServiceDetailPage, CheckoutPage, OrderDetailPage, etc.
import 'app_routes.dart';

final GlobalKey<NavigatorState> _userShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'userShell');

final List<RouteBase> userRoutes = [
  // User Dashboard Shell Route
  ShellRoute(
    navigatorKey: _userShellNavigatorKey,
    builder: (context, state, child) {
      return DashboardPage(child: child); // Your user dashboard UI
    },
    routes: [
      GoRoute(path: AppRoutes.home, builder: (context, state) => const UserHomePage()),
      GoRoute(path: AppRoutes.cart, builder: (context, state) => const CartPage()),
      GoRoute(path: AppRoutes.orders, builder: (context, state) => const OrderListPage()),
      GoRoute(path: AppRoutes.profile, builder: (context, state) => const UserProfilePage()),
    ],
  ),

  // User screens that are pushed ON TOP of the dashboard (no bottom nav)
  // GoRoute(
  //   path: AppRoutes.serviceDetail,
  //   builder: (context, state) => ServiceDetailPage(serviceId: state.pathParameters['id']!),
  // ),
  // GoRoute(
  //   path: AppRoutes.checkout,
  //   builder: (context, state) => const CheckoutPage(),
  // ),
  // GoRoute(
  //   path: AppRoutes.orderDetail,
  //   builder: (context, state) => OrderDetailPage(orderId: state.pathParameters['id']!),
  // ),
];