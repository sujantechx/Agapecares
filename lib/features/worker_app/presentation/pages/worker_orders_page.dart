// filepath: lib/features/worker_app/presentation/pages/worker_orders_page.dart

import 'package:flutter/material.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/features/worker_app/presentation/widgets/job_card.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/blocs/worker_tasks_bloc.dart';
import '../../logic/blocs/worker_tasks_event.dart';
// Note: State import is no longer needed for the build method
// import '../../logic/blocs/worker_tasks_state.dart';

import '../../../../core/models/job_model.dart';

// NEW imports for photo upload, Cloud Functions and Firestore writes triggered by list updates
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:agapecares/features/worker_app/presentation/pages/worker_order_detail_page.dart';


class WorkerOrdersPage extends StatefulWidget {
  const WorkerOrdersPage({Key? key}) : super(key: key);

  @override
  State<WorkerOrdersPage> createState() => _WorkerOrdersPageState();
}

class _WorkerOrdersPageState extends State<WorkerOrdersPage> with TickerProviderStateMixin {
  final WorkerJobRepository _repo = WorkerJobRepository();
  List<JobModel> _jobs = [];
  bool _loading = true;
  bool _isOnline = true;
  final Set<String> _updatingJobIds = <String>{};

  late final TabController _tabController;

  // Realtime subscriptions
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assignedSub; // collectionGroup
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mirrorSub;   // workers/{workerId}/orders
  String? _workerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Resolve worker id and start subscription/initial load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeWorkerData();
    });

    _loadAvailability();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assignedSub?.cancel();
    _mirrorSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeWorkerData() async {
    // This logic is copied from WorkerHomePage to ensure it's identical
    try {
      final wid = await _resolveWorkerId();
      if (wid != null && wid.isNotEmpty) {
        _workerId = wid;
        // Start with an initial load
        await _loadJobs(workerId: wid);
        // Then listen for real-time updates
        _subscribeAssignedOrders(wid);
      } else {
        // no worker id resolved; fallback to loading without workerId
        debugPrint('[WorkerOrdersPage] No worker ID found, loading jobs anyway.');
        await _loadJobs();
      }
    } catch (e) {
      debugPrint('[WorkerOrdersPage] initializeWorkerData error: $e');
      await _loadJobs(); // Attempt to load even if ID resolution failed
    }
  }

  Future<String?> _resolveWorkerId() async {
    // This logic is identical to WorkerHomePage
    String? resolvedWorkerId;
    String? resolvedPhone;
    try {
      final session = context.read<SessionService>();
      final sUser = session.getUser();
      if (sUser != null && sUser.role.name == 'worker' && sUser.uid.isNotEmpty) {
        resolvedWorkerId = sUser.uid;
      }
      if (sUser != null && (sUser.phoneNumber ?? '').isNotEmpty) resolvedPhone = sUser.phoneNumber;
    } catch (_) {}

    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if ((resolvedWorkerId == null || resolvedWorkerId.isEmpty) && fbUser != null && fbUser.uid.isNotEmpty) {
        resolvedWorkerId = fbUser.uid;
        if ((fbUser.phoneNumber ?? '').isNotEmpty) resolvedPhone = fbUser.phoneNumber;
      }
    } catch (_) {}

    // Fallback: query users collection by phoneNumber if we still don't have a uid
    if ((resolvedWorkerId == null || resolvedWorkerId.isEmpty) && resolvedPhone != null && resolvedPhone.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: resolvedPhone)
            .where('role', isEqualTo: 'worker')
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) resolvedWorkerId = snap.docs.first.id;
      } catch (e) {
        debugPrint('[WorkerOrdersPage] failed to lookup worker by phone: $e');
      }
    }

    debugPrint('[WorkerOrdersPage] resolvedWorkerId=$resolvedWorkerId');
    return resolvedWorkerId;
  }

  Future<void> _loadAvailability() async {
    try {
      final avail = await _repo.getAvailability();
      if (avail != null) setState(() => _isOnline = avail);
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadAvailability error: $e');
    }
  }

  Future<void> _loadJobs({String? workerId}) async {
    if(!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _repo.getAssignedJobs(workerId: workerId);
      if (mounted) setState(() => _jobs = list);
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadJobs error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load jobs: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  //
  // --- THIS IS THE UPDATED/FIXED FUNCTION ---
  //
  void _subscribeAssignedOrders(String workerId) {
    // Cancel previous
    _assignedSub?.cancel();
    _mirrorSub?.cancel();

    // 1) Subscribe to worker mirror (most permissive under rules)
    try {
      _mirrorSub = FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .collection('orders')
          .orderBy('scheduledAt', descending: false)
          .snapshots()
          .listen((snap) {
        try {
          final list = snap.docs.map(_mapDocToJobModel).whereType<JobModel>().toList();
          _mergeListsAndSet(listSourceMirror: list);
        } catch (e) {
          debugPrint('[WorkerOrdersPage] mirror subscription parse error: $e');
        }
      }, onError: (e) {
        debugPrint('[WorkerOrdersPage] mirror subscription error: $e');
      });
    } catch (e) {
      debugPrint('[WorkerOrdersPage] mirror subscribe failed: $e');
    }

    // 2) Subscribe to collectionGroup for completeness (may require indexes/rules)
    try {
      _assignedSub = FirebaseFirestore.instance
          .collectionGroup('orders')
          .where('workerId', isEqualTo: workerId)
          .orderBy('scheduledAt', descending: false)
          .snapshots()
          .listen((snap) {
        try {
          final list = snap.docs.map(_mapDocToJobModel).whereType<JobModel>().toList();
          _mergeListsAndSet(listSourceCg: list);
        } catch (e) {
          debugPrint('[WorkerOrdersPage] collectionGroup subscription parse error: $e');
        }
      }, onError: (e) {
        debugPrint('[WorkerOrdersPage] collectionGroup subscription error (check rules/index): $e');
      });
    } catch (e) {
      debugPrint('[WorkerOrdersPage] collectionGroup subscribe failed: $e');
    }
  }

  // Robust address extraction helper for the worker UI (keeps logic local and tolerant)
  String _extractAddressFromData(Map<String, dynamic> data) {
    try {
      final snapRaw = data['addressSnapshot'];
      if (snapRaw is Map) {
        final snap = Map<String, dynamic>.from(snapRaw);
        final keys = ['address', 'line1', 'line_1', 'formatted', 'formattedAddress', 'formatted_address', 'fullAddress', 'street', 'streetAddress', 'addressLine', 'address_line', 'displayAddress'];
        for (final k in keys) {
          final v = snap[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        if (snap['location'] is Map) {
          final loc = Map<String, dynamic>.from(snap['location'] as Map);
          final lf = loc['address'] ?? loc['formatted_address'] ?? loc['formatted'];
          if (lf is String && lf.trim().isNotEmpty) return lf.trim();
        }
      }

      final topKeys = ['address', 'line1', 'formattedAddress', 'formatted_address', 'fullAddress', 'addressLine', 'streetAddress', 'displayAddress'];
      for (final k in topKeys) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }

      if (data['userAddresses'] is List && (data['userAddresses'] as List).isNotEmpty) {
        final first = (data['userAddresses'] as List).first;
        if (first is Map) {
          final m = Map<String, dynamic>.from(first);
          final candidates = ['address', 'line1', 'formatted', 'formattedAddress', 'displayAddress', 'streetAddress'];
          for (final k in candidates) {
            final v = m[k];
            if (v is String && v.trim().isNotEmpty) return v.trim();
          }
          final parts = <String>[];
          if (m['line1'] is String && (m['line1'] as String).trim().isNotEmpty) parts.add((m['line1'] as String).trim());
          if (m['city'] is String && (m['city'] as String).trim().isNotEmpty) parts.add((m['city'] as String).trim());
          if (m['state'] is String && (m['state'] as String).trim().isNotEmpty) parts.add((m['state'] as String).trim());
          if (m['postalCode'] is String && (m['postalCode'] as String).trim().isNotEmpty) parts.add((m['postalCode'] as String).trim());
          if (parts.isNotEmpty) return parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('[WorkerOrdersPage] _extractAddressFromData error: $e');
    }
    return '';
  }

  JobModel? _mapDocToJobModel(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    try {
      final data = d.data();
      final jobMap = <String, dynamic>{'id': d.id};
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

      // Resolve address robustly
      final extracted = _extractAddressFromData(data);
      jobMap['address'] = extracted.isNotEmpty ? extracted : (data['address'] ?? '');

      jobMap['customerName'] = data['userName'] ?? data['customerName'] ?? '';
      jobMap['customerPhone'] = data['userPhone'] ?? data['customerPhone'] ?? '';
      jobMap['scheduledAt'] = data['scheduledAt'] ?? data['scheduled_at'] ?? data['scheduledAtAt'];
      jobMap['scheduledEnd'] = data['scheduledEnd'] ?? data['scheduled_end'] ?? data['scheduledAtEnd'];
      jobMap['status'] = data['status'] ?? data['orderStatus'] ?? 'assigned';
      jobMap['isCod'] = data['paymentStatus'] == 'cod' || (data['isCod'] ?? data['is_cod'] ?? false);
      jobMap['specialInstructions'] = data['specialInstructions'] ?? data['special_instructions'] ?? '';
      jobMap['rating'] = data['rating'] ?? null;
      return JobModel.fromMap(jobMap, id: d.id);
    } catch (e) {
      debugPrint('[WorkerOrdersPage] _mapDocToJobModel parse error for ${d.id}: $e');
      return null;
    }
  }

  // merge helper: combine mirror and collectionGroup lists, preferring mirror fields when duplicates
  List<JobModel> _latestMirror = [];
  List<JobModel> _latestCg = [];
  void _mergeListsAndSet({List<JobModel>? listSourceMirror, List<JobModel>? listSourceCg}) {
    if (listSourceMirror != null) _latestMirror = listSourceMirror;
    if (listSourceCg != null) _latestCg = listSourceCg;

    // De-duplicate by id, prefer mirror entry
    final Map<String, JobModel> byId = {};
    for (final j in _latestCg) {
      byId[j.id] = j;
    }
    for (final j in _latestMirror) {
      byId[j.id] = j;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (mounted) setState(() => _jobs = merged);
  }

  // New helper: write status history in Firestore (best-effort)
  Future<void> _writeStatusHistory(String orderId, String status) async {
    try {
      final now = FieldValue.serverTimestamp();
      final wid = await _repo.getCurrentWorkerId();
      final data = {
        'status': status,
        'updatedAt': now,
        'by': wid ?? 'unknown',
      };
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).collection('statusHistory').add(data);
      } catch (e) {
        debugPrint('[WorkerOrdersPage] failed to write top-level statusHistory: $e');
      }
      if (wid != null) {
        try {
          await FirebaseFirestore.instance.collection('workers').doc(wid).collection('orders').doc(orderId).collection('statusHistory').add(data);
        } catch (e) {
          debugPrint('[WorkerOrdersPage] failed to write worker mirror statusHistory: $e');
        }
      }
    } catch (e) {
      debugPrint('[WorkerOrdersPage] writeStatusHistory error: $e');
    }
  }

  // New helper: call cloud function to notify user/admin of status change (best-effort)
  Future<void> _notifyStatusChange(String orderId, String status) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('notifyStatusChange');
      await callable.call({'orderId': orderId, 'status': status});
    } catch (e) {
      debugPrint('[WorkerOrdersPage] notifyStatusChange failed or not available: $e');
    }
  }

  // New helper: pick and upload a completion photo (used when marking completed from the list)
  Future<void> _pickAndUploadPhoto(String orderId) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('jobs').child(orderId).child('completion_$now.jpg');
      final snapshot = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await snapshot.ref.getDownloadURL();
      try {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
        await orderRef.update({'completionPhotos': FieldValue.arrayUnion([url])});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
      } catch (e) {
        debugPrint('[WorkerOrdersPage] failed to persist photo URL: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploaded but failed to save reference: $e')));
      }
    } catch (e) {
      debugPrint('[WorkerOrdersPage] _pickAndUploadPhoto error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    }
  }

  Future<void> _updateStatus(JobModel job, String newStatus) async {
    try {
      setState(() => _updatingJobIds.add(job.id));

      // Show a single confirmation dialog for any status change (OTP removed)
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm'),
          content: Text('Are you sure you want to mark this job as ${newStatus.replaceAll('_', ' ')}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
          ],
        ),
      ) ?? false;
      if (!confirmed) return;

      // If the worker is completing the job, and the order is COD/unpaid, try to mark it paid first (best-effort).
      if (newStatus.toLowerCase() == 'completed' || newStatus.toLowerCase() == 'complete') {
        try {
          final ps = (job.paymentStatus ?? '').toLowerCase();
          if (ps == 'cod' || ps == 'pending' || ps.isEmpty) {
            final paid = await _repo.updatePaymentStatus(job.id, 'paid', paymentRef: {'markedBy': 'worker', 'markedAt': FieldValue.serverTimestamp()});
            if (paid == null) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to mark COD as paid, aborting completion')));
              return;
            }
            // update local job reference with latest paymentStatus
            job = paid;
          }
        } catch (e) {
          debugPrint('[WorkerOrdersPage] pre-mark-as-paid failed for ${job.id}: $e');
        }
      }

      // Immediate backend sync via repository
      final updated = await _repo.updateJobStatus(job.id, newStatus);
      if (updated != null) {
        // The real-time subscription _should_ update the list, but we can
        // force it locally for a faster UI response.
        final idx = _jobs.indexWhere((j) => j.id == job.id);
        if (idx != -1) {
          if(mounted) setState(() => _jobs[idx] = updated);
        } else {
          // Not in the list? Force a reload just in case.
          await _loadJobs(workerId: _workerId);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${updated.status}')));

        // write history and notify (best-effort)
        await _writeStatusHistory(updated.id, newStatus);
        await _notifyStatusChange(updated.id, newStatus);

        // If completed, prompt to upload photo as proof
        if (newStatus.toLowerCase() == 'completed' || newStatus.toLowerCase() == 'complete') {
          final upload = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Upload Proof'),
              content: const Text('Do you want to upload a completion photo as proof of work?'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes'))],
            ),
          ) ??
              false;
          if (upload) await _pickAndUploadPhoto(job.id);
        }

        // If a WorkerTasksBloc exists, ask it to refresh so other UI (like home page) updates
        try {
          final bloc = context.read<WorkerTasksBloc>();
          bloc.add(RefreshWorkerOrders());
        } catch (_) {
          // No BLoC in context, that's fine
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job not found')));
      }
    } catch (e) {
      debugPrint('[WorkerOrdersPage] updateStatus error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    } finally {
      if (mounted) setState(() => _updatingJobIds.remove(job.id));
    }
  }

  Future<void> _setAvailability(bool v) async {
    setState(() => _isOnline = v);
    try {
      final repoDyn = _repo as dynamic;
      try {
        await repoDyn.setAvailability(v);
      } on NoSuchMethodError {
        try {
          await repoDyn.updateAvailability(v);
        } on NoSuchMethodError {
          debugPrint('[WorkerOrdersPage] repository has no setAvailability/updateAvailability method');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Availability saved locally')));
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v ? 'You are now Online' : 'You are now Offline')));
    } catch (e) {
      debugPrint('[WorkerOrdersPage] setAvailability error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set availability: $e')));
    }
  }

  // Helper: separate jobs into active (assigned/in_progress/on_my_way/arrived) and history (completed/cancelled)
  List<JobModel> _activeJobs(List<JobModel> all) {
    return all.where((j) {
      final s = j.status.toLowerCase();
      return !(s.contains('complete') || s.contains('cancel'));
    }).toList();
  }

  List<JobModel> _historyJobs(List<JobModel> all) {
    return all.where((j) {
      final s = j.status.toLowerCase();
      return (s.contains('complete') || s.contains('cancel'));
    }).toList();
  }

  // Visual feedback helper: map status to color
  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete')) return Colors.green;
    if (s.contains('arrived') || s.contains('in_progress') || s.contains('started')) return Colors.deepOrange;
    if (s.contains('on_my_way') || s.contains('on_way')) return Colors.blue;
    if (s.contains('pending') || s.contains('assigned')) return Colors.amber;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // These lists are now populated by the _jobs list,
    // which is updated by the _subscribeAssignedOrders subscription.
    final activeJobs = _activeJobs(_jobs);
    final historyJobs = _historyJobs(_jobs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Active Jobs'), Tab(text: 'History')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // We just reload our local data
              await _loadJobs(workerId: _workerId);
              // And poke the BLoC in case the home page needs to update
              try {
                context.read<WorkerTasksBloc>().add(RefreshWorkerOrders());
              } catch (_) {}
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // Active Jobs tab
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: activeJobs.isEmpty
                ? const Center(child: Text('No active jobs'))
                : RefreshIndicator(
              onRefresh: () => _loadJobs(workerId: _workerId),
              child: ListView.separated(
                itemCount: activeJobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final j = activeJobs[index];
                  return JobCard(
                    job: j,
                    isProminent: index == 0, // Highlight the first job
                    isUpdating: _updatingJobIds.contains(j.id),
                    onTap: () async {
                      try {
                        GoRouter.of(context).go(AppRoutes.workerOrderDetail.replaceFirst(':id', j.id));
                      } catch (_) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerOrderDetailPage(orderId: j.id)));
                      }
                    },
                    onStatusTap: (newStatus) async {
                      await _updateStatus(j, newStatus);
                    },
                  );
                },
              ),
            ),
          ),

          // History tab
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: historyJobs.isEmpty
                ? const Center(child: Text('No history yet'))
                : ListView.separated(
              itemCount: historyJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final j = historyJobs[index];
                return ListTile(
                  tileColor: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(j.serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (j.orderNumber != null && j.orderNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('#${j.orderNumber}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ]
                  ]),
                  subtitle: Text('${DateFormat.yMMMMd().format(j.scheduledAt)} • ${j.customerName}'),
                  trailing: Text(j.status.toUpperCase(), style: TextStyle(color: _statusColor(j.status), fontWeight: FontWeight.bold)),
                  onTap: () {
                    try {
                      GoRouter.of(context).go(AppRoutes.workerOrderDetail.replaceFirst(':id', j.id));
                    } catch (_) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkerOrderDetailPage(orderId: j.id)));
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Availability', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(_isOnline ? 'Online' : 'Offline', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Switch(value: _isOnline, onChanged: (v) => _setAvailability(v)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

