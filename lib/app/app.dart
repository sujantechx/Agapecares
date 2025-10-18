// lib/injection_container.dart


import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Repository interfaces
import 'package:agapecares/features/common_auth/data/repositories/auth_repository.dart';

// Admin-specific imports
import 'package:agapecares/features/admin_app/features/service_management/data/data_sources/service_remote_data_source.dart';
import 'package:agapecares/features/admin_app/features/service_management/data/data_sources/service_remote_data_source_impl.dart';
import 'package:agapecares/features/admin_app/features/service_management/domain/repositories/service_repository.dart'
    as admin_repo;
import 'package:agapecares/features/admin_app/features/service_management/data/repositories/service_repository_impl.dart'
    as admin_repo_impl;
import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/data/data_sources/order_remote_data_source.dart' as admin_order_ds;
import 'package:agapecares/features/admin_app/features/order_management/data/data_sources/order_remote_data_source_impl.dart' as admin_order_ds_impl;
import 'package:agapecares/features/admin_app/features/order_management/domain/repositories/order_repository.dart' as admin_order_repo;
import 'package:agapecares/features/admin_app/features/order_management/data/repositories/order_repository_impl.dart' as admin_order_repo_impl;
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:agapecares/features/admin_app/features/user_management/data/data_sources/user_remote_data_source.dart' as admin_user_ds;
import 'package:agapecares/features/admin_app/features/user_management/data/data_sources/user_remote_data_source_impl.dart' as admin_user_ds_impl;
import 'package:agapecares/features/admin_app/features/user_management/domain/repositories/user_repository.dart' as admin_user_repo;
import 'package:agapecares/features/admin_app/features/user_management/data/repositories/user_repository_impl.dart' as admin_user_repo_impl;
import 'package:agapecares/features/admin_app/features/user_management/presentation/bloc/admin_user_bloc.dart';

import 'package:agapecares/features/admin_app/features/worker_management/data/data_sources/worker_remote_data_source.dart' as admin_worker_ds;
import 'package:agapecares/features/admin_app/features/worker_management/data/data_sources/worker_remote_data_source_impl.dart' as admin_worker_ds_impl;
import 'package:agapecares/features/admin_app/features/worker_management/domain/repositories/worker_repository.dart' as admin_worker_repo;
import 'package:agapecares/features/admin_app/features/worker_management/data/repositories/worker_repository_impl.dart' as admin_worker_repo_impl;
import 'package:agapecares/features/admin_app/features/worker_management/presentation/bloc/admin_worker_bloc.dart';

// User-specific imports
import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository.dart';
import 'package:agapecares/features/user_app/features/services/data/repositories/service_repository.dart';
import 'package:agapecares/features/user_app/features/workers/domain/repositories/worker_repository.dart';
import 'package:agapecares/features/user_app/features/workers/data/repositories/worker_repository_impl.dart';

import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:agapecares/features/user_app/features/services/data/repositories/service_repository_impl.dart';

import 'package:agapecares/features/user_app/features/cart/bloc/cart_bloc.dart' as ui_cart_bloc;
import 'package:agapecares/features/user_app/features/services/logic/service_bloc.dart';
import 'package:agapecares/features/user_app/features/orders/logic/order_bloc.dart';
// Import the user-app OrderRepository (interface + implementation) with a prefix
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;
import 'package:agapecares/features/user_app/features/data/repositories/offer_repository.dart';
import 'package:agapecares/features/user_app/features/data/repositories/booking_repository.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/repository/razorpay_payment_repository.dart';
import 'package:agapecares/features/user_app/features/payment_gateway/repository/cod_payment_repository.dart';

// Removed unused import of checkout_bloc.dart

import '../features/common_auth/logic/blocs/auth_bloc.dart';
import 'package:agapecares/features/common_auth/data/datasources/auth_remote_ds.dart';
import 'package:agapecares/core/services/session_service.dart';

// Repository implementations



final sl = GetIt.instance;

