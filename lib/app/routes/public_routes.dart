import 'package:go_router/go_router.dart';

import '../../features/common_auth/presentation/pages/login_page.dart';
import '../../features/common_auth/presentation/pages/register_page.dart';
// TODO: Add imports for your SplashPage, ForgotPasswordPage, etc.
import 'app_routes.dart';

final List<RouteBase> publicRoutes = [
  // You can add your SplashScreen route here if you have one
  // GoRoute(
  //   path: '/splash',
  //   builder: (context, state) => const SplashScreen(),
  // ),
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginPage(),
  ),
  GoRoute(
    path: AppRoutes.register,
    builder: (context, state) => const RegisterPage(),
  ),
  // TODO: Add other public routes like ForgotPassword
  // GoRoute(
  //   path: AppRoutes.forgotPassword,
  //   builder: (context, state) => const ForgotPasswordPage(),
  // ),
];
