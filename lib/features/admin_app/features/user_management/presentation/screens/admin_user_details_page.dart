import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';

class AdminUserDetailsPage extends StatefulWidget {
  final String uid;
  const AdminUserDetailsPage({Key? key, required this.uid}) : super(key: key);

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
  }

  Widget _row(String label, String? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value ?? '-')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData || !snap.data!.exists) return const Center(child: Text('User not found'));

          final data = snap.data!.data()!;
          final createdAt = (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate().toString()
              : (data['createdAt']?.toString() ?? '-');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] ?? data['email'] ?? widget.uid, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _row('UID', widget.uid),
                _row('Email', data['email'] as String?),
                _row('Phone', data['phoneNumber'] as String?),
                _row('Role', data['role']?.toString()),
                _row('Verified', (data['isVerified'] == true) ? 'Yes' : 'No'),
                _row('Disabled', (data['disabled'] == true) ? 'Yes' : 'No'),
                _row('CreatedAt', createdAt),
                const Divider(height: 28),
                if (data['addresses'] != null) ...[
                  const Text('Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(data['addresses'] as List).map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(a.toString()),
                      )),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to admin user's orders page inside admin shell
                      final path = AppRoutes.adminUserOrders.replaceFirst(':id', widget.uid);
                      context.push(path);
                    },
                    child: const Text('View Orders'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      // Quick action: open admin user detail (same page) or other actions
                      final path = AppRoutes.adminUserDetail.replaceFirst(':id', widget.uid);
                      context.push(path);
                    },
                    child: const Text('Open in Admin Shell'),
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
