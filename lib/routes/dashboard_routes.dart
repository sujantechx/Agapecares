import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
// 🎯 Import the CartPage

import '../features/user_app/cart/presentation/cart_page.dart';
import '../features/user_app/presentation/pages/message_page.dart';
import '../features/user_app/presentation/pages/profile_page.dart';
import '../features/user_app/presentation/pages/user_home_page.dart';
import '../shared/widgets/dashboard_page.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final List<RouteBase> dashboardRoutes = [
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
      // 🎯 ADD THE CART ROUTE HERE
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartPage(),
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
];