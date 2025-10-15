import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_add_edit_service_screen.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_service_list_page.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_order_list_page.dart';
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
    builder: (context, state) => AdminDashboardPage(child: const AdminHomePage()),
  ),
  GoRoute(
    path: AppRoutes.adminServices,
    builder: (context, state) => AdminDashboardPage(child: const AdminServiceListScreen()),
  ),

  GoRoute(
    path: AppRoutes.adminAddService,
    builder: (context, state) => AdminDashboardPage(child: const AdminAddEditServiceScreen()),
  ),
  GoRoute(
    path: AppRoutes.adminEditService,
    builder: (context, state) {
      final service = state.extra as ServiceModel?;
      return AdminDashboardPage(child: AdminAddEditServiceScreen(service: service));
    },
  ),
  GoRoute(
    path: AppRoutes.adminOrders,
    builder: (context, state) => AdminDashboardPage(child: const AdminOrderListPage()),
  ),
  GoRoute(
    path: AppRoutes.adminUsers,
    builder: (context, state) => AdminDashboardPage(child: const AdminUserWorkerTabPage()),
  ),
  // Admin-specific profile route (separate from shared user profile)
  GoRoute(
    path: AppRoutes.adminProfile,
    builder: (context, state) => AdminDashboardPage(child: const AdminProfilePage()),
  ),
];