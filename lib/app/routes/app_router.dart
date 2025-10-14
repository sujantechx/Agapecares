import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'public_routes.dart';
import 'user_routes.dart';
import 'worker_routes.dart';
import 'admin_routes.dart';

class AppRouter {
  // Lightweight, dependency-free router for now
  static GoRouter createRouter({String initialLocation = AppRoutes.home}) {
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

// Retain the class below if you later add auth-gated routing. Commented out imports were removed.
// class GoRouterRefreshStream extends ChangeNotifier {
//   late final StreamSubscription<dynamic> _subscription;
//   GoRouterRefreshStream(Stream<dynamic> stream) {
//     _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
//   }
//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }
// }
