import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/services/session_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // Helper function to create an email link
  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@nakoda.com', // Your support email
      queryParameters: {'subject': 'App Support Inquiry'},
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Could not launch $emailLaunchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if current session user is a worker
    bool showWorkerMenu = false;
    try {
      final session = context.read<SessionService>();
      final UserModel? u = session.getUser();
      if (u != null && u.role == 'worker') showWorkerMenu = true;
    } catch (_) {}

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _buildDrawerHeader(),
          _buildSubheading('Pages:'),
          _buildDrawerItem(context: context, icon: Icons.login, text: 'Login', onTap: () => context.go('/login')),
          if (showWorkerMenu) _buildDrawerItem(context: context, icon: Icons.dashboard_outlined, text: 'Worker Dashboard', onTap: () => context.go(AppRoutes.workerHome)),
          if (showWorkerMenu) _buildDrawerItem(context: context, icon: Icons.work_outline, text: 'Worker Orders', onTap: () => context.go(AppRoutes.workerOrders)),
          _buildDrawerItem(context: context, icon: Icons.info_outline, text: 'About Us', onTap: () => context.push('/about-us')),
          _buildDrawerItem(context: context, icon: Icons.cleaning_services, text: 'Cleaning Services', onTap: () => context.push('/cleaning-services')),
          _buildDrawerItem(context: context, icon: Icons.settings_outlined, text: 'AC Services', onTap: () => context.push('/ac-services')),
          _buildDrawerItem(context: context, icon: Icons.pest_control, text: 'Pest Control', onTap: () => context.push('/pest-control')),
          _buildDrawerItem(context: context, icon: Icons.article_outlined, text: 'Our Blog', onTap: () => context.push('/blog')),
          const Divider(),
          _buildSubheading('Info Pages:'),
          _buildDrawerItem(context: context, icon: Icons.phone_outlined, text: 'Contact Us', onTap: () => context.push('/contact-us')),
          _buildDrawerItem(context: context, icon: Icons.email_outlined, text: 'Email', onTap: _launchEmail), // Use the special function here
          _buildDrawerItem(context: context, icon: Icons.description_outlined, text: 'Terms of Use', onTap: () => context.push('/terms')),
          const Divider(),
          // Logout option for signed-in users
          Builder(builder: (ctx) {
            try {
              final session = ctx.read<SessionService>();
              final u = session.getUser();
              if (u != null) {
                return ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    // Clear session then sign out
                    try {
                      await session.clear();
                    } catch (_) {}
                    try {
                      await FirebaseAuth.instance.signOut();
                    } catch (_) {}
                    if (ctx.mounted) GoRouter.of(ctx).go(AppRoutes.login);
                  },
                );
              }
            } catch (_) {}
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  /// Helper widget for the custom drawer header.
  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60.0, bottom: 20.0),
      child: Column(
        children: [
          // The ClipRRect gives the logo image rounded corners.
          ClipRRect(
            // borderRadius: BorderRadius.circular(50.0),
            child: Image.asset(
              "assets/logos/logo.png", // Make sure this path is correct
              width: 300,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          Text(
            'Agapecares',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget for the section subheadings.
  Widget _buildSubheading(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required BuildContext context, required IconData icon, required String text, required GestureTapCallback onTap}) {
    return ListTile(
      leading: Icon(icon,),
      title: Text(text, style: const TextStyle(fontSize: 16)),
      onTap: () {
        Navigator.of(context).pop(); // Close the drawer
        onTap(); // Execute the action
      },
    );
  }
}