import 'package:agapecares/core/models/job_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class WorkerJobRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkerJobRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<String?> _resolveWorkerId() async {
    // Try session service first (caller may provide it via Provider)
    try {
      // Note: This method is intentionally tolerant: if no current user/session, we return null
      // Caller should handle null workerId.
      final user = _auth.currentUser;
      if (user != null && user.uid.isNotEmpty) return user.uid;
    } catch (e) {
      debugPrint('[WorkerJobRepository] _resolveWorkerId firebase auth error: $e');
    }
    return null;
  }

  /// Returns current worker id if available
  Future<String?> getCurrentWorkerId() async {
    return await _resolveWorkerId();
  }

  /// Read availability (isOnline) flag for given worker or current worker
  Future<bool?> getAvailability({String? workerId}) async {
    final wid = workerId ?? await _resolveWorkerId();
    if (wid == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(wid).get();
      if (!doc.exists) return null;
      return (doc.data()?['isOnline'] as bool?) ?? null;
    } catch (e) {
      debugPrint('[WorkerJobRepository] getAvailability error: $e');
      return null;
    }
  }

  /// Fetch jobs assigned to the current worker (or all orders with workerId equal to provided id)
  Future<List<JobModel>> getAssignedJobs({String? workerId}) async {
    final wid = workerId ?? await _resolveWorkerId();
    if (wid == null) return [];

    // 1) Preferred: per-worker mirror
    try {
      final snap = await _firestore
          .collection('workers')
          .doc(wid)
          .collection('orders')
          .orderBy('scheduledAt', descending: false)
          .get();

      if (snap.docs.isNotEmpty) {
        final List<JobModel> out = [];
        for (final d in snap.docs) {
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
          jobMap['scheduledEnd'] = data['scheduledEnd'] ?? data['scheduled_end'] ?? data['scheduledAtEnd'];
          jobMap['status'] = data['status'] ?? data['orderStatus'] ?? 'assigned';
          jobMap['isCod'] = data['paymentStatus'] == 'cod' || (data['isCod'] ?? data['is_cod'] ?? false);
          jobMap['specialInstructions'] = data['specialInstructions'] ?? data['special_instructions'] ?? '';
          jobMap['rating'] = data['rating'] ?? null;

          if ((jobMap['customerName'] == null || (jobMap['customerName'] as String).isEmpty || jobMap['customerPhone'] == null || (jobMap['customerPhone'] as String).isEmpty) && data['userId'] != null) {
            try {
              final udoc = await _firestore.collection('users').doc(data['userId']).get();
              if (udoc.exists) {
                final ud = udoc.data();
                jobMap['customerName'] = (ud?['name'] as String?) ?? jobMap['customerName'];
                jobMap['customerPhone'] = (ud?['phoneNumber'] as String?) ?? jobMap['customerPhone'];
              }
            } catch (_) {}
          }

          try {
            out.add(JobModel.fromMap(jobMap, id: d.id));
          } catch (e) {
            debugPrint('[WorkerJobRepository] failed to parse job ${d.id}: $e');
          }
        }
        return out;
      }
    } catch (e) {
      debugPrint('[WorkerJobRepository] per-worker mirror read failed for worker=$wid: $e');
    }

    // 2) Fallback: collectionGroup across users/*/orders where workerId matches
    try {
      Query cg = _firestore.collectionGroup('orders').where('workerId', isEqualTo: wid);
      try {
        cg = cg.orderBy('scheduledAt', descending: false);
      } catch (_) {}
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await cg.get() as QuerySnapshot<Map<String, dynamic>>;
      } catch (e) {
        debugPrint('[WorkerJobRepository] collectionGroup initial error: $e');
        // If error mentions index/permission, retry without orderBy
        try {
          final retryCg = _firestore.collectionGroup('orders').where('workerId', isEqualTo: wid);
          snap = await retryCg.get() as QuerySnapshot<Map<String, dynamic>>;
        } catch (e2) {
          debugPrint('[WorkerJobRepository] collectionGroup retry failed: $e2');
          throw e2; // fall-through to outer catch
        }
      }

      if (snap.docs.isNotEmpty) {
        debugPrint('[WorkerJobRepository] collectionGroup returned ${snap.docs.length} docs for worker=$wid');
        final List<JobModel> out = [];
        for (final d in snap.docs) {
          final data = d.data();
          final jobMap = Map<String, dynamic>.from(data);
          jobMap['id'] = d.id;
          try {
            out.add(JobModel.fromMap(jobMap, id: d.id));
          } catch (e) {
            debugPrint('[WorkerJobRepository] parse error for collectionGroup doc ${d.id}: $e');
          }
        }
        return out;
      }
    } catch (e) {
      debugPrint('[WorkerJobRepository] collectionGroup fallback failed or is disallowed: $e');
    }

    // 3) Final fallback: top-level orders collection
    try {
      Query topQ = _firestore.collection('orders').where('workerId', isEqualTo: wid);
      try {
        topQ = topQ.orderBy('scheduledAt', descending: false);
      } catch (_) {}

      QuerySnapshot<Map<String, dynamic>> top;
      try {
        top = await topQ.get() as QuerySnapshot<Map<String, dynamic>>;
      } catch (e) {
        debugPrint('[WorkerJobRepository] top-level initial query error: $e');
        try {
          final retryTop = _firestore.collection('orders').where('workerId', isEqualTo: wid);
          top = await retryTop.get() as QuerySnapshot<Map<String, dynamic>>;
        } catch (e2) {
          debugPrint('[WorkerJobRepository] top-level retry failed: $e2');
          throw e2;
        }
      }

      if (top.docs.isNotEmpty) {
        debugPrint('[WorkerJobRepository] top-level orders returned ${top.docs.length} docs for worker=$wid');
        final List<JobModel> out = [];
        for (final d in top.docs) {
          final data = d.data();
          final jobMap = Map<String, dynamic>.from(data);
          jobMap['id'] = d.id;
          try {
            out.add(JobModel.fromMap(jobMap, id: d.id));
          } catch (e) {
            debugPrint('[WorkerJobRepository] parse error for top-level order ${d.id}: $e');
          }
        }
        return out;
      }
    } catch (e) {
      debugPrint('[WorkerJobRepository] top-level orders fallback failed: $e');
    }

    // Nothing found
    return [];
  }

  Future<JobModel?> getJobById(String id) async {
    try {
      // Try to find the job in the per-worker mirror first (fast & allowed by rules)
      // If not found, fall back to the top-level orders collection.
      // Note: We don't know the workerId from just order id, so first attempt top-level (get is allowed for workers if they're assigned).
      final top = await _firestore.collection('orders').doc(id).get();
      if (top.exists) {
        final map = top.data() ?? {};
        final jobMap = Map<String, dynamic>.from(map);
        jobMap['id'] = top.id;
        return JobModel.fromMap(jobMap, id: top.id);
      }
      // As a fallback, try scanning per-worker mirrors (expensive) - attempt to find under current worker if available
      final wid = await _resolveWorkerId();
      if (wid != null) {
        final d = await _firestore.collection('workers').doc(wid).collection('orders').doc(id).get();
        if (d.exists) {
          final jobMap = Map<String, dynamic>.from(d.data() ?? {});
          jobMap['id'] = d.id;
          return JobModel.fromMap(jobMap, id: d.id);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WorkerJobRepository] getJobById error: $e');
      return null;
    }
  }

  /// Update order status in Firestore. Also update orderStatus and updatedAt fields.
  Future<JobModel?> updateJobStatus(String id, String status) async {
    try {
      final ref = _firestore.collection('orders').doc(id);
       final snap = await ref.get();
       if (!snap.exists) return null;
       await ref.update({
         'status': status,
         'orderStatus': status,
         'updatedAt': FieldValue.serverTimestamp(),
       });
       // Return updated JobModel
       return await getJobById(id);
     } catch (e) {
       debugPrint('[WorkerJobRepository] updateJobStatus error: $e');
       rethrow;
     }
   }

  /// Set worker availability on the worker's user document
  Future<void> setAvailability(bool online, {String? workerId}) async {
    final wid = workerId ?? await _resolveWorkerId();
    if (wid == null) return;
    try {
      await _firestore.collection('users').doc(wid).update({'isOnline': online});
    } catch (e) {
      // If field doesn't exist, try set with merge
      try {
        await _firestore.collection('users').doc(wid).set({'isOnline': online}, SetOptions(merge: true));
      } catch (_) {
        debugPrint('[WorkerJobRepository] setAvailability failed: $e');
      }
    }
  }
}
