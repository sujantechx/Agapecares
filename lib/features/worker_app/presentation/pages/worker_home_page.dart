// filepath: lib/features/worker_app/presentation/pages/worker_home_page.dart
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

// Import the new drawer
import 'package:agapecares/features/worker_app/presentation/widgets/worker_drawer.dart';

import '../../../../core/models/service_model.dart';

// New import for JobCard
import '../widgets/job_card.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({Key? key}) : super(key: key);

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  UserModel? _profile;
  bool _loading = true;
  int _assignedCount = 0;
  int _incomingCount = 0; // This is your "pending" count
  int _completedCount = 0;

  // Services list (populated by _subscribeServices). Keep for future UI — suppress unused-field lint for now.
  // ignore: unused_field
  List<ServiceModel> _services = [];
  // New: assigned orders preview (job-shaped, sanitized for workers)
  List<JobModel> _assignedOrdersPreview = [];
  final WorkerJobRepository _jobRepo = WorkerJobRepository();

  // Realtime subscriptions
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _servicesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assignedSub;

  // Track per-job update in-flight states so we can show per-card loading indicators
  final Set<String> _updatingJobIds = <String>{};

  // Availability toggle state
  bool _isAvailable = true;

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
        if (sUser != null && sUser.phoneNumber != null && sUser.phoneNumber!.isNotEmpty) resolvedPhone = sUser.phoneNumber!;
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
      // Try repository first as a fast path (keeps previous behavior)
      List<JobModel> repoJobs = [];
      try {
        repoJobs = await _jobRepo.getAssignedJobs(workerId: workerId);
      } catch (_) {
        repoJobs = [];
      }

      // We'll collect snapshots that succeeded. Each query is executed independently so a permission error
      // for collectionGroup/top-level won't abort the whole method.
      final List<QuerySnapshot<Map<String, dynamic>>> results = [];

      // worker mirror (most likely readable by worker)
      try {
        final snap = await FirebaseFirestore.instance
            .collection('workers')
            .doc(workerId)
            .collection('orders')
            .get();
        results.add(snap);
      } catch (e) {
        debugPrint('[WorkerHomePage] _loadCounts: worker mirror read failed: $e');
      }

      // collectionGroup('orders') where workerId == workerId
      try {
        final snap = await FirebaseFirestore.instance
            .collectionGroup('orders')
            .where('workerId', isEqualTo: workerId)
            .get();
        results.add(snap);
      } catch (e) {
        debugPrint('[WorkerHomePage] _loadCounts: collectionGroup by worker read failed: $e');
      }

      // top-level orders where workerId == workerId
      try {
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .where('workerId', isEqualTo: workerId)
            .get();
        results.add(snap);
      } catch (e) {
        debugPrint('[WorkerHomePage] _loadCounts: top-level orders read failed: $e');
      }

      // collectionGroup where orderOwner == workerId (fallback)
      try {
        final snap = await FirebaseFirestore.instance
            .collectionGroup('orders')
            .where('orderOwner', isEqualTo: workerId)
            .get();
        results.add(snap);
      } catch (e) {
        debugPrint('[WorkerHomePage] _loadCounts: collectionGroup by owner read failed: $e');
      }

      // If we couldn't read any source, fall back to repository or zero counts
      if (results.isEmpty && repoJobs.isEmpty) {
        if (mounted) setState(() {
          _assignedCount = 0;
          _incomingCount = 0;
          _completedCount = 0;
        });
        debugPrint('[WorkerHomePage] _loadCounts: no readable sources found, counts set to 0');
        return;
      }

      // Combine and de-duplicate by a stable id. Prefer 'remoteId' if present, otherwise use document id.
      final Map<String, Map<String, dynamic>> combined = {};
      for (final snap in results) {
        for (final doc in snap.docs) {
          try {
            final data = Map<String, dynamic>.from(doc.data());
            final key = (data['remoteId'] ?? data['remote_id'] ?? doc.id).toString();
            // Keep the doc with latest updatedAt if present
            if (!combined.containsKey(key)) {
              final copy = <String, dynamic>{...data};
              copy['__source_doc_id'] = doc.id;
              combined[key] = copy;
            } else {
              // If both have updatedAt, keep the newest
              final existing = combined[key]!;
              final existingUpdated = existing['updatedAt'];
              final newUpdated = data['updatedAt'];
              if (newUpdated != null && existingUpdated != null) {
                try {
                  if (newUpdated.toString().compareTo(existingUpdated.toString()) > 0) {
                    final copy = <String, dynamic>{...data};
                    copy['__source_doc_id'] = doc.id;
                    combined[key] = copy;
                  }
                } catch (_) {}
              }
            }
          } catch (e) {
            debugPrint('[WorkerHomePage] _loadCounts: skipping doc ${doc.id} parse error: $e');
          }
        }
      }

      // Ensure repoJobs (JobModel) are included if repository returned items not present in combined set
      for (final j in repoJobs) {
        // JobModel.id is non-nullable; check emptiness only
        if (j.id.isNotEmpty && !combined.containsKey(j.id)) {
          combined[j.id] = {
            'status': j.status,
            'remoteId': j.id,
            '__source_doc_id': j.id,
          };
        }
      }

      // Normalize statuses and compute counts
      int completed = 0;
      int incoming = 0; // This is "Pending"
      int assigned = 0; // This is "Active/In-Progress"

      for (final entry in combined.values) {
        String raw = '';
        try {
          if (entry.containsKey('status')) raw = (entry['status'] ?? '').toString();
          if ((raw.isEmpty) && entry.containsKey('orderStatus')) raw = (entry['orderStatus'] ?? '').toString();
          if ((raw.isEmpty) && entry.containsKey('order_status')) raw = (entry['order_status'] ?? '').toString();
        } catch (_) {
          raw = '';
        }
        final status = raw.trim().toLowerCase();

        // --- THIS IS THE CALCULATION LOGIC ---
        if (status.contains('complete')) {
          completed++;
        } else if (status.contains('pending') || status.contains('incoming') || status == 'awaiting') {
          // "incoming" count IS the "pending" count
          incoming++;
        } else {
          // anything else treat as assigned/active
          // (e.g., 'accepted', 'on_my_way', 'arrived', 'in_progress', 'paused')
          assigned++;
        }
      }

      // Update UI state
      if (mounted) {
        setState(() {
          _assignedCount = assigned;
          _incomingCount = incoming;
          _completedCount = completed;
        });
      }

      debugPrint('[WorkerHomePage] _loadCounts combined=${combined.length} assigned=${_assignedCount} incoming=${_incomingCount} completed=${_completedCount}');
    } catch (e) {
      debugPrint('[WorkerHomePage] _loadCounts error: $e');
    }
  }

  Future<void> _changeJobStatus(String orderId, String status) async {
    try {
      // mark this job as updating (per-card loading) so UI shows spinner only for this job
      setState(() => _updatingJobIds.add(orderId));
      final updated = await _jobRepo.updateJobStatus(orderId, status);
      if (updated != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order ${updated.id} marked $status')));
          // Refresh preview; repository/real-time subscription should reflect change, but reload preview to be safe
          final wid = await _jobRepo.getCurrentWorkerId();
          if (wid != null) await _loadAssignedPreview(wid);

          // Navigate to order detail page for the updated order
          try {
            GoRouter.of(context).go(AppRoutes.workerOrderDetail.replaceFirst(':id', updated.id));
          } catch (_) {
            Navigator.of(context).pushNamed(AppRoutes.workerOrderDetail.replaceFirst(':id', updated.id));
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update order')));
      }
    } catch (e) {
      debugPrint('[WorkerHomePage] _changeJobStatus error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      // clear the per-job loading flag
      if (mounted) setState(() => _updatingJobIds.remove(orderId));
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

      // --- ADDED DRAWER ---
      drawer: const WorkerDrawer(),

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
                  // Header: Greeting + status + availability toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            child: Text(
                              (() {
                                final name = _profile?.name ?? '';
                                if (name.isNotEmpty) {
                                  return name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).join();
                                }
                                return 'W';
                              })(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good ${_greeting()}, ${_profile?.name ?? 'Worker'}!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(_isAvailable ? Icons.circle : Icons.circle, color: _isAvailable ? Colors.green : Colors.red, size: 12),
                                  const SizedBox(width: 6),
                                  Text(_isAvailable ? '🟢 Online' : '🔴 Offline', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Availability Toggle
                      Column(
                        children: [
                          const Text('Available for new jobs', style: TextStyle(fontSize: 12)),
                          Switch(
                            value: _isAvailable,
                            onChanged: (v) {
                              setState(() => _isAvailable = v);
                              // TODO: persist availability to backend (low-risk, deferred)
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startNextJob,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Next Job'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _viewRoute,
                        icon: const Icon(Icons.map),
                        label: const Text('View Route'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _callAdmin,
                        icon: const Icon(Icons.call),
                        label: const Text('Call Admin'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Today's Jobs header
                  const Text("Today's Jobs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Job list (preview). Highlight current/next job
                  _assignedOrdersPreview.isEmpty
                      ? const Text('No jobs for today')
                      : Expanded(
                          child: ListView.separated(
                            itemCount: _assignedOrdersPreview.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final job = _assignedOrdersPreview[index];
                              final isNext = index == 0; // treat first item as current/next prominently
                              return JobCard(
                                job: job,
                                isProminent: isNext,
                                onTap: () {
                                  try {
                                    GoRouter.of(context).go(AppRoutes.workerOrderDetail.replaceFirst(':id', job.id));
                                  } catch (_) {
                                    Navigator.of(context).pushNamed(AppRoutes.workerOrderDetail.replaceFirst(':id', job.id));
                                  }
                                },
                                onStatusTap: (newStatus) async {
                                  // Confirm when marking completed
                                  if (newStatus == 'completed') {
                                    final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Mark as completed?'),
                                            content: const Text('Do you want to mark this job as completed?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!ok) return;
                                  }
                                  await _changeJobStatus(job.id, newStatus);
                                },
                                isUpdating: _updatingJobIds.contains(job.id),
                              );
                            },
                          ),
                        ),

                  const SizedBox(height: 12),

                  // Small footer counts summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('$_assignedCount', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Incoming', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('$_incomingCount', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          Column(
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
                ],
              ),
            ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _startNextJob() {
    // TODO: implement start next job logic
    debugPrint('[WorkerHomePage] Start Next Job tapped');
  }

  void _viewRoute() {
    // TODO: implement view route logic
    debugPrint('[WorkerHomePage] View Route tapped');
  }

  void _callAdmin() {
    // TODO: implement call admin logic
    debugPrint('[WorkerHomePage] Call Admin tapped');
  }
}

