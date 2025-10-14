import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'public_routes.dart';
import 'user_routes.dart';
import 'worker_routes.dart';
import 'admin_routes.dart';

class AppRouter {
  // Lightweight, dependency-free router for now
  static GoRouter createRouter({String initialLocation = AppRoutes.splash}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ...publicRoutes,
        ...userRoutes,
        ...workerRoutes,
        ...adminRoutes,
      ],
    );
  }
}



