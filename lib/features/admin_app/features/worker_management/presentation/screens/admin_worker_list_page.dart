import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_worker_bloc.dart';
import '../bloc/admin_worker_event.dart';
import '../bloc/admin_worker_state.dart';

class AdminWorkerListPage extends StatelessWidget {
  const AdminWorkerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<AdminWorkerBloc>().add(LoadWorkers());
    return Scaffold(
      appBar: AppBar(title: const Text('Workers')),
      body: BlocBuilder<AdminWorkerBloc, AdminWorkerState>(
        builder: (context, state) {
          if (state is AdminWorkerLoading) return const Center(child: CircularProgressIndicator());
          if (state is AdminWorkerError) return Center(child: Text('Error: ${state.message}'));
          if (state is AdminWorkerLoaded) {
            if (state.workers.isEmpty) return const Center(child: Text('No workers'));
            return ListView.builder(
              itemCount: state.workers.length,
              itemBuilder: (context, i) {
                final dynamic w = state.workers[i];

                return SwitchListTile(
                  title: Text((w.name as String?) ?? w.toString()),
                  subtitle: Text(
                    'Rating: ${((w.rating as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)} • Earnings: ₹${((w.earnings as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  ),
                  value: (w.isAvailable as bool?) ?? false,
                  onChanged: (v) => context.read<AdminWorkerBloc>().add(SetAvailabilityEvent(workerId: w.id as String, isAvailable: v)),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => context.read<AdminWorkerBloc>().add(DeleteWorkerEvent(w.id as String)),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

