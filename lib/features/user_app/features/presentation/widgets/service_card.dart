// lib/features/user_app/presentation/widgets/service_card.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/models/service_list_model.dart';
import '../../../../../app/routes/app_routes.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;

  const ServiceCard({super.key, required this.service});

  // A helper to get an icon based on the dummy iconUrl string
  IconData _getIconForService(String iconName) {
    switch (iconName) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'gardening':
        return Icons.grass;
      default:
        return Icons.miscellaneous_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The card is a purely presentational component – no business logic.
    // Navigation or actions should be provided by the parent widget.
    final priceText = '\$${service.price.toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // Navigate to the service detail page when the card is tapped.
        onTap: () {
          // Use the route pattern and replace the :id param to push a detail page.
          final path = AppRoutes.serviceDetail.replaceAll(':id', service.id);
          context.push(path);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _getIconForService(service.iconUrl),
                // color: AppTheme.primaryColor,
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                priceText,
                style: const TextStyle(
                  // color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}