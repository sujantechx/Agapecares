import 'package:go_router/go_router.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/phone_verify_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/phone_reset_otp_page.dart';
import '../features/auth/presentation/pages/set_new_password_page.dart';
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
  GoRoute(
    path: AppRoutes.register,
    builder: (context, state) => const RegisterPage(),
  ),
  GoRoute(
    path: AppRoutes.phoneVerify,
    builder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      final verificationId = extra?['verificationId'] as String? ?? '';
      final phone = extra?['phone'] as String? ?? '';
      final name = extra?['name'] as String?;
      final email = extra?['email'] as String?;
      return PhoneVerifyPage(verificationId: verificationId, phone: phone, name: name, email: email);
    },
  ),
  GoRoute(
    path: AppRoutes.forgotPassword,
    builder: (context, state) => const ForgotPasswordPage(),
  ),
  GoRoute(
    path: AppRoutes.phoneResetOtp,
    builder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      final verificationId = extra?['verificationId'] as String? ?? '';
      final phone = extra?['phone'] as String? ?? '';
      return PhoneResetOtpPage(verificationId: verificationId, phone: phone);
    },
  ),
  GoRoute(
    path: AppRoutes.setNewPassword,
    builder: (context, state) => const SetNewPasswordPage(),
  ),
];