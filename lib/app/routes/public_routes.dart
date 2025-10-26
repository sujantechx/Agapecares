import 'package:agapecares/core/models/user_model.dart';
import 'package:go_router/go_router.dart';

import '../../features/common_auth/presentation/pages/login_page.dart';
import '../../features/common_auth/presentation/pages/register_page.dart';
import '../../features/common_auth/presentation/pages/phone_verify_page.dart';
import '../../features/common_auth/presentation/pages/forgot_password_page.dart';
import '../../features/common_auth/presentation/pages/onboarding_page.dart';
import 'splash_router.dart';
// TODO: Add imports for your SplashPage, ForgotPasswordPage, etc.
import 'app_routes.dart';

final List<RouteBase> publicRoutes = [
  // You can add your SplashScreen route here if you have one
  GoRoute(
    path: AppRoutes.splash,
    builder: (context, state) => const SplashRouter(),
  ),
  GoRoute(
    path: AppRoutes.onboarding,
    builder: (context, state) => const OnboardingPage(),
  ),
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginPage(),
  ),
  GoRoute(
    path: AppRoutes.register,
    builder: (context, state) => const RegisterPage(),
  ),
  GoRoute(
    path: AppRoutes.phoneVerify,
    builder: (context, state) {
      final extra = state.extra;
      String verificationId = '';
      String? name;
      String? email;
      String? phone;
      String? password;
      UserRole? role;
      if (extra is String) {
        verificationId = extra;
      } else if (extra is Map<String, dynamic>) {
        verificationId = extra['verificationId'] ?? '';
        name = extra['name'] as String?;
        email = extra['email'] as String?;
        phone = extra['phone'] as String?;
        password = extra['password'] as String?;
        final r = extra['role'];
        if (r is UserRole) role = r;
        if (r is String) {
          final normalized = r.trim().toLowerCase();
          if (normalized.contains('admin')) role = UserRole.admin;
          else if (normalized.contains('worker')) role = UserRole.worker;
          else role = UserRole.user;
        }
      }
      return PhoneVerifyPage(
        verificationId: verificationId,
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
    },
  ),
  GoRoute(
    path: AppRoutes.forgotPassword,
    builder: (context, state) => const ForgotPasswordPage(),
  ),
];
