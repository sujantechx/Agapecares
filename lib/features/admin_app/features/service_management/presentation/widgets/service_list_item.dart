// filepath: c:\FlutterDev\agapecares\lib\features\admin_app\features\service_management\presentation\widgets\service_list_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: service.imageUrl.isNotEmpty
            ? Image.asset(service.imageUrl, width: 56, height: 56, fit: BoxFit.cover)
            : const Icon(Icons.cleaning_services, size: 40),
        title: Text(service.name),
        subtitle: Text('${service.category} • ₹${service.basePrice.toStringAsFixed(0)}'),
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
