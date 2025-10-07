// lib/main.dart

import 'package:agapecares/routes/app_router.dart';
import 'package:agapecares/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';


void main() {
  // In a real app, you would initialize services here
  // like Firebase, Dependency Injection, etc.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp.router is used to integrate a routing package like go_router.
    return MaterialApp.router(
      title: 'Service App',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // The routerConfig is what tells the app how to navigate between screens.
      routerConfig: AppRouter.router,
    );
  }
}