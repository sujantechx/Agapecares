import 'package:flutter/material.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_repository.dart';
import 'package:agapecares/core/models/user_model.dart';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:agapecares/core/models/order_model.dart';
import 'package:agapecares/features/worker_app/presentation/pages/create_service_page.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:agapecares/app/routes/app_routes.dart';

import '../../../../core/models/service_model.dart';
import '../../../admin_app/features/order_management/domain/repositories/order_repository.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({Key? key}) : super(key: key);

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  UserModel? _profile;
  bool _loading = true;
  int _assignedCount = 0;
  int _incomingCount = 0;
  int _completedCount = 0;

  // New: services list
  List<ServiceModel> _services = [];
  // New: assigned orders preview
  List<OrderModel> _assignedOrdersPreview = [];

  // Realtime subscriptions
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assignedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _loading = true);
      final repo = context.read<WorkerRepository>();
      final orderRepo = context.read<OrderRepository>();
      // final serviceRepo = context.read<ServiceRepository>(); // not used

      // Resolve worker id from SessionService first, then FirebaseAuth as fallback
      String? resolvedWorkerId;
      String? resolvedPhone;
      try {
        final session = context.read<SessionService>();
        final sUser = session.getUser();
        if (sUser != null && sUser.role == UserRole.worker && sUser.uid.isNotEmpty) {
          resolvedWorkerId = sUser.uid;
        }
        if (sUser != null && sUser.phoneNumber != null && sUser.phoneNumber!.isNotEmpty) resolvedPhone = sUser.phoneNumber;
      } catch (_) {}

      final fbUser = FirebaseAuth.instance.currentUser;
      if (resolvedWorkerId == null && fbUser != null && fbUser.uid.isNotEmpty) {
        resolvedWorkerId = fbUser.uid;
        if ((fbUser.phoneNumber ?? '').isNotEmpty) resolvedPhone = fbUser.phoneNumber!;
      }

      // Fallback: query users collection by phoneNumber if we still don't have a uid
      if ((resolvedWorkerId == null || resolvedWorkerId.isEmpty) && resolvedPhone != null && resolvedPhone.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', isEqualTo: resolvedPhone)
              .where('role', isEqualTo: UserRole.worker.name)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            resolvedWorkerId = snap.docs.first.id;
          }
        } catch (e) {
          debugPrint('[WorkerHomePage] failed to lookup worker by phone: $e');
        }
      }

      debugPrint('[WorkerHomePage] resolvedWorkerId=$resolvedWorkerId');

      if (resolvedWorkerId != null && resolvedWorkerId.isNotEmpty) {
        final candidate = await repo.fetchWorkerProfile(resolvedWorkerId);
        if (candidate != null) setState(() => _profile = candidate);
        // Use realtime subscriptions so the UI updates as Firestore data changes
        await _loadCounts(orderRepo, resolvedWorkerId);
        _subscribeAssignedOrders(resolvedWorkerId);
      }

      // Load services regardless of auth
      _subscribeServices();
    } catch (e) {
      debugPrint('[WorkerHomePage] loadProfile error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }


  void _subscribeServices() {
    // Cancel previous subscription
    _servicesSub?.cancel();
    _servicesSub = FirebaseFirestore.instance.collection('services').snapshots().listen((snap) {
      try {
        final List<ServiceModel> list = snap.docs
            .map<ServiceModel>((d) => ServiceModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        debugPrint('[WorkerHomePage] services snapshot count=${list.length}');
        if (mounted) setState(() => _services = list);
      } catch (e) {
        debugPrint('[WorkerHomePage] services snapshot parse error: $e');
      }
    }, onError: (e) {
      debugPrint('[WorkerHomePage] services snapshot error: $e');
    });
  }


  void _subscribeAssignedOrders(String workerId) {
    _assignedSub?.cancel();
    _assignedSub = FirebaseFirestore.instance
        .collection('orders')
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      try {
        final list = snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        if (mounted) {
          setState(() {
            _assignedOrdersPreview = list.take(10).toList();
            // orderStatus is an enum on OrderModel; use `.name` for string comparisons
            _assignedCount = list.where((o) => o.orderStatus != OrderStatus.completed).length;
            _completedCount = list.where((o) => o.orderStatus == OrderStatus.completed).length;
          });
        }
        debugPrint('[WorkerHomePage] assigned snapshot count=${list.length}');
      } catch (e) {
        debugPrint('[WorkerHomePage] assigned snapshot parse error: $e');
      }
    }, onError: (e) {
      debugPrint('[WorkerHomePage] assigned snapshot error: $e');
    });
  }

  Future<void> _loadCounts(OrderRepository orderRepo, String workerId) async {
    try {
      // incoming: orders placed and not yet assigned
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
      final incomingSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('workerId', isNull: true)
          .where('createdAt', isGreaterThanOrEqualTo: cutoff)
          .get();
      final incoming = incomingSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();

      // assigned & completed for this worker: query Firestore directly
      final assignedSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('workerId', isEqualTo: workerId)
          .get();
      final assigned = assignedSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();

      // orderStatus is an enum on OrderModel; compare against OrderStatus.completed
      final completed = assigned.where((o) => o.orderStatus == OrderStatus.completed).toList();
      final inProgress = assigned.where((o) => o.orderStatus != OrderStatus.completed).toList();
      setState(() {
        _incomingCount = incoming.length;
        _assignedCount = inProgress.length;
        _completedCount = completed.length;
      });
      debugPrint('[WorkerHomePage] counts incoming=${_incomingCount} assigned=${_assignedCount} completed=${_completedCount} (workerId=$workerId)');
    } catch (e) {
      debugPrint('[WorkerHomePage] _loadCounts error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                // Clear local session if available
                try {
                  final session = context.read<SessionService>();
                  await session.clear();
                } catch (_) {}
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                debugPrint('[WorkerHomePage] logout failed: $e');
              }
              // Route back to login
              try {
                final go = (context as dynamic).go as void Function(String);
                go('/login');
              } catch (_) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              // Refresh profile/services/work counts
              try {
                setState(() => _loading = true);
                await _loadProfile();
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Navigate to worker profile using GoRouter if available
              final go = (context as dynamic).go as void Function(String);
              try {
                go(AppRoutes.workerProfile);
              } catch (_) {
                Navigator.of(context).pushNamed(AppRoutes.workerProfile);
              }
            },
          )
        ],
      ),

      // Add FloatingActionButton (create service)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateServicePage()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Service',
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        child: Text(
                          _profile?.name != null && _profile!.name!.isNotEmpty
                              ? (_profile!.name!.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join())
                              : 'W',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile?.name ?? 'Worker',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(_profile?.email ?? 'No email available'),
                          const SizedBox(height: 2),
                          Text(_profile?.phoneNumber ?? ''),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('$_assignedCount', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Incoming', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('$_incomingCount', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Completed', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('$_completedCount', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final go = (context as dynamic).go as void Function(String);
                      try {
                        go(AppRoutes.workerOrders);
                      } catch (_) {
                        Navigator.of(context).pushNamed(AppRoutes.workerOrders);
                      }
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View Orders'),
                  ),
                  const SizedBox(height: 12),
                  // New sections: Services and Assigned Work preview
                  const Text('Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _services.isEmpty
                      ? const Text('No services available')
                      : SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _services.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final s = _services[i];
                              return Card(
                                child: Container(
                                  width: 200,
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text('₹${s.basePrice.toStringAsFixed(2)}'),
                                      const SizedBox(height: 6),
                                      Expanded(child: Text(s.description, maxLines: 3, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 12),
                  const Text('Your Work', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _assignedOrdersPreview.isEmpty
                      ? const Text('No assigned work')
                      : Expanded(
                          child: ListView.builder(
                            itemCount: _assignedOrdersPreview.length,
                            itemBuilder: (context, i) {
                              final o = _assignedOrdersPreview[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text('Order • ${o.orderNumber.isNotEmpty ? o.orderNumber : o.id}'),
                                  subtitle: Text('${o.userId} • ₹${o.total.toStringAsFixed(2)}'),
                                  trailing: Text(o.orderStatus.name),
                                  onTap: () {
                                    final go = (context as dynamic).go as void Function(String);
                                    try {
                                      go(AppRoutes.workerOrders);
                                    } catch (_) {
                                      Navigator.of(context).pushNamed(AppRoutes.workerOrders);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _servicesSub?.cancel();
    _assignedSub?.cancel();
    super.dispose();
  }
}
