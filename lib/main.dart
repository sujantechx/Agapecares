import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/routes/app_router.dart';
import 'package:agapecares/shared/theme/app_theme.dart';

import 'features/user_app/cart/bloc/cart_bloc.dart';
import 'features/user_app/cart/bloc/cart_event.dart';
import 'features/user_app/cart/data/repository/cart_repository.dart';
import 'features/user_app/data/repositories/offer_repository.dart';



void main() {
  // Create single instances of your repositories.
  final CartRepository cartRepository = CartRepository();
  final OfferRepository offerRepository = OfferRepository(); // 🎯 Create OfferRepository

  runApp(
    // 🎯 Use MultiRepositoryProvider for multiple repositories
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: cartRepository),
        RepositoryProvider.value(value: offerRepository),
      ],
      child: BlocProvider(
        create: (context) => CartBloc(
          // BLoC can now read both repositories from the context
          cartRepository: context.read<CartRepository>(),
          offerRepository: context.read<OfferRepository>(),
        )..add(CartStarted()),
        child: const MyApp(),
      ),
    ),
  );
}

// ... MyApp class remains the same

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp.router is used to integrate a routing package like go_router.
    return MaterialApp.router(
      title: 'Agape Cares',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // The routerConfig from your refactored AppRouter is used here.
      routerConfig: AppRouter.router,
    );
  }
}