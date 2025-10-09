// This file wires application-wide repositories, services and BLoCs.

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Repositories and services
import 'package:agapecares/features/user_app/cart/data/repository/cart_repository.dart';
import 'package:agapecares/features/user_app/data/repositories/offer_repository.dart';
import 'package:agapecares/features/user_app/data/repositories/order_repository.dart';
import 'package:agapecares/features/user_app/payment_gateway/repository/cod_payment_repository.dart';
import 'package:agapecares/features/user_app/payment_gateway/repository/razorpay_payment_repository.dart';

// Services
import 'package:agapecares/shared/services/local_database_service.dart';
import 'package:agapecares/shared/services/sync_service.dart';

// BLoCs
import 'package:agapecares/features/user_app/cart/bloc/cart_bloc.dart';
import 'package:agapecares/features/user_app/payment_gateway/bloc/checkout_bloc.dart';

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

  final cartRepository = CartRepository();
  final offerRepository = OfferRepository();
  final razorpayRepository = RazorpayPaymentRepository(
    backendCreateOrderUrl: '$_backendBaseUrl/create-order',
  );
  final codRepository = CodPaymentRepository();

  // Sync service
  final syncService = SyncService(orderRepository: orderRepository);
  syncService.start();

  // Return repository providers that will be mounted by the app
  return [
    RepositoryProvider<CartRepository>.value(value: cartRepository),
    RepositoryProvider<OfferRepository>.value(value: offerRepository),
    RepositoryProvider<LocalDatabaseService>.value(value: localDb),
    RepositoryProvider<OrderRepository>.value(value: orderRepository),
    RepositoryProvider<RazorpayPaymentRepository>.value(value: razorpayRepository),
    RepositoryProvider<CodPaymentRepository>.value(value: codRepository),
    RepositoryProvider<SyncService>.value(value: syncService),
  ];
}

// Build and return the list of BlocProviders after repositories are mounted in the widget tree
List<BlocProvider> buildBlocs(BuildContext context) {
  final cartRepo = context.read<CartRepository>();
  final offerRepo = context.read<OfferRepository>();
  final orderRepo = context.read<OrderRepository>();
  final razorpayRepo = context.read<RazorpayPaymentRepository>();
  final codRepo = context.read<CodPaymentRepository>();

  return [
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
        // For now, a small helper to obtain current user id. Replace with your auth provider later.
        getCurrentUserId: () async => 'user123',
      ),
    ),
  ];
}
