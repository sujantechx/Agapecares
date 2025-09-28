// lib/features/user_app/presentation/pages/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../features/user_app/presentation/widgets/app_drawer.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  final Widget child;
  const DashboardPage({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/profile')) {
      return 1;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/home');
        break;
      case 1:
        GoRouter.of(context).go('/profile');
        break;
        case 2:
        GoRouter.of(context).go('/messages');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => AppDrawer(),));
        }

      ),
      title: Image.network(
        "assets/logos/ap_logo.png", // Replace with your actual logo URL
      fit: BoxFit.contain,
        height: 152,
      ),
      centerTitle: true,
    ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.subtitleColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ), BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}