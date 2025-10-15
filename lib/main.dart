// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';

import 'app/theme/app_theme.dart';
import 'package:agapecares/app/app.dart' as di;
import 'package:agapecares/app/routes/app_router.dart';
import 'package:agapecares/features/common_auth/logic/blocs/auth_bloc.dart';
import 'package:agapecares/app/theme/theme_cubit.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        child: MyApp(authBloc: authBloc),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthBloc authBloc;

  const MyApp({super.key, required this.authBloc});

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
          routerConfig: _router,
        );
      },
    );
  }
}