import 'package:flutter/material.dart';
import 'package:agapecares/core/models/user_model.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:agapecares/core/models/order_model.dart';
import 'package:agapecares/core/models/job_model.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/features/worker_app/presentation/pages/create_service_page.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:agapecares/app/routes/app_routes.dart';

import '../../../../core/models/service_model.dart';

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
  // New: assigned orders preview (job-shaped, sanitized for workers)
  List<JobModel> _assignedOrdersPreview = [];
  final WorkerJobRepository _jobRepo = WorkerJobRepository();

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
      // Avoid reading WorkerRepository/OrderRepository via context to prevent provider type collisions.
      // We'll read directly from Firestore where needed.

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
        // Fetch worker profile directly to avoid provider type collisions
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(resolvedWorkerId).get();
          if (doc.exists) {
            final candidate = UserModel.fromFirestore(doc);
            setState(() => _profile = candidate);
          } else {
            // Fallback: maybe worker profile lives in `workers/{id}` collection
            try {
              final wdoc = await FirebaseFirestore.instance.collection('workers').doc(resolvedWorkerId).get();
              if (wdoc.exists) {
                final wdata = wdoc.data();
                if (wdata != null) {
                  // Map minimal fields into UserModel-like shape
                  final candidate = UserModel(
                    uid: resolvedWorkerId,
                    name: (wdata['name'] as String?) ?? (wdata['workerName'] as String?) ?? 'Worker',
                    email: (wdata['email'] as String?) ?? '',
                    phoneNumber: (wdata['phoneNumber'] as String?) ?? (wdata['phone'] as String?) ?? '',
                    role: UserRole.worker, createdAt: Timestamp.now(),
                  );
                  setState(() => _profile = candidate);
                }
              }
            } catch (e) {
              debugPrint('[WorkerHomePage] failed to fetch worker-profile from workers collection: $e');
            }
          }
        } catch (e) {
          debugPrint('[WorkerHomePage] failed to fetch profile directly: $e');
        }

        // Use per-worker mirror for assigned orders so security rules allow reads
        await _loadCounts(resolvedWorkerId);
        // Load a small preview using WorkerJobRepository which maps fields into JobModel
        _loadAssignedPreview(resolvedWorkerId);

        // Subscribe to real-time updates for assigned orders so UI updates live
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
            .map<ServiceModel>((d) => ServiceModel.fromMap(d.data()))
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
    // Cancel previous subscription
    _assignedSub?.cancel();
    _assignedSub = FirebaseFirestore.instance
        .collection('workers')
        .doc(workerId)
        .collection('orders')
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .listen((snap) {
      try {
        final List<JobModel> list = snap.docs.map((d) {
          try {
            final data = d.data();
            final jobMap = <String, dynamic>{};
            jobMap['id'] = d.id;
            if (data['items'] is List && (data['items'] as List).isNotEmpty) {
              final first = (data['items'] as List).first as Map<String, dynamic>;
              jobMap['serviceName'] = first['serviceName'] ?? first['optionName'] ?? data['serviceName'];
              jobMap['inclusions'] = (data['items'] as List).map((it) {
                try {
                  final m = Map<String, dynamic>.from(it as Map);
                  return m['optionName']?.toString() ?? m['serviceName']?.toString() ?? '';
                } catch (_) {
                  return '';
                }
              }).where((s) => s.isNotEmpty).toList();
            } else {
              jobMap['serviceName'] = data['serviceName'] ?? '';
              jobMap['inclusions'] = data['inclusions'] ?? [];
            }
            if (data['addressSnapshot'] is Map && (data['addressSnapshot'] as Map).containsKey('address')) {
              jobMap['address'] = (data['addressSnapshot'] as Map)['address'] ?? data['address'] ?? '';
            } else {
              jobMap['address'] = data['address'] ?? '';
            }
            jobMap['customerName'] = data['userName'] ?? data['customerName'] ?? '';
            jobMap['customerPhone'] = data['userPhone'] ?? data['customerPhone'] ?? '';
            jobMap['scheduledAt'] = data['scheduledAt'] ?? data['scheduled_at'] ?? data['scheduledAtAt'];
            jobMap['status'] = data['status'] ?? data['orderStatus'] ?? 'assigned';
            jobMap['isCod'] = data['paymentStatus'] == 'cod' || (data['isCod'] ?? data['is_cod'] ?? false);
            jobMap['specialInstructions'] = data['specialInstructions'] ?? data['special_instructions'] ?? '';
            jobMap['rating'] = data['rating'] ?? null;
            return JobModel.fromMap(jobMap, id: d.id);
          } catch (e) {
            debugPrint('[WorkerHomePage] _subscribeAssignedOrders parse error for ${d.id}: $e');
            rethrow;
          }
        }).toList();

        // Update counts and preview
        final completed = list.where((o) => o.status == 'completed' || o.status == 'COMPLETED' || o.status == OrderStatus.completed.name).toList();
        final inProgress = list.where((o) => !(o.status == 'completed' || o.status == 'COMPLETED' || o.status == OrderStatus.completed.name)).toList();
        if (mounted) setState(() {
          _assignedOrdersPreview = list.take(10).toList();
          _assignedCount = inProgress.length;
          _completedCount = completed.length;
        });
        debugPrint('[WorkerHomePage] _subscribeAssignedOrders snapshot count=${list.length} assigned=${_assignedCount} completed=${_completedCount}');
      } catch (e) {
        debugPrint('[WorkerHomePage] _subscribeAssignedOrders handler error: $e');
      }
    }, onError: (e) {
      debugPrint('[WorkerHomePage] _assignedSub error: $e');
    });
  }

  Future<void> _loadAssignedPreview(String workerId) async {
    try {
      final list = await _jobRepo.getAssignedJobs(workerId: workerId);
      debugPrint('[WorkerHomePage] _loadAssignedPreview fetched ${list.length} jobs for worker=$workerId');
      if (list.isNotEmpty) debugPrint('[WorkerHomePage] job ids: ${list.map((j) => j.id).toList()}');
      if (mounted) setState(() => _assignedOrdersPreview = list.take(10).toList());
    } catch (e) {
      debugPrint('[WorkerHomePage] _loadAssignedPreview error: $e');
    }
  }

  Future<void> _loadCounts(String workerId) async {
    try {
      // assigned & completed for this worker from per-worker mirror
      final assignedSnap = await FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .collection('orders')
          .get();
      final assigned = assignedSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();

      // incoming: not available to workers (restricted by rules) — show 0 or fetch via admin route
      final incoming = <OrderModel>[];

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
                GoRouter.of(context).go('/login');
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
              try {
                GoRouter.of(context).go(AppRoutes.workerProfile);
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
                  /// assigned, incoming, completed counts
                  InkWell(
                    onTap: () {
                      try {
                        GoRouter.of(context).go(AppRoutes.workerTasks);
                      } catch (_) {
                        Navigator.of(context).pushNamed(AppRoutes.workerTasks);
                      }
                    },
                    child: Card(
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
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () {
                      try {
                        GoRouter.of(context).go(AppRoutes.workerOrders);
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
                              final j = _assignedOrdersPreview[i];
                              final scheduled = j.scheduledAt.toLocal();
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(j.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${j.address}'),
                                      const SizedBox(height: 4),
                                      Text('${scheduled.year}-${scheduled.month.toString().padLeft(2,'0')}-${scheduled.day.toString().padLeft(2,'0')} ${scheduled.hour.toString().padLeft(2,'0')}:${scheduled.minute.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('${j.customerName} • ${j.customerPhone}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                  trailing: Text(j.status.toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
                                  onTap: () {
                                    try {
                                      // Use the route template but replace the :id placeholder with the actual id
                                      GoRouter.of(context).go(AppRoutes.workerOrderDetail.replaceFirst(':id', j.id));
                                    } catch (_) {
                                      // Fallback for environments without GoRouter: push the concrete path as the route name
                                      Navigator.of(context).pushNamed(AppRoutes.workerOrderDetail.replaceFirst(':id', j.id));
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
