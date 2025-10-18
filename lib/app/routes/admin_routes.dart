import 'package:flutter/material.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_services_main_page.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_add_edit_service_screen.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/screens/admin_order_list_page.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_user_worker_tab_page.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_dashboard_page.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'app_routes.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_home.dart';
import '../../features/admin_app/presentation/screens/admin_profile.dart';

/// NOTE:
/// Route protection (admin-only) is handled by `AppRouter.redirect`. Builders
/// should provide the admin shell (`AdminDashboardPage`) with the appropriate
/// child content widget. Avoid wrapping in additional guards to prevent
/// double-wrapping and accidental recursion.

final List<RouteBase> adminRoutes = [
  GoRoute(
    path: AppRoutes.adminDashboard,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: AdminDashboardPage(child: const AdminHomePage()),
    ),
  ),
  GoRoute(
    path: AppRoutes.adminServices,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: AdminDashboardPage(child: const AdminServicesMainPage()),
    ),
  ),

  GoRoute(
    path: AppRoutes.adminAddService,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: AdminDashboardPage(child: const AdminAddEditServiceScreen()),
    ),
  ),
  GoRoute(
    path: AppRoutes.adminEditService,
    pageBuilder: (context, state) {
      final service = state.extra as ServiceModel?;
      return MaterialPage(
        key: state.pageKey,
        child: AdminDashboardPage(child: AdminAddEditServiceScreen(service: service)),
      );
    },
  ),
  GoRoute(
    path: AppRoutes.adminOrders,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: AdminDashboardPage(child: const AdminOrderListPage()),
    ),
  ),
  GoRoute(
    path: AppRoutes.adminUsers,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: AdminDashboardPage(child: const AdminUserWorkerTabPage()),
    ),
  ),
  // Admin-specific profile route (separate from shared user profile)
  GoRoute(
    path: AppRoutes.adminProfile,
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: AdminDashboardPage(child: const AdminProfilePage()),
    ),
  ),
];