/// Initialize dependencies. Call once before runApp.
/// Returns a list of [RepositoryProvider] which can be mounted at the top of the widget tree.
Future<List<RepositoryProvider>> init() async {
  // External
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // Ensure SessionService is available and initialized
  final sessionService = SessionService();
  await sessionService.init();
  sl.registerLazySingleton<SessionService>(() => sessionService);

  // DataSources
  sl.registerLazySingleton<ServiceRemoteDataSource>(
      () => ServiceRemoteDataSourceImpl(firestore: sl()));

  // Register auth remote data source
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()));

  // Register admin order data source
  sl.registerLazySingleton<admin_order_ds.OrderRemoteDataSource>(() => admin_order_ds_impl.OrderRemoteDataSourceImpl(firestore: sl()));
  // Admin user/worker data sources
  sl.registerLazySingleton<admin_user_ds.AdminUserRemoteDataSource>(() => admin_user_ds_impl.AdminUserRemoteDataSourceImpl(firestore: sl()));
  sl.registerLazySingleton<admin_worker_ds.AdminWorkerRemoteDataSource>(() => admin_worker_ds_impl.AdminWorkerRemoteDataSourceImpl(firestore: sl()));

  // Repositories
  sl.registerLazySingleton<CartRepository>(() => CartRepositoryImpl(firestore: sl()));
  sl.registerLazySingleton<ServiceRepository>(() => ServiceRepositoryImpl(firestore: sl()));
  // Register the user-facing OrderRepository implementation under the user-order interface
  sl.registerLazySingleton<user_orders_repo.OrderRepository>(() => user_orders_repo.OrderRepositoryImpl(firestore: sl()));
  // OfferRepository is a simple, in-memory/deterministic repository used by CartBloc
  sl.registerLazySingleton<OfferRepository>(() => OfferRepository());

  // New: Booking and Payment repositories
  sl.registerLazySingleton<BookingRepository>(() => BookingRepository(firestore: sl()));
  sl.registerLazySingleton<RazorpayPaymentRepository>(() => RazorpayPaymentRepository(backendCreateOrderUrl: 'https://example.com/create-order'));
  sl.registerLazySingleton<CodPaymentRepository>(() => CodPaymentRepository());

  // Register AuthRepository (used by AuthBloc and app-wide providers)
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository(firebaseAuth: sl(), firestore: sl()));

  sl.registerLazySingleton<admin_repo.ServiceRepository>(
      () => admin_repo_impl.ServiceRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton<admin_order_repo.OrderRepository>(() => admin_order_repo_impl.OrderRepositoryImpl(firestore: sl()));
  sl.registerLazySingleton<admin_user_repo.AdminUserRepository>(() => admin_user_repo_impl.AdminUserRepositoryImpl(remote: sl()));
  sl.registerLazySingleton<admin_worker_repo.AdminWorkerRepository>(() => admin_worker_repo_impl.AdminWorkerRepositoryImpl(remote: sl()));
  // Register a user-facing WorkerRepository that delegates to the admin worker remote data source
  sl.registerLazySingleton<WorkerRepository>(() => WorkerRepositoryImpl(remote: sl()));

  // BLoC factories
  // Ensure AuthBloc receives SessionService so it can persist/clear cached user state.
  sl.registerFactory(() => AuthBloc(authRepository: sl(), sessionService: sl()));
  sl.registerFactory(() => ServiceBloc(serviceRepository: sl()));
  // Register the UI-facing CartBloc which expects CartRepository & OfferRepository
  sl.registerFactory(() => ui_cart_bloc.CartBloc(cartRepository: sl(), offerRepository: sl()));
  sl.registerFactory(() => OrderBloc(orderRepository: sl()));
  sl.registerFactory(() => ServiceManagementBloc(serviceRepository: sl()));
  sl.registerFactory(() => AdminOrderBloc(repo: sl()));
  sl.registerFactory(() => AdminUserBloc(repo: sl()));
  sl.registerFactory(() => AdminWorkerBloc(repo: sl()));
  // CheckoutBloc is provided at the checkout route to ensure correct dependencies and lifecycle.

  // Build repository providers to mount at app root
  final providers = <RepositoryProvider>[
    RepositoryProvider<AuthRepository>.value(value: sl()),
    RepositoryProvider<CartRepository>.value(value: sl()),
    RepositoryProvider<ServiceRepository>.value(value: sl()),
    // Expose the user-order repository under a specific typed provider to avoid collisions
    RepositoryProvider<user_orders_repo.OrderRepository>.value(value: sl()),
    RepositoryProvider<admin_repo.ServiceRepository>.value(value: sl()),
    RepositoryProvider<admin_order_repo.OrderRepository>.value(value: sl()),
    RepositoryProvider<admin_user_repo.AdminUserRepository>.value(value: sl()),
    RepositoryProvider<admin_worker_repo.AdminWorkerRepository>.value(value: sl()),
    // Expose the user-facing worker repository to the widget tree
    RepositoryProvider<WorkerRepository>.value(value: sl()),
    RepositoryProvider<OfferRepository>.value(value: sl()),
    // Expose SessionService to the widget tree so widgets can read cached user safely
    RepositoryProvider<SessionService>.value(value: sl()),
    // Expose booking/payment repositories
    RepositoryProvider<BookingRepository>.value(value: sl()),
    RepositoryProvider<RazorpayPaymentRepository>.value(value: sl()),
    RepositoryProvider<CodPaymentRepository>.value(value: sl()),
  ];

  return providers;
}

