import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/service_list.dart';
import '../../services/logic/service_bloc.dart';
import '../../services/logic/service_event.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The ServiceBloc is provided at app root via `app.dart` MultiBlocProvider.
    // We rely on ServiceList to dispatch the initial LoadServices event, but
    // provide a RefreshIndicator so the user can pull to refresh.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ServiceBloc>().add(LoadServices()),
            tooltip: 'Refresh services',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    onChanged: (q) {
                      // For now, search is client-side filtering to be implemented later.
                      // Keep this handler small to avoid adding business logic to the UI.
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: () => context.read<ServiceBloc>().add(LoadServices()), icon: const Icon(Icons.search)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<ServiceBloc>().add(LoadServices());
                // Wait briefly to allow BLoC to process. In production you might
                // await a stream or expose a Future from the BLoC.
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: const ServiceList(),
            ),
          ),
        ],
      ),
    );
  }
}
