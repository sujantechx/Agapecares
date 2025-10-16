import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/features/user_app/features/data/fixed_data/all_services.dart';
import 'package:agapecares/core/models/service_model.dart';

class CleaningServicesPage extends StatelessWidget {
  const CleaningServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the sample `allServices` list (ServiceModel) for display.
    final List<ServiceModel> services = allServices;

    return Scaffold(
      appBar: AppBar(title: const Text('Cleaning Services')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = services[index];
          final image = (s.images.isNotEmpty) ? s.images.first : s.imageUrl;

          return Card(
            child: ListTile(
              leading: image.isNotEmpty
                  ? Image.asset(image, width: 56, height: 56, fit: BoxFit.cover)
                  : const SizedBox(width: 56, height: 56),
              title: Text(s.name),
              subtitle: Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text('₹${s.basePrice.toStringAsFixed(0)}'),
              // Navigate to the service detail screen. The service route is defined
              // as '/service/:id' so we must include the id in the path. We also
              // pass the full ServiceModel as `extra` so the detail page can use
              // the fast-path and avoid re-fetching.
              onTap: () => context.push('/service/${s.id}', extra: s),
            ),
          );
        },
      ),
    );
  }
}