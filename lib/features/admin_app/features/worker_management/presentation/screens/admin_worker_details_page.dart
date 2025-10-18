import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';
import 'package:agapecares/app/routes/route_helpers.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/widgets/select_order_for_worker_dialog.dart';

class AdminWorkerDetailsPage extends StatefulWidget {
  final String uid;
  const AdminWorkerDetailsPage({Key? key, required this.uid}) : super(key: key);

  @override
  State<AdminWorkerDetailsPage> createState() => _AdminWorkerDetailsPageState();
}

class _AdminWorkerDetailsPageState extends State<AdminWorkerDetailsPage> {
  late final Future<List<DocumentSnapshot<Map<String, dynamic>>>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.wait([
      FirebaseFirestore.instance.collection('workers').doc(widget.uid).get(),
      FirebaseFirestore.instance.collection('users').doc(widget.uid).get(),
    ]);
  }

  Widget _row(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value ?? '-')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker details')),
      body: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: Text('Worker not found'));

          final workerDoc = snap.data![0];
          final userDoc = snap.data![1];

          if (!workerDoc.exists && !userDoc.exists) return const Center(child: Text('Worker not found'));

          final workerData = workerDoc.exists ? workerDoc.data() as Map<String, dynamic>? : null;
          final userData = userDoc.exists ? userDoc.data() as Map<String, dynamic>? : null;

          final name = userData?['name'] ?? userData?['email'] ?? widget.uid;
          final status = workerData?['status'] ?? userData?['status'] ?? '-';
          final skills = (workerData?['skills'] as List?) ?? (userData?['skills'] as List?) ?? <dynamic>[];
          final ratingAvg = (workerData?['ratingAvg'] ?? userData?['ratingAvg'])?.toString() ?? '-';
          final ratingCount = (workerData?['ratingCount'] ?? userData?['ratingCount'])?.toString() ?? '0';
          final isAvailable = (workerData?['isAvailable'] ?? userData?['isAvailable']) == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toString(), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _row('UID', widget.uid),
                _row('Email', userData?['email'] as String?),
                _row('Phone', userData?['phoneNumber'] as String?),
                _row('Status', status?.toString()),
                _row('Available', isAvailable ? 'Yes' : 'No'),
                _row('Rating', '$ratingAvg ($ratingCount reviews)'),
                const Divider(height: 28),
                const Text('Skills', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (skills.isEmpty) const Text('No skills listed') else ...skills.map((s) => Text('- ${s.toString()}')),
                const SizedBox(height: 20),
                if (workerData != null && workerData['notes'] != null) ...[
                  const Divider(),
                  const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(workerData['notes'].toString()),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to admin worker's orders page inside admin shell using RouteHelper
                      final path = RouteHelper.adminWorkerOrders(widget.uid);
                      context.push(path);
                    },
                    child: const Text('View Assigned Orders'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      // Open order selection dialog and perform assignment
                      final userName = userData?['name'] as String?;
                      final assigned = await showDialog<bool?>(context: context, builder: (_) => SelectOrderForWorkerDialog(workerId: widget.uid, workerName: userName));
                      if (assigned == true) {
                        // Refresh or show a confirmation
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker assigned to order')));
                      }
                    },
                    child: const Text('Assign to Order'),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
