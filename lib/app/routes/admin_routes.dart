import 'package:flutter/material.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_services_main_page.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_add_edit_service_screen.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/screens/admin_order_list_page.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_user_worker_tab_page.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_dashboard_page.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/core/models/service_model.dart';
import '../../features/admin_app/features/order_management/presentation/pages/admin_order_detail_page.dart';
import 'app_routes.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_home.dart';
import '../../features/admin_app/presentation/screens/admin_profile.dart';
import 'package:agapecares/features/admin_app/features/user_management/presentation/screens/admin_user_details_page.dart';
import 'package:agapecares/features/admin_app/features/worker_management/presentation/screens/admin_worker_details_page.dart';
import 'package:agapecares/core/models/order_model.dart';

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
  // Admin user detail route (shows details inside AdminDashboard shell)
  GoRoute(
    path: AppRoutes.adminUserDetail,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return MaterialPage(
        key: state.pageKey,
        child: AdminDashboardPage(child: AdminUserDetailsPage(uid: id)),
      );
    },
  ),
  // Admin worker detail route
  GoRoute(
    path: AppRoutes.adminWorkerDetail,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return MaterialPage(
        key: state.pageKey,
        child: AdminDashboardPage(child: AdminWorkerDetailsPage(uid: id)),
      );
    },
  ),
  // Admin: view all orders for a specific user
  GoRoute(
    path: AppRoutes.adminUserOrders,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final filters = {'orderOwner': id};
      return MaterialPage(
        key: state.pageKey,
        child: AdminDashboardPage(child: AdminOrderListPage(initialFilters: filters)),
      );
    },
  ),
  // Admin: view all orders assigned to a specific worker
  GoRoute(
    path: AppRoutes.adminWorkerOrders,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      final filters = {'workerId': id};
      return MaterialPage(
        key: state.pageKey,
        child: AdminDashboardPage(child: AdminOrderListPage(initialFilters: filters)),
      );
    },
  ),
  // Admin order detail route
  GoRoute(
    path: AppRoutes.adminOrderDetail,
    pageBuilder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      // If caller passed the OrderModel via extra, use it. Otherwise attempt to fetch via repo inside the detail page
      final extra = state.extra;
      if (extra != null && extra is OrderModel) {
        final OrderModel order = extra as OrderModel;
        return MaterialPage(
          key: state.pageKey,
          child: AdminDashboardPage(child: AdminOrderDetailPage(order: order)),
        );
      }
      // Fallback: try to load order by id in the detail page - the page currently expects an OrderModel, so try to navigate to a minimal scaffold that fetches it
      return MaterialPage(
        key: state.pageKey,
        child: AdminDashboardPage(child: Builder(builder: (ctx) => Center(child: Text('Order detail for id: $id (not preloaded)')))),
      );
    },
  ),
];