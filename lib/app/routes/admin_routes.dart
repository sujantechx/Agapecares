import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_add_edit_service_screen.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_service_list_page.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/screens/admin_order_list_page.dart';
import 'package:agapecares/features/admin_app/presentation/screens/admin_user_worker_tab_page.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/widgets/admin_dashboard_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'app_routes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:agapecares/core/models/user_model.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Admin Dashboard')));
  }
}

/// Widget that checks if the current signed-in user has the admin role.
/// If not signed-in -> redirect to login. If signed-in but not admin -> redirect to home.
class AdminAuthGuard extends StatefulWidget {
  final Widget child;
  const AdminAuthGuard({Key? key, required this.child}) : super(key: key);

  @override
  State<AdminAuthGuard> createState() => _AdminAuthGuardState();
}

class _AdminAuthGuardState extends State<AdminAuthGuard> {
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      // Fast path: check locally-cached session if available to avoid extra network reads.
      try {
        final session = context.read<SessionService>();
        final cached = session.getUser();
        if (cached != null) {
          if (cached.role == UserRole.admin) {
            if (mounted) setState(() {
              _allowed = true;
              _loading = false;
            });
            return;
          } else {
            if (mounted) GoRouter.of(context).go(AppRoutes.home);
            return;
          }
        }
      } catch (_) {
        // No SessionService provided; continue to check via Firebase.
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not signed in -> go to login
        if (context.mounted) GoRouter.of(context).go(AppRoutes.login);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        if (context.mounted) GoRouter.of(context).go(AppRoutes.home);
        return;
      }
      // Use DocumentSnapshot.get to avoid unnecessary cast warnings
      String roleStr = UserRole.user.name;
      try {
        final dynamic r = doc.get('role');
        if (r is String) roleStr = r;
      } catch (_) {
        roleStr = UserRole.user.name;
      }
      final savedRole = UserRole.values.firstWhere((e) => e.name == roleStr, orElse: () => UserRole.user);
      if (savedRole == UserRole.admin) {
        if (mounted) setState(() {
          _allowed = true;
          _loading = false;
        });
      } else {
        // Signed in but not admin
        if (context.mounted) GoRouter.of(context).go(AppRoutes.home);
      }
    } catch (e) {
      // On error, redirect to login for safety.
      if (context.mounted) GoRouter.of(context).go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_allowed) return const SizedBox.shrink();
    // Allowed -> show child inside AdminDashboardPage shell
    return AdminDashboardPage(child: widget.child);
  }
}

final List<RouteBase> adminRoutes = [
  // The protection logic is handled centrally by the router's redirect callback.
  // No more AdminAuthGuard widgets needed!
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
    builder: (context, state) => const AdminAuthGuard(child: AdminAddEditServiceScreen()),
  ),
  GoRoute(
    path: AppRoutes.adminEditService,
    builder: (context, state) {
      final service = state.extra as ServiceModel?;
      return AdminAuthGuard(child: AdminAddEditServiceScreen(service: service));
    },
  ),
  GoRoute(
    path: AppRoutes.adminOrders,
    builder: (context, state) => const AdminAuthGuard(child: AdminOrderListPage()),
  ),
  GoRoute(
    path: AppRoutes.adminUsers,
    builder: (context, state) => const AdminAuthGuard(child: AdminUserWorkerTabPage()),
  ),
];