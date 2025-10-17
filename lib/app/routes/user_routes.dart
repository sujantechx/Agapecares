import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

// Prefer package imports so analyzer can resolve symbols reliably.
import 'package:agapecares/features/user_app/features/presentation/widgets/dashboard_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/user_home_page.dart';
import 'package:agapecares/features/user_app/features/cart/presentation/cart_page.dart';
import 'package:agapecares/features/user_app/features/orders/presentation/pages/order_list_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/profile_page.dart';
import 'package:agapecares/app/routes/app_routes.dart';

// Additional user pages
import 'package:agapecares/features/user_app/features/presentation/pages/cleaning_services_page.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/service_detail_page.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'package:agapecares/features/user_app/features/services/data/repositories/service_repository.dart';
import 'package:agapecares/features/user_app/features/presentation/pages/checkout_page.dart';

// Additional imports required so the Checkout route can create a local CheckoutBloc

import 'package:agapecares/features/user_app/features/data/repositories/booking_repository.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/repository/razorpay_payment_repository.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/repository/cod_payment_repository.dart';
import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/bloc/checkout_bloc.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;
import 'package:firebase_auth/firebase_auth.dart';

final GlobalKey<NavigatorState> _userShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'userShell');

final List<RouteBase> userRoutes = [
  // User Dashboard Shell Route
  ShellRoute(
    navigatorKey: _userShellNavigatorKey,
    builder: (context, state, child) {
      return DashboardPage(child: child); // Your user dashboard UI
    },
    routes: [
      // Use pageBuilder and unique keys to avoid duplicated page keys when go_router rebuilds
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: UserHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: CartPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.orders,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: OrderListPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: UserProfilePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      // Add cleaning services as a route inside the dashboard shell so it shows within the bottom-nav scaffold
      GoRoute(
        path: AppRoutes.cleaningServices,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CleaningServicesPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      // Checkout route: can accept `extra` as ServiceModel or List<CartItemModel>
      GoRoute(
        path: AppRoutes.checkout,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: BlocProvider<CheckoutBloc>(
            create: (ctx) => CheckoutBloc(
              orderRepo: ctx.read<user_orders_repo.OrderRepository>(),
              razorpayRepo: ctx.read<RazorpayPaymentRepository>(),
              codRepo: ctx.read<CodPaymentRepository>(),
              cartRepo: ctx.read<CartRepository>(),
              bookingRepo: ctx.read<BookingRepository>(),
              getCurrentUserId: () async => FirebaseAuth.instance.currentUser?.uid,
            ),
            child: CheckoutPage(extra: state.extra),
          ),
        ),
      ),
    ],
  ),

  // Service detail and other full-screen user pages that should be pushed on top of the dashboard
  GoRoute(
    path: AppRoutes.serviceDetail,
    builder: (context, state) {
      // Accept a ServiceModel via `extra` when callers already have the model (fast path).
      final extra = state.extra;
      if (extra != null && extra is ServiceModel) {
        return ServiceDetailPage(service: extra);
      }

      // Otherwise attempt to fetch the service by id using the registered repository.
      final id = state.pathParameters['id'] ?? '';
      if (id.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Service')),
          body: const Center(child: Text('Service not found')),
        );
      }

      final repo = context.read<ServiceRepository>();
      return FutureBuilder<ServiceModel>(
        future: repo.fetchServiceById(id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError || snap.data == null) {
            return Scaffold(body: Center(child: Text('Failed to load service: ${snap.error}')));
          }
          return ServiceDetailPage(service: snap.data!);
        },
      );
    },
  ),
];