/// Build the list of BlocProvider using instances from the current context's repositories.
List<BlocProvider> buildBlocs(BuildContext context) {
  final authRepo = context.read<AuthRepository>();
  final sessionService = context.read<SessionService>();
  final serviceRepo = context.read<ServiceRepository>();
  final adminServiceRepo = context.read<admin_repo.ServiceRepository>();
  final adminOrderRepo = context.read<admin_order_repo.OrderRepository>();
  final adminUserRepo = context.read<admin_user_repo.AdminUserRepository>();
  final adminWorkerRepo = context.read<admin_worker_repo.AdminWorkerRepository>();

  return [
    BlocProvider<AuthBloc>(create: (_) => AuthBloc(authRepository: authRepo, sessionService: sessionService)),
    BlocProvider<ServiceBloc>(create: (_) => ServiceBloc(serviceRepository: serviceRepo)),
    BlocProvider<ui_cart_bloc.CartBloc>(
      create: (ctx) => ui_cart_bloc.CartBloc(
        cartRepository: ctx.read<CartRepository>(),
        offerRepository: ctx.read<OfferRepository>(),
      ),
    ),
    BlocProvider<OrderBloc>(create: (_) => OrderBloc(orderRepository: sl<user_orders_repo.OrderRepository>())),
    // CheckoutBloc provided locally in route; do not register globally to avoid duplicate instances.
    BlocProvider<ServiceManagementBloc>(create: (_) => ServiceManagementBloc(serviceRepository: adminServiceRepo)),
    BlocProvider<AdminOrderBloc>(create: (_) => AdminOrderBloc(repo: adminOrderRepo)),
    BlocProvider<AdminUserBloc>(create: (_) => AdminUserBloc(repo: adminUserRepo)),
    BlocProvider<AdminWorkerBloc>(create: (_) => AdminWorkerBloc(repo: adminWorkerRepo)),
  ];
}

List<BlocProvider> buildBlocsFromGetIt({AuthBloc? authBloc}) {
  // Use the service locator to build bloc instances when we don't have a BuildContext.
  // If an AuthBloc instance is provided, use it (so router and widget tree share it).
  final _authBloc = authBloc ?? sl<AuthBloc>();

  return [
    BlocProvider<AuthBloc>.value(value: _authBloc),
    BlocProvider<ServiceBloc>(create: (_) => ServiceBloc(serviceRepository: sl())),
    BlocProvider<ui_cart_bloc.CartBloc>(
      create: (_) => ui_cart_bloc.CartBloc(cartRepository: sl(), offerRepository: sl()),
    ),
    BlocProvider<OrderBloc>(create: (_) => OrderBloc(orderRepository: sl<user_orders_repo.OrderRepository>())),
    // CheckoutBloc is created on the checkout route instead of globally.
    BlocProvider<ServiceManagementBloc>(create: (_) => ServiceManagementBloc(serviceRepository: sl())),
    BlocProvider<AdminOrderBloc>(create: (_) => AdminOrderBloc(repo: sl())),
    BlocProvider<AdminUserBloc>(create: (_) => AdminUserBloc(repo: sl())),
    BlocProvider<AdminWorkerBloc>(create: (_) => AdminWorkerBloc(repo: sl())),
  ];
}
