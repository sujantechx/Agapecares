// filepath: c:\FlutterDev\agapecares\lib\features\admin_app\features\service_management\presentation\widgets\service_list_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:agapecares/core/models/service_model.dart';
// Use package imports so analyzer resolves types across the package.
import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_bloc.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/bloc/service_management_event.dart';
import 'package:agapecares/app/routes/app_routes.dart';

/// A single row in the admin services list. Shows basic info and provides
/// edit/delete actions. Uses the `ServiceManagementBloc` to perform deletes
/// and navigates to the add/edit route for editing.
class ServiceListItem extends StatelessWidget {
  final ServiceModel service;
  const ServiceListItem({Key? key, required this.service}) : super(key: key);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete service'),
        content: Text('Are you sure you want to delete "${service.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        context.read<ServiceManagementBloc>().add(DeleteService(service.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service deleted')));
      } catch (e) {
        debugPrint('[ServiceListItem] delete error: $e');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete service')));
      }
    }
  }

  Widget _buildLeading() {
    if (service.images.isNotEmpty) {
      return SizedBox(
        width: 72,
        height: 72,
        child: CarouselSlider(
          options: CarouselOptions(
            viewportFraction: 1.0,
            enableInfiniteScroll: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            height: 72,
          ),
          items: service.images.map((img) {
            final isNetwork = img.startsWith('http');
            return Builder(builder: (ctx) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isNetwork
                    ? Image.network(img, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                    : Image.asset(img, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
              );
            });
          }).toList(),
        ),
      );
    }

    // Fallback icon when no images are present
    return const Icon(Icons.cleaning_services, size: 40);
  }

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final created = _formatTs(service.createdAt);
    final updated = _formatTs(service.updatedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _buildLeading(),
        title: Text(service.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${service.category} • ₹${service.basePrice.toStringAsFixed(0)}'),
            if (created.isNotEmpty || updated.isNotEmpty) const SizedBox(height: 4),
            if (created.isNotEmpty) Text('Created: $created', style: const TextStyle(fontSize: 12)),
            if (updated.isNotEmpty) Text('Updated: $updated', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              // Navigate to edit screen and pass the service as extra so it can be edited
              context.push(AppRoutes.adminEditService, extra: service);
            } else if (value == 'delete') {
              await _confirmDelete(context);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
