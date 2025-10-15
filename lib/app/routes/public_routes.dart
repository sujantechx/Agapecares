import 'package:go_router/go_router.dart';

import '../../features/common_auth/presentation/pages/login_page.dart';
import '../../features/common_auth/presentation/pages/register_page.dart';
import '../../features/common_auth/presentation/pages/phone_verify_page.dart';
import '../../splasse_screen.dart';
// TODO: Add imports for your SplashPage, ForgotPasswordPage, etc.
import 'app_routes.dart';

final List<RouteBase> publicRoutes = [
  // You can add your SplashScreen route here if you have one
  GoRoute(
    path: AppRoutes.splash,
    builder: (context, state) => const SplasseScreen(),
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
      if (extra is String) {
        verificationId = extra;
      } else if (extra is Map<String, dynamic>) {
        verificationId = extra['verificationId'] ?? '';
      }
      return PhoneVerifyPage(
        verificationId: verificationId,
      );
    },
  ),
  // TODO: Add other public routes like ForgotPassword
  // GoRoute(
  //   path: AppRoutes.forgotPassword,
  //   builder: (context, state) => const ForgotPasswordPage(),
  // ),
];
