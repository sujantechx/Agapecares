/// A central class for all route paths in the application.
/// Using constants for route paths is a best practice to avoid typos
/// and to have a single source of truth for your navigation paths.
class AppRoutes {
  // --- Authentication Flow ---
  static const String login = '/login';
  static const String otp = '/otp';
  static const String register = '/register';
  static const String phoneVerify = '/phone-verify';
  static const String forgotPassword = '/forgot-password';
  static const String phoneResetOtp = '/phone-reset-otp';
  static const String setNewPassword = '/set-new-password';

  // --- Main App Shell (Dashboard) Routes ---
  static const String home = '/home';
  static const String profile = '/profile';
  static const String messages = '/messages';

  // --- Top-Level (Standalone) Pages ---
  static const String serviceDetails = '/service-details';
  static const String cart = '/cart'; // Added from our previous implementation
  static const String aboutUs = '/about-us';
  static const String contactUs = '/contact-us';
  static const String cleaningServices = '/cleaning-services';
  static const String pestControl = '/pest-control';
  static const String blog = '/blog';
  static const String terms = '/terms';
  // Checkout route for placing orders
  static const String checkout = '/checkout';
}