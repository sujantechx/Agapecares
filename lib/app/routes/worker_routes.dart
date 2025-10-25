// Worker routes for the app
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';
import 'package:agapecares/features/worker_app/presentation/pages/worker_home_page.dart';
import 'package:agapecares/features/worker_app/presentation/pages/worker_orders_page.dart';
import 'package:agapecares/features/worker_app/presentation/pages/worker_order_detail_page.dart';
import 'package:agapecares/features/worker_app/presentation/pages/worker_profile_page.dart';
import 'package:agapecares/features/worker_app/presentation/widgets/worker_dashboard_page.dart';
import 'package:agapecares/features/worker_app/presentation/pages/worker_tasks_page.dart';

final List<RouteBase> workerRoutes = [
  ShellRoute(
    builder: (context, state, child) => WorkerDashboardPage(child: child),
    routes: [
      GoRoute(
        path: AppRoutes.workerHome,
        builder: (context, state) => const WorkerHomePage(),
      ),
      GoRoute(
        path: AppRoutes.workerTasks,
        builder: (context, state) => const WorkerTasksPage(),
      ),
      GoRoute(
        path: AppRoutes.workerOrders,
        builder: (context, state) => const WorkerOrdersPage(),
      ),
      GoRoute(
        path: AppRoutes.workerOrderDetail,
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? state.uri.queryParameters['id'] ?? '';
          return WorkerOrderDetailPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.workerProfile,
        builder: (context, state) => const WorkerProfilePage(),
      ),
    ],
  ),
];
