import 'dart:ui';

import 'package:agapecares/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app/app.dart';
import 'app/routes/app_router.dart';
import 'app/theme/app_theme.dart';

import 'core/services/session_service.dart';
import 'core/api/auth_service.dart';

/// App entrypoint
/// - Initializes DI (repositories/services), Firebase and global error handlers.
/// - Passes repository providers into the widget tree, then builds BLoCs from those providers.
Future<void> main() async {
  debugPrint('MAIN_DEBUG: main() starting');
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first so any repository that depends on Firestore
  // (created during `init()`) will have a Firebase App available.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('MAIN_DEBUG: Firebase.initializeApp completed');
    // Ensure FirebaseAuth has initialized and emitted initial auth state.
    try {
      // Wait for the first auth state event (may be immediate). Time out after a short period
      await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 5));
      debugPrint('MAIN_DEBUG: FirebaseAuth initial authStateChanges received');
    } catch (_) {
      debugPrint('MAIN_DEBUG: FirebaseAuth initial wait timed out or failed');
      // If auth didn't become ready quickly, continue; downstream code must still guard for null user.
    }
  } catch (e, stack) {
    debugPrint('MAIN_DEBUG: Firebase initialization error: $e');
    // ignore: avoid_print
    print('Firebase initialization error: $e\n$stack');
    rethrow;
  }

  debugPrint('MAIN_DEBUG: initializing SessionService in main');
  // Initialize session service (local prefs) early so we can cache user profile.
  final session = SessionService();
  await session.init();
  debugPrint('MAIN_DEBUG: SessionService initialized');

  // Listen for auth state changes and persist/clear session user accordingly.
  final authService = AuthService();
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    debugPrint('MAIN_DEBUG: authStateChanges event: ${user?.uid}');
    if (user == null) {
      await session.clear();
    } else {
      // Try to fetch Firestore user profile and save it locally
      try {
        final model = await authService.fetchUserModel(user.uid);
        if (model != null) await session.saveUser(model);
      } catch (_) {
        // ignore errors; session may remain stale until next successful fetch
      }
    }
  });

  debugPrint('MAIN_DEBUG: calling init() to register DI');
  // Initialize dependency injection and receive repository providers
  final repoProviders = await init();
  debugPrint('MAIN_DEBUG: init() completed, repoProviders.length=${repoProviders.length}');

  // Basic error handlers
  FlutterError.onError = (details) {
    debugPrint('MAIN_DEBUG: FlutterError: ${details.exceptionAsString()}');
    // ignore: avoid_print
    print('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('MAIN_DEBUG: Uncaught error: $error');
    // ignore: avoid_print
    print('Uncaught error: $error\n$stack');
    return true;
  };

  runApp(MyApp(repositoryProviders: repoProviders));
}

class MyApp extends StatelessWidget {
  final List<RepositoryProvider> repositoryProviders;

  // Make repositoryProviders optional for tests and simple runs. If not provided,
  // an empty list is used (no repositories mounted).
  const MyApp({super.key, List<RepositoryProvider>? repositoryProviders})
      : repositoryProviders = repositoryProviders ?? const [];

  @override
  Widget build(BuildContext context) {
    debugPrint('MAIN_DEBUG: MyApp.build repositoryProviders.length=${repositoryProviders.length}');
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
        debugPrint('MAIN_DEBUG: Building MultiBlocProvider');
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
