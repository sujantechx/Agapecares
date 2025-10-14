import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/logic/service_bloc.dart';
import '../../services/logic/service_event.dart';
import '../../services/logic/service_state.dart';
import 'service_card.dart';

/// ServiceList widget
///
/// This widget is a thin UI layer that separates presentation from business
/// logic. It expects a [ServiceBloc] to be available in the widget tree.
///
/// If you want to use the ServiceList in isolation you can wrap it with
/// [ServiceListProvider] which will create a ServiceBloc from the repository
/// available in the context.
class ServiceList extends StatefulWidget {
  const ServiceList({super.key});

  @override
  State<ServiceList> createState() => _ServiceListState();
}

class _ServiceListState extends State<ServiceList> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Dispatch the initial load event exactly once. Using didChangeDependencies
      // ensures that the Bloc is already available when the widget is inserted.
      final bloc = context.read<ServiceBloc?>();
      if (bloc != null) {
        bloc.add(LoadServices());
      } else {
        // If ServiceBloc is not available, do nothing here. The parent should
        // provide it or use ServiceListProvider to supply one. Avoid crashing.
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServiceBloc, ServiceState>(
      builder: (context, state) {
        if (state is ServiceLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ServiceError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load services'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.read<ServiceBloc>().add(LoadServices()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is ServiceLoaded) {
          final services = state.services;
          if (services.isEmpty) {
            return const Center(child: Text('No services available'));
          }
          return ListView.separated(
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemBuilder: (context, index) {
              final s = services[index];
              return ServiceCard(service: s);
            },
          );
        }

        // Default fallback
        return const SizedBox.shrink();
      },
    );
  }
}

/// A convenience wrapper that ensures a [ServiceBloc] is available for
/// descendants. It creates a ServiceBloc using the registered ServiceRepository
/// from the widget tree (via RepositoryProvider) when no bloc is already present.
class ServiceListProvider extends StatelessWidget {
  final Widget child;

  const ServiceListProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // If a ServiceBloc already exists in the tree, just return the child.
    try {
      context.read<ServiceBloc>();
      return child;
    } catch (_) {
      // No existing ServiceBloc, create one using the repository from context.
      final repo = RepositoryProvider.of<dynamic>(context);
      // We avoid importing specific repository types here to keep this wrapper
      // generic; callers typically set up RepositoryProvider<ServiceRepository>
      // at app root and the service locator in `app.dart` already does so.
      return BlocProvider<ServiceBloc>(
        create: (ctx) => ServiceBloc(serviceRepository: ctx.read()),
        child: child,
      );
    }
  }
}
