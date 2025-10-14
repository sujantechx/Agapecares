import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_add_edit_service_screen.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_service_list_page.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_order_list_page.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_user_worker_tab_page.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'app_routes.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Admin Dashboard')));
  }
}

final List<RouteBase> adminRoutes = [
  GoRoute(
    path: AppRoutes.adminDashboard,
    builder: (context, state) => const AdminDashboardScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminServices,
    builder: (context, state) => const AdminServiceListScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminAddService,
    builder: (context, state) => const AdminAddEditServiceScreen(),
  ),
  GoRoute(
    path: AppRoutes.adminEditService,
    builder: (context, state) {
      final service = state.extra as ServiceModel?;
      return AdminAddEditServiceScreen(service: service);
    },
  ),
  GoRoute(
    path: AppRoutes.adminOrders,
    builder: (context, state) => const AdminOrderListPage(),
  ),
  GoRoute(
    path: AppRoutes.adminUsers,
    builder: (context, state) => const AdminUserWorkerTabPage(),
  ),
];