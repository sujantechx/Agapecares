import 'package:go_router/go_router.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import 'app_routes.dart';

/// Defines the routes for the authentication flow.
final List<RouteBase> authRoutes = [
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginPage(),
  ),
  GoRoute(
    path: AppRoutes.otp,
    builder: (context, state) {
      // Safely cast the extra data to a String.
      final phoneNumber = state.extra as String? ?? 'No number provided';
      return OtpPage(phoneNumber: phoneNumber);
    },
  ),
];