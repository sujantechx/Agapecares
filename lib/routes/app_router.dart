// lib/routes/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 🎯 CORRECTED IMPORTS to match our project structure
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/user_app/presentation/pages/about_us_page.dart';
import '../features/user_app/presentation/pages/cleaning_services_page.dart';
import '../features/user_app/presentation/pages/contact_us_page.dart';
import '../features/user_app/presentation/pages/message_page.dart';
import '../features/user_app/presentation/pages/our_blog_page.dart';
import '../features/user_app/presentation/pages/pest_control_page.dart';
import '../features/user_app/presentation/pages/profile_page.dart';
import '../features/user_app/presentation/pages/service_detail_page.dart';
import '../features/user_app/presentation/pages/terms_of_use_page.dart';
import '../features/user_app/presentation/pages/user_home_page.dart';
import '../shared/models/service_list_model.dart';
import '../shared/widgets/dashboard_page.dart';


class AppRouter {
  /// A private key for the root navigator.
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// A private key for the shell navigator used within the dashboard.
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    navigatorKey: _rootNavigatorKey,
    routes: [
      // --- Authentication Flow ---
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phoneNumber = state.extra as String;
          return OtpPage(phoneNumber: phoneNumber);
        },
      ),

      // --- 🎯 CORRECTED Service Details Route ---
      // This route is separate from the main dashboard shell.
      GoRoute(
        path: '/service-details',
        builder: (context, state) {
          // It expects a ServiceModel object, not a phone number.
          final service = state.extra as ServiceModel;
          // It returns the ServiceDetailPage.
          return ServiceDetailPage(service: service);
        },
      ),
      // 🎯 ADD THE NEW ROUTES for the drawer pages
      GoRoute(
        path: '/about-us',
        builder: (context, state) => const AboutUsPage(),
      ),
      GoRoute(
        path: '/contact-us',
        builder: (context, state) => const ContactUsPage(),
      ),
      GoRoute(path: '/cleaning-services', builder: (context, state) => const CleaningServicesPage()),
      GoRoute(path: '/pest-control', builder: (context, state) => const PestControlPage()),
      GoRoute(path: '/blog', builder: (context, state) => const OurBlogPage()),
      GoRoute(path: '/terms', builder: (context, state) => const TermsOfUsePage()),
      // --- Main App Flow (User Side) ---
      // ShellRoute creates the scaffold with the persistent BottomNavigationBar.
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return DashboardPage(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => UserHomePage(),
          ),

          GoRoute(
            path: '/profile',
            builder: (context, state) => const UserProfilePage(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const MessagePage(),
          ),
        ],
      ),
    ],
  );
}