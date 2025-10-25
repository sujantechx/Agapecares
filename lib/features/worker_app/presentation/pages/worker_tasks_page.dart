// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\pages\worker_tasks_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../logic/blocs/worker_tasks_bloc.dart';
import '../../logic/blocs/worker_tasks_event.dart';
import '../../logic/blocs/worker_tasks_state.dart';
import '../widgets/order_list_tile.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;
import 'package:agapecares/core/services/session_service.dart';

class WorkerTasksPage extends StatefulWidget {
  const WorkerTasksPage({Key? key}) : super(key: key);

  @override
  State<WorkerTasksPage> createState() => _WorkerTasksPageState();
}

class _WorkerTasksPageState extends State<WorkerTasksPage> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load after the first frame so the global BlocProvider is available in context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<WorkerTasksBloc>().add(const LoadWorkerOrders());
      } catch (_) {
        // If the global bloc isn't mounted for some reason, ignore silently.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Jobs')),
      body: BlocConsumer<WorkerTasksBloc, WorkerTasksState>(
        listener: (context, state) {
          if (state is WorkerTasksUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
          } else if (state is WorkerTasksUpdateFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is WorkerTasksLoading || state is WorkerTasksInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is WorkerTasksFailure) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is WorkerTasksEmpty) {
            return const Center(child: Text('No assignments'));
          }
          if (state is WorkerTasksLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<WorkerTasksBloc>().add(RefreshWorkerOrders());
              },
              child: ListView(
                children: [
                  if (state.today.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...state.today.map((o) => OrderListTile(
                          order: o,
                          onTap: () {
                            try {
                              GoRouter.of(context).go('/worker/orders/${o.id}');
                            } catch (_) {
                              Navigator.of(context).pushNamed('/worker/orders/${o.id}');
                            }
                          },
                        )),
                  ],
                  if (state.upcoming.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...state.upcoming.map((o) => OrderListTile(
                          order: o,
                          onTap: () {
                            try {
                              GoRouter.of(context).go('/worker/orders/${o.id}');
                            } catch (_) {
                              Navigator.of(context).pushNamed('/worker/orders/${o.id}');
                            }
                          },
                        )),
                  ],
                  if (state.past.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Past', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...state.past.map((o) => OrderListTile(
                          order: o,
                          onTap: () {
                            try {
                              GoRouter.of(context).go('/worker/orders/${o.id}');
                            } catch (_) {
                              Navigator.of(context).pushNamed('/worker/orders/${o.id}');
                            }
                          },
                        )),
                  ],
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
