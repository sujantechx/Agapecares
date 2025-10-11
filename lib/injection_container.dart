// This file wires application-wide repositories, services and BLoCs.

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Repositories and services
import 'package:agapecares/features/user_app/cart/data/repository/cart_repository.dart';
import 'package:agapecares/features/user_app/data/repositories/offer_repository.dart';
import 'package:agapecares/features/user_app/data/repositories/order_repository.dart';
import 'package:agapecares/features/user_app/payment_gateway/repository/cod_payment_repository.dart';
import 'package:agapecares/features/user_app/payment_gateway/repository/razorpay_payment_repository.dart';
import 'package:agapecares/features/user_app/data/repositories/booking_repository.dart';
import 'package:agapecares/features/user_app/data/repositories/service_repository.dart';

// Services
import 'package:agapecares/shared/services/local_database_service.dart';
import 'package:agapecares/shared/services/sync_service.dart';
import 'package:agapecares/shared/services/session_service.dart';

// BLoCs
import 'package:agapecares/features/user_app/cart/bloc/cart_bloc.dart';
import 'package:agapecares/features/user_app/payment_gateway/bloc/checkout_bloc.dart';

// Auth repository/bloc imports
import 'package:agapecares/features/auth/data/repositories/auth_repository.dart';
import 'package:agapecares/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:agapecares/features/auth/logic/blocs/auth_bloc.dart';

// Flutter
import 'package:flutter/widgets.dart';

// Single place to manage app-wide configuration
const String _backendBaseUrl = 'http://10.0.2.2:8080';

// Exposed init function: creates services, repositories and returns the list of RepositoryProviders
Future<List<RepositoryProvider>> init() async {
  // Initialize services
  final LocalDatabaseService localDb = kIsWeb ? WebLocalDatabaseService() : SqfliteLocalDatabaseService();
  await localDb.init();

  // Repositories
  final orderRepository = OrderRepository(localDb: localDb);
  await orderRepository.init();

  // Initialize session service first so repositories can use it as a fallback
  final sessionService = SessionService();
  await sessionService.init();

  // Create cart repository with sessionService fallback for user id detection
  final cartRepository = CartRepository(localDb: localDb, sessionService: sessionService);

  // When user signs in (phone auth), attempt to seed the local cart from remote Firestore
  // This ensures the CartPage will show stored cart items immediately after login.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      // Fire-and-forget: getCartItems will seed local DB if remote cart exists
      cartRepository.getCartItems();
    }
  });
  final offerRepository = OfferRepository();
  final razorpayRepository = RazorpayPaymentRepository(
    backendCreateOrderUrl: '$_backendBaseUrl/create-order',
  );
  final codRepository = CodPaymentRepository();
  final serviceRepository = ServiceRepository();
  final bookingRepository = BookingRepository();

  // Sync service
  final syncService = SyncService(orderRepository: orderRepository);
  syncService.start();

  // Auth repository using the dummy remote datasource by default. This keeps the
  // app working without wiring a real Firebase remote datasource here. If you
  // later add a Firebase-backed datasource, replace AuthDummyDataSourceImpl()
  // with that implementation.
  final authRemoteDs = AuthDummyDataSourceImpl();
  final authRepository = AuthRepositoryImpl(remoteDataSource: authRemoteDs);

  // Return repository providers that will be mounted by the app
  return [
    RepositoryProvider<CartRepository>.value(value: cartRepository),
    RepositoryProvider<SessionService>.value(value: sessionService),
    RepositoryProvider<OfferRepository>.value(value: offerRepository),
    RepositoryProvider<LocalDatabaseService>.value(value: localDb),
    RepositoryProvider<OrderRepository>.value(value: orderRepository),
    RepositoryProvider<ServiceRepository>.value(value: serviceRepository),
    RepositoryProvider<BookingRepository>.value(value: bookingRepository),
    RepositoryProvider<RazorpayPaymentRepository>.value(value: razorpayRepository),
    RepositoryProvider<CodPaymentRepository>.value(value: codRepository),
    RepositoryProvider<SyncService>.value(value: syncService),
    // Provide auth repository so AuthBloc can be created at app start
    RepositoryProvider<AuthRepository>.value(value: authRepository),
  ];
}

// Build and return the list of BlocProviders after repositories are mounted in the widget tree
List<BlocProvider> buildBlocs(BuildContext context) {
  final cartRepo = context.read<CartRepository>();
  final offerRepo = context.read<OfferRepository>();
  final orderRepo = context.read<OrderRepository>();
  final razorpayRepo = context.read<RazorpayPaymentRepository>();
  final codRepo = context.read<CodPaymentRepository>();
  final bookingRepo = context.read<BookingRepository>();
  final authRepo = context.read<AuthRepository>();

  return [
    // Provide AuthBloc app-wide so LoginPage/OtpPage can use the same instance
    BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(authRepository: authRepo),
    ),
    BlocProvider<CartBloc>(
      create: (_) => CartBloc(
        cartRepository: cartRepo,
        offerRepository: offerRepo,
      ),
    ),
    BlocProvider<CheckoutBloc>(
      create: (_) => CheckoutBloc(
        orderRepo: orderRepo,
        razorpayRepo: razorpayRepo,
        codRepo: codRepo,
        cartRepo: cartRepo,
        bookingRepo: bookingRepo,
        // For now, a small helper to obtain current user id. Replace with your auth provider later.
        getCurrentUserId: () async {
          final user = FirebaseAuth.instance.currentUser;
          // Return null when no user is logged in. CheckoutBloc will handle nulls.
          if (user == null) return null;
          // Prefer Firebase UID (stable) over phone number for server-side queries
          final uid = user.uid?.trim();
          if (uid != null && uid.isNotEmpty) return uid;
          final phone = user.phoneNumber?.trim();
          if (phone != null && phone.isNotEmpty) return phone;
          return null;
        },
      ),
    ),
  ];
}
