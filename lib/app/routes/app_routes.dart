// lib/routes/app_routes.dart

class AppRoutes {
  static const String home = '/home';
  static const String serviceDetail = '/service/:id';
  // alias for older/alternate usage
  static const String serviceDetails = serviceDetail;
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:id';
  static const String profile = '/profile';
  static const String login = '/auth/login';
  static const String otp = '/auth/otp';

  // Auth flow additional routes
  static const String register = '/auth/register';
  static const String phoneVerify = '/auth/phone-verify';
  static const String forgotPassword = '/auth/forgot';
  static const String phoneResetOtp = '/auth/reset-otp';
  static const String setNewPassword = '/auth/set-new-password';

  // Dashboard / misc
  static const String messages = '/messages';

  static const String workerHome = '/worker/home';
  static const String workerOrders = '/worker/orders';
  static const String workerOrderDetail = '/worker/orders/:id';
  static const String workerProfile = '/worker/profile';

  static const String adminDashboard = '/admin/dashboard';
  static const String adminServices = '/admin/services';
  static const String adminAddService = '/admin/services/add';
  static const String adminEditService = '/admin/services/edit';
  static const String adminOrders = '/admin/orders';
  static const String adminUsers = '/admin/users';
  static const String adminAssignWorker = '/admin/assign';

  // Main informational routes
  static const String aboutUs = '/about';
  static const String contactUs = '/contact';
  static const String cleaningServices = '/cleaning-services';
  static const String pestControl = '/pest-control';
  static const String blog = '/blog';
  static const String terms = '/terms';
}
