// lib/routes/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:go_router/go_router.dart';

import '../../features/common_auth/logic/blocs/auth_bloc.dart';
import '../../features/common_auth/logic/blocs/auth_state.dart';
import '../../core/models/user_model.dart';
import 'app_routes.dart';
import 'public_routes.dart';
import 'user_routes.dart';
import 'worker_routes.dart';
import 'admin_routes.dart';

class AppRouter {
  final AuthBloc authBloc;

  AppRouter({required this.authBloc});

  GoRouter createRouter() {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      // The refreshListenable makes the router rebuild when the auth state changes.
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: [
        ...publicRoutes,
        ...userRoutes,
        ...workerRoutes,
        ...adminRoutes,
      ],
      // The redirect callback is the single source of truth for navigation logic.
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        final location = state.matchedLocation;
        if (kDebugMode) debugPrint('AppRouter.redirect: authState=$authState location=$location');

        // Define which routes are public using explicit path list (avoids RouteBase API differences).
        const publicPaths = [AppRoutes.splash, AppRoutes.onboarding, AppRoutes.login, AppRoutes.register, AppRoutes.phoneVerify];
        final isPublicRoute = publicPaths.contains(location);

        // --- REDIRECTION LOGIC ---

        // 1. If the auth state is unknown (e.g., app just started), stay on the splash screen.
        if (authState is AuthInitial || authState is AuthLoading) {
          if (kDebugMode) debugPrint('AppRouter.redirect -> splash (auth unknown/loading)');
          return AppRoutes.splash;
        }

        // 2. If the user is authenticated.
        if (authState is Authenticated) {
          final user = authState.user;

          // If the user tries to access a public route (like login/register) while logged in,
          // redirect them to their respective dashboard.
          if (isPublicRoute || location == AppRoutes.splash) {
            switch (user.role) {
              case UserRole.admin:
                if (kDebugMode) debugPrint('AppRouter.redirect -> adminDashboard');
                return AppRoutes.adminDashboard;
              case UserRole.worker:
                if (kDebugMode) debugPrint('AppRouter.redirect -> workerHome');
                return AppRoutes.workerHome;
              default:
                if (kDebugMode) debugPrint('AppRouter.redirect -> home');
                return AppRoutes.home;
            }
          }

          // Role-based protection:
          // If a non-admin tries to access an admin route, redirect them.
          if (location.startsWith('/admin') && user.role != UserRole.admin) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> non-admin tried admin route, redirect home');
            return AppRoutes.home; // Or show an "Access Denied" page
          }
          // If a non-worker tries to access a worker route, redirect them.
          if (location.startsWith('/worker') && user.role != UserRole.worker) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> non-worker tried worker route, redirect home');
            return AppRoutes.home; // Or show an "Access Denied" page
          }
        }

        // 3. If the user is unauthenticated.
        if (authState is Unauthenticated) {
          // If they is trying to access a protected route, redirect to login.
          if (!isPublicRoute) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> unauthenticated user accessing protected route, redirect to login');
            return AppRoutes.login;
          }
        }

        // 4. No redirection needed, continue to the intended route.
        if (kDebugMode) debugPrint('AppRouter.redirect -> no redirection');
        return null;
      },
    );
  }
}

/// A utility class to convert a BLoC stream into a Listenable for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}