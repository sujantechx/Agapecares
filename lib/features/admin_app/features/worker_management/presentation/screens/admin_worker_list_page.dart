import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/worker_model.dart';
import '../bloc/admin_worker_bloc.dart';
import '../bloc/admin_worker_event.dart';
import '../bloc/admin_worker_state.dart';
import 'package:agapecares/features/admin_app/features/worker_management/presentation/screens/admin_worker_details_page.dart';

class AdminWorkerListPage extends StatefulWidget {

  const AdminWorkerListPage({super.key});

  @override
  State<AdminWorkerListPage> createState() => _AdminWorkerListPageState();
}

class _AdminWorkerListPageState extends State<AdminWorkerListPage> {

  @override
  void initState() {
    super.initState();
    // Load workers via AdminWorkerBloc
    context.read<AdminWorkerBloc>().add(LoadWorkers());
  }

  // Pull-to-refresh helper: triggers a reload and completes when loaded or failed.
  Future<void> _refresh() async {
    final bloc = context.read<AdminWorkerBloc>();
    bloc.add(LoadWorkers());
    // Wait until we get a loaded or error state so RefreshIndicator completes visibly
    await bloc.stream.firstWhere((s) => s is AdminWorkerLoaded || s is AdminWorkerError);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workers')),
      body: BlocBuilder<AdminWorkerBloc, AdminWorkerState>(
        builder: (context, state) {
          if (state is AdminWorkerLoading) return const Center(child: CircularProgressIndicator());
          if (state is AdminWorkerError) return Center(child: Text('Error: ${state.message}'));
          if (state is AdminWorkerLoaded) {
            if (state.workers.isEmpty) return RefreshIndicator(onRefresh: _refresh, child: ListView(children: const [SizedBox(height: 120), Center(child: Text('No workers'))]));

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                itemCount: state.workers.length,
                itemBuilder: (context, i) {
                  final WorkerModel w = state.workers[i];

                  // Fetch live worker doc for fields not present on WorkerModel (eg. isAvailable)
                  final future = Future.wait<DocumentSnapshot>([
                    FirebaseFirestore.instance.collection('workers').doc(w.uid).get(),
                    FirebaseFirestore.instance.collection('users').doc(w.uid).get(),
                  ]);

                  return FutureBuilder<List<DocumentSnapshot>>(
                    future: future,
                    builder: (context, snap) {
                      bool isAvailable = false;
                      String displayName = w.uid;
                      String subtitle = '${w.status.name} • ${w.ratingAvg.toStringAsFixed(1)}★ (${w.ratingCount})';

                      if (snap.hasData) {
                        final workerDoc = snap.data![0];
                        final userDoc = snap.data![1];
                        final workerData = workerDoc.data() as Map<String, dynamic>?;
                        final userData = userDoc.data() as Map<String, dynamic>?;

                        isAvailable = workerData?['isAvailable'] as bool? ?? false;
                        displayName = userData?['name'] as String? ?? userData?['email'] as String? ?? w.uid;
                      }

                      return ListTile(
                        title: Text(displayName),
                        subtitle: Text(subtitle),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isAvailable,
                              onChanged: (v) => context.read<AdminWorkerBloc>().add(SetAvailabilityEvent(workerId: w.uid, isAvailable: v)),
                            ),
                            // Delete action removed: admins should not delete workers via the admin UI.
                            const SizedBox(width: 8),
                          ],
                        ),
                        onTap: () {
                          // Navigate to a full details page for the worker
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminWorkerDetailsPage(uid: w.uid)));
                        },
                      );
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
