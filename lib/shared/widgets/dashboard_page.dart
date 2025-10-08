import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/routes/app_routes.dart'; // 🎯 Import your app routes
import 'package:agapecares/features/user_app/presentation/widgets/app_drawer.dart';
import 'package:agapecares/shared/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  final Widget child;
  const DashboardPage({super.key, required this.child});

  // 🎯 Updated to handle the new cart index
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.home)) {
      return 0;
    }
    if (location.startsWith(AppRoutes.cart)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.profile)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.messages)) {
      return 3;
    }
    return 0; // Default to home
  }

  // 🎯 Updated to navigate to the new cart route
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go(AppRoutes.home);
        break;
      case 1:
        GoRouter.of(context).go(AppRoutes.cart);
        break;
      case 2:
        GoRouter.of(context).go(AppRoutes.profile);
        break;
      case 3:
        GoRouter.of(context).go(AppRoutes.messages);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎯 Using the Scaffold's built-in drawer property is the standard practice.
      // It automatically adds the menu icon to the AppBar.
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Image.asset( // 🎯 Use Image.asset for local assets
          "assets/logos/ap_logo.png",
          fit: BoxFit.contain,
          height: 32, // Adjusted height for a standard AppBar
        ),
        centerTitle: true,
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.subtitleColor,
        // 🎯 The 'type' property is needed when you have more than 3 items
        // to ensure all items are displayed correctly.
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          // 🎯 NEW CART ITEM ADDED
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}