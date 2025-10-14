import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/models/service_list_model.dart';
import 'package:agapecares/features/user_app/features/services/data/repositories/service_repository.dart';

/// ServiceDetailPage
///
/// Fetches a service by id using the registered ServiceRepository and displays
/// a simple detail view. This keeps fetching logic out of the UI and uses the
/// repository layer which is already wired in the app's DI container.
class ServiceDetailPage extends StatefulWidget {
  final String serviceId;

  const ServiceDetailPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  late final ServiceRepository _repo;
  late Future<ServiceModel> _futureService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read ServiceRepository from RepositoryProvider (app.dart registers it)
    _repo = RepositoryProvider.of<ServiceRepository>(context);
    _futureService = _repo.fetchServiceById(widget.serviceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: FutureBuilder<ServiceModel>(
        future: _futureService,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load service details'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _futureService = _repo.fetchServiceById(widget.serviceId);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final service = snapshot.data;
          if (service == null || service.id.isEmpty) {
            return const Center(child: Text('Service not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('\$${service.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(service.description),
                const SizedBox(height: 12),
                if (service.inclusions.isNotEmpty) ...[
                  const Text('Inclusions', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...service.inclusions.map((i) => Text('• $i')),
                  const SizedBox(height: 12),
                ],
                if (service.exclusions.isNotEmpty) ...[
                  const Text('Exclusions', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...service.exclusions.map((i) => Text('• $i')),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: implement add to cart or booking flow. Keep UI-only for now.
                        },
                        child: const Text('Book / Add to cart'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
