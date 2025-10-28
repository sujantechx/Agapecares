// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'core/firebase_emulator.dart';

import 'app/theme/app_theme.dart';
import 'package:agapecares/app/app.dart' as di;
import 'package:agapecares/app/routes/app_router.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_bloc.dart';
import 'package:agapecares/app/theme/theme_cubit.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_state.dart';

// Global key to allow showing SnackBars from a top-level listener even when
// the current route's widget tree hasn't mounted its own listeners yet.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // If you're running local emulators for Firestore/Functions set the flag
  // `useFirebaseEmulator = true` in `lib/core/firebase_emulator.dart`.
  // This call is a no-op when the flag is false.
  configureFirebaseEmulators();

  // Initialize dependency injection container and get repository providers
  final repoProviders = await di.init();

  // Create a single AuthBloc instance from GetIt so the router and widget tree share it.
  final authBloc = di.sl<AuthBloc>();

  // Build BlocProviders from GetIt and ensure the shared AuthBloc is used.
  final blocProviders = di.buildBlocsFromGetIt(authBloc: authBloc);

  // Run the app wrapped by the repository providers, bloc providers and ThemeCubit so
  // repositories, blocs and theme are available above MyApp.
  runApp(
    MultiRepositoryProvider(
      providers: repoProviders,
      child: MultiBlocProvider(
        providers: [
          ...blocProviders,
          // Provide a global ThemeCubit so the entire app can toggle themes.
          BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        ],
        // Add a top-level BlocListener for AuthBloc so errors are shown even during navigation
        child: BlocListener<AuthBloc, AuthState>(
          bloc: authBloc,
          listener: (context, state) {
            if (state is AuthFailure) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            }
          },
          child: MyApp(authBloc: authBloc),
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthBloc authBloc;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  const MyApp({super.key, required this.authBloc, this.scaffoldMessengerKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Hold the router instance to properly dispose of it.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Create the router, passing the shared AuthBloc instance to it.
    _router = AppRouter(authBloc: widget.authBloc).createRouter();
  }

  @override
  void dispose() {
    // We created the AuthBloc via GetIt factory and provided it above the app.
    // Close it here to avoid leaks when the app shuts down.
    widget.authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The BlocProviders are already mounted above MyApp, so simply build the router app.
    // Use BlocBuilder to react to ThemeCubit changes and switch between light/dark themes.
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp.router(
          title: 'Agape Cares',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: widget.scaffoldMessengerKey ?? scaffoldMessengerKey,
          routerConfig: _router,
        );
      },
    );
  }
}