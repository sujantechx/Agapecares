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
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      routes: [
        ...publicRoutes,
        ...userRoutes,
        ...workerRoutes,
        // Assuming this was a typo and you mean worker_routes
        ...adminRoutes,
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final authState = authBloc.state;
        final location = state.matchedLocation;
        if (kDebugMode) debugPrint('AppRouter.redirect: authState=$authState location=$location');

        // Define which routes are public
        const publicPaths = [
          AppRoutes.splash,
          AppRoutes.onboarding,
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.phoneVerify,
          AppRoutes.forgotPassword, // Add forgot password
          AppRoutes.setNewPassword, // Add set new password
        ];
        final isPublicRoute = publicPaths.contains(location);

        // --- NEW REDIRECTION LOGIC ---

        // 1. If auth state is unknown (e.g., app just started)
        if (authState is AuthInitial) {
          if (kDebugMode) debugPrint('AppRouter.redirect -> stay on splash (auth initial)');
          // Stay on splash, the SplashRouter will decide where to go
          return (location == AppRoutes.splash) ? null : AppRoutes.splash;
        }

        // 2. If auth state is loading
        if (authState is AuthLoading) {
          // If we are on a public route (like login/register), STAY there.
          // This allows loading indicators to show on the page.
          if (isPublicRoute) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> stay on public route (auth loading)');
            return null;
          }
          // If we are on a protected route, go to splash.
          if (kDebugMode) debugPrint('AppRouter.redirect -> on protected route, go to splash (auth loading)');
          return AppRoutes.splash;
        }

        // 3. If the user is authenticated.
        if (authState is Authenticated) {
          final user = authState.user;

          // If logged in, redirect from public routes to dashboard.
          if (isPublicRoute) {
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

          // Role-based protection
          if (location.startsWith('/admin') && user.role != UserRole.admin) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> non-admin tried admin route, redirect home');
            return AppRoutes.home;
          }
          if (location.startsWith('/worker') && user.role != UserRole.worker) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> non-worker tried worker route, redirect home');
            return AppRoutes.home;
          }
        }

        // 4. If the user is unauthenticated.
        if (authState is Unauthenticated || authState is AuthFailure || authState is AuthEmailVerificationSent) {
          // If they are on a protected route, redirect to login.
          if (!isPublicRoute) {
            if (kDebugMode) debugPrint('AppRouter.redirect -> unauthenticated user accessing protected route, redirect to login');
            return AppRoutes.login;
          }
        }

        // 5. No redirection needed.
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