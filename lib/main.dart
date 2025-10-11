import 'dart:ui';

import 'package:agapecares/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'injection_container.dart';
import 'routes/app_router.dart';
import 'shared/theme/app_theme.dart';

/// App entrypoint
/// - Initializes DI (repositories/services), Firebase and global error handlers.
/// - Passes repository providers into the widget tree, then builds BLoCs from those providers.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first so any repository that depends on Firestore
  // (created during `init()`) will have a Firebase App available.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Ensure FirebaseAuth has initialized and emitted initial auth state.
    // This avoids calling Firestore with an unready auth instance which can
    // lead to empty or invalid user ids during early writes.
    try {
      // Wait for the first auth state event (may be immediate). Time out after a short period
      await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 5));
    } catch (_) {
      // If auth didn't become ready quickly, continue; downstream code must still guard for null user.
    }
  } catch (e, stack) {
    // If Firebase fails to initialize, it's unsafe to create repositories
    // that depend on Firestore. Re-throw or exit early depending on desired
    // behavior; here we rethrow to avoid creating repos that call
    // `FirebaseFirestore.instance` before Firebase is ready.
    // ignore: avoid_print
    print('Firebase initialization error: $e\n$stack');
    rethrow;
  }

  // Initialize dependency injection and receive repository providers
  final repoProviders = await init();

  // Basic error handlers
  FlutterError.onError = (details) {
    // ignore: avoid_print
    print('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('Uncaught error: $error\n$stack');
    return true;
  };

  runApp(MyApp(repositoryProviders: repoProviders));
}

/// MyApp is intentionally simple and scalable:
/// - Accepts `RepositoryProvider`s created at startup.
/// - Mounts them at the top of the widget tree so any child can `context.read<T>()`.
/// - Builds BLoCs using `buildBlocs(context)` after the repositories are mounted.
class MyApp extends StatelessWidget {
  final List<RepositoryProvider> repositoryProviders;

  // Make repositoryProviders optional for tests and simple runs. If not provided,
  // an empty list is used (no repositories mounted).
  const MyApp({super.key, List<RepositoryProvider>? repositoryProviders})
      : repositoryProviders = repositoryProviders ?? const [];

  @override
  Widget build(BuildContext context) {
    // If no repository providers are provided (e.g. during lightweight tests),
    // skip wrapping with MultiRepositoryProvider and MultiBlocProvider to
    // avoid provider assertion errors. This keeps `MyApp()` simple and
    // usable in unit/widget tests without full DI wiring.
    if (repositoryProviders.isEmpty) {
      return MaterialApp.router(
        title: 'Agape Cares',
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.system,
        // When running without DI, create a router lazily.
        routerConfig: AppRouter.createRouter(),
        debugShowCheckedModeBanner: false,
      );
    }

    return MultiRepositoryProvider(
      providers: repositoryProviders,
      // Use a Builder so the inner context can `read` repositories and build BLoCs.
      child: Builder(builder: (context) {
        return MultiBlocProvider(
          providers: buildBlocs(context),
          child: MaterialApp.router(
            title: 'Agape Cares',
            theme: AppTheme.lightTheme,
            // darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            // Create the router after providers and blocs are available so
            // route builder contexts include them (fixes "Could not find the correct Provider<CartBloc>" errors).
            routerConfig: AppRouter.createRouter(),
            debugShowCheckedModeBanner: false,
          ),
        );
      }),
    );
  }
}
