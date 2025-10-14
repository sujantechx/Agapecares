import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../data/static_services.dart';

class CleaningServicesPage extends StatelessWidget {
  const CleaningServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaning Services')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: cleaningServices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = cleaningServices[index];
          return Card(
            child: ListTile(
              leading: Image.asset(s['image'], width: 56, height: 56, fit: BoxFit.cover),
              title: Text(s['title']),
              subtitle: Text(s['description']),
              trailing: Text('₹${s['price'].toStringAsFixed(0)}'),
              onTap: () {
                // Navigate to checkout with selected service map as extra using GoRouter
                context.push(AppRoutes.checkout, extra: s);
              },
            ),
          );
        },
      ),
    );
  }
}