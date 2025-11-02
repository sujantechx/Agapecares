import 'package:agapecares/core/models/job_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
      QuerySnapshot snap;
      try {
        snap = await cg.get();
      } catch (e) {
        debugPrint('[WorkerJobRepository] collectionGroup initial error: $e');
        // If error mentions index/permission, retry without orderBy
        try {
          final retryCg = _firestore.collectionGroup('orders').where('workerId', isEqualTo: wid);
          snap = await retryCg.get();
        } catch (e2) {
          debugPrint('[WorkerJobRepository] collectionGroup retry failed: $e2');
          throw e2; // fall-through to outer catch
        }
      }

      if (snap.docs.isNotEmpty) {
        final List<JobModel> out = [];
        final Set<String> seenIds = <String>{};
        for (final d in snap.docs) {
          // Deduplicate documents that may appear in multiple collections (e.g. top-level `orders` and `users/{uid}/orders`)
          if (seenIds.contains(d.id)) continue;
          seenIds.add(d.id);
          final raw = d.data();
          if (raw is! Map) {
            debugPrint('[WorkerJobRepository] unexpected collectionGroup doc data type for ${d.id}, skipping');
            continue;
          }
          final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
          final jobMap = Map<String, dynamic>.from(data);
          jobMap['id'] = d.id;
          try {
            out.add(JobModel.fromMap(jobMap, id: d.id));
          } catch (e) {
            debugPrint('[WorkerJobRepository] parse error for collectionGroup doc ${d.id}: $e');
          }
        }
        debugPrint('[WorkerJobRepository] collectionGroup returned ${snap.docs.length} docs (${seenIds.length} unique) for worker=$wid');
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

      QuerySnapshot top;
      try {
        top = await topQ.get();
      } catch (e) {
        debugPrint('[WorkerJobRepository] top-level initial query error: $e');
        try {
          final retryTop = _firestore.collection('orders').where('workerId', isEqualTo: wid);
          top = await retryTop.get();
        } catch (e2) {
          debugPrint('[WorkerJobRepository] top-level retry failed: $e2');
          throw e2;
        }
      }

      if (top.docs.isNotEmpty) {
        debugPrint('[WorkerJobRepository] top-level orders returned ${top.docs.length} docs for worker=$wid');
        final List<JobModel> out = [];
        for (final d in top.docs) {
          final raw = d.data();
          if (raw is! Map) {
            debugPrint('[WorkerJobRepository] unexpected top-level doc data type for ${d.id}, skipping');
            continue;
          }
          final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
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
      // Try top-level first
      final top = await _firestore.collection('orders').doc(id).get();
      if (top.exists) {
        final map = top.data() ?? {};
        final jobMap = Map<String, dynamic>.from(map);
        jobMap['id'] = top.id;
        return JobModel.fromMap(jobMap, id: top.id);
      }
      // Try per-worker mirror under current worker
      final wid = await _resolveWorkerId();
      if (wid != null) {
        final d = await _firestore.collection('workers').doc(wid).collection('orders').doc(id).get();
        if (d.exists) {
          final jobMap = Map<String, dynamic>.from(d.data() ?? {});
          jobMap['id'] = d.id;
          return JobModel.fromMap(jobMap, id: d.id);
        }
      }
      // Last: collectionGroup fallback by orderId or remoteId
      try {
        QuerySnapshot? cg;
        try {
          cg = await _firestore.collectionGroup('orders').where('orderId', isEqualTo: id).limit(3).get();
        } catch (_) { cg = null; }
        if (cg == null || cg.docs.isEmpty) {
          try {
            cg = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: id).limit(3).get();
          } catch (_) { cg = null; }
        }
        if (cg != null && cg.docs.isNotEmpty) {
          final doc = cg.docs.first;
          final raw = doc.data();
          if (raw is Map) {
            final jobMap = Map<String, dynamic>.from(raw);
            jobMap['id'] = doc.id;
            return JobModel.fromMap(jobMap, id: doc.id);
          }
        }
      } catch (e) {
        debugPrint('[WorkerJobRepository] collectionGroup getJobById fallback failed: $e');
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
      // Debug: print current authenticated user info
      try {
        final cu = _auth.currentUser;
        debugPrint('[WorkerJobRepository] updateJobStatus called by auth.uid=${cu?.uid} email=${cu?.email}');
      } catch (_) {}

      // Helper to read a specific doc reference and convert to JobModel
      Future<JobModel?> _jobFromRef(DocumentReference ref) async {
        try {
          final snap = await ref.get();
          if (!snap.exists) return null;
          final raw = snap.data();
          if (raw is! Map) return null;
          final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
          map['id'] = snap.id;
          return JobModel.fromMap(map, id: snap.id);
        } catch (e) {
          debugPrint('[WorkerJobRepository] _jobFromRef error for ${ref.path}: $e');
          return null;
        }
      }

      // Prefer updating the per-worker mirror if present (workers/{workerId}/orders/{id}).
      // Worker security rules allow updates on the per-worker mirror for the assigned worker.
      final wid = await _resolveWorkerId();
      if (wid != null && wid.isNotEmpty) {
        try {
          final workerRef = _firestore.collection('workers').doc(wid).collection('orders').doc(id);
          final workerSnap = await workerRef.get();
          if (workerSnap.exists) {
            // Include workerId in the update so security rules allow status transitions
            try {
              await workerRef.update({
                'status': status,
                'orderStatus': status,
                'workerId': wid,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              // Also attempt to update the top-level orders/{id} to keep mirrors in sync (best-effort).
              try {
                final topRefAfterWorker = _firestore.collection('orders').doc(id);
                final topSnapAfterWorker = await topRefAfterWorker.get();
                if (topSnapAfterWorker.exists) {
                  try {
                    await topRefAfterWorker.update({
                      'status': status,
                      'orderStatus': status,
                      'workerId': wid,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    debugPrint('[WorkerJobRepository] top-level update after worker mirror failed (non-blocking): $e');
                  }
                }
              } catch (e) {
                debugPrint('[WorkerJobRepository] failed to check/top-update after worker mirror: $e');
              }
            } catch (e, st) {
              debugPrint('[WorkerJobRepository] workerRef.update failed: $e');
              debugPrint(st.toString());
              rethrow;
            }
            // Return the updated document from the exact ref to avoid stale mirrors
            return await _jobFromRef(workerRef);
          }
        } catch (e) {
          debugPrint('[WorkerJobRepository] per-worker update failed for $id: $e');
          // Fall through to try collectionGroup / other doc updates
        }

        // Try updating top-level /orders/{id} if it exists and is assigned to this worker
        try {
          final topRef = _firestore.collection('orders').doc(id);
          final topSnap = await topRef.get();
          if (topSnap.exists) {
            final topData = topSnap.data();
            if (topData != null && topData['workerId'] == wid) {
              if (topData['mirroredFromUserSubcollection'] == true) {
                debugPrint('[WorkerJobRepository] top-level orders doc for $id is a mirror; falling back to users/{uid}/orders update');
                final ownerId = (topData['userId'] ?? topData['orderOwner']);
                if (ownerId != null && ownerId is String && ownerId.isNotEmpty) {
                  try {
                    final userOrderRef = _firestore.collection('users').doc(ownerId).collection('orders').doc(id);
                    try {
                      final existing = await userOrderRef.get();
                      if (existing.exists) {
                        final ed = existing.data();
                        final Map<String, dynamic>? edMap = (ed is Map) ? Map<String, dynamic>.from(ed as Map) : null;
                        final dynamic docWorkerId = (edMap != null && edMap.containsKey('workerId')) ? edMap['workerId'] : null;
                        if (ed is Map && docWorkerId == wid) {
                          try {
                            final topRefCandidate = _firestore.collection('orders').doc(id);
                            final batch = _firestore.batch();
                            batch.update(userOrderRef, {
                              'status': status,
                              'orderStatus': status,
                              'workerId': wid,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            final topSnapCandidate = await topRefCandidate.get();
                            if (topSnapCandidate.exists) {
                              batch.update(topRefCandidate, {
                                'status': status,
                                'orderStatus': status,
                                'workerId': wid,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            }
                            await batch.commit();
                            return await _jobFromRef(userOrderRef);
                          } catch (batchErr) {
                            debugPrint('[WorkerJobRepository] batch update failed, retrying single update: $batchErr');
                            await userOrderRef.update({
                              'status': status,
                              'orderStatus': status,
                              'workerId': wid,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            return await _jobFromRef(userOrderRef);
                          }
                        } else {
                          debugPrint('[WorkerJobRepository] users/{uid}/orders/{id} workerId mismatch or missing. doc.workerId=$docWorkerId expected=$wid');
                        }
                      } else {
                        debugPrint('[WorkerJobRepository] users/{uid}/orders/{id} does not exist at ${userOrderRef.path}');
                      }
                    } catch (e) {
                      debugPrint('[WorkerJobRepository] failed to read users/{uid}/orders/{id}: $e');
                    }
                  } catch (e) {
                    debugPrint('[WorkerJobRepository] update on users/{uid}/orders/{id} outer failed: $e');
                  }
                } else {
                  debugPrint('[WorkerJobRepository] top-level mirror missing ownerId; cannot target users/{uid}/orders/{id}');
                }
              } else {
                debugPrint('[WorkerJobRepository] attempting top-level update on path=${topRef.path} for worker=$wid; docData=$topData');
                await topRef.update({
                  'status': status,
                  'orderStatus': status,
                  'workerId': wid,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                return await _jobFromRef(topRef);
              }
            }
          }
        } catch (e) {
          debugPrint('[WorkerJobRepository] top-level update attempt failed for $id: $e');
          // Continue to collectionGroup fallback
        }
      }

      // Search all `orders` subcollections and top-level using collectionGroup, prefer workers/ and users/ paths
      try {
        QuerySnapshot? cgSnap;
        try {
          final q1 = _firestore.collectionGroup('orders').where('workerId', isEqualTo: wid).where('orderId', isEqualTo: id).limit(5);
          cgSnap = await q1.get();
        } catch (_) {
          cgSnap = null;
        }
        if (cgSnap == null || cgSnap.docs.isEmpty) {
          try {
            final q2 = _firestore.collectionGroup('orders').where('workerId', isEqualTo: wid).where('remoteId', isEqualTo: id).limit(5);
            cgSnap = await q2.get();
          } catch (_) {
            cgSnap = null;
          }
        }
        if (cgSnap == null || cgSnap.docs.isEmpty) {
          try {
            final q3 = _firestore.collectionGroup('orders').where('workerId', isEqualTo: wid).limit(50);
            cgSnap = await q3.get();
          } catch (e) {
            debugPrint('[WorkerJobRepository] collectionGroup lookup/update failed for $id (fallback workerId query): $e');
            cgSnap = null;
          }
        }

        if (cgSnap != null && cgSnap.docs.isNotEmpty) {
          for (final d in cgSnap.docs) {
            final dynamic raw = d.data();
            final assigned = (raw is Map) ? raw['workerId'] : null;
            if (assigned == wid) {
              final path = d.reference.path;
              final Map<String, dynamic> updateMap = {
                'status': status,
                'orderStatus': status,
                'workerId': wid,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              debugPrint('[WorkerJobRepository] attempting update with payload=$updateMap on path=$path');
              if (path.startsWith('workers/')) {
                await d.reference.update(updateMap);
                return await _jobFromRef(d.reference);
              }
              if (path.contains('/users/')) {
                try {
                  final topRef = _firestore.collection('orders').doc(id);
                  try {
                    final batch = _firestore.batch();
                    batch.update(d.reference, updateMap);
                    final topSnap = await topRef.get();
                    if (topSnap.exists) {
                      batch.update(topRef, updateMap);
                    }
                    await batch.commit();
                    return await _jobFromRef(d.reference);
                  } catch (batchErr) {
                    debugPrint('[WorkerJobRepository] collectionGroup batch failed, falling back to single update: $batchErr');
                    await d.reference.update(updateMap);
                    return await _jobFromRef(d.reference);
                  }
                } catch (e, st) {
                  debugPrint('[WorkerJobRepository] update on path=${d.reference.path} failed: $e');
                  debugPrint(st.toString());
                  if (e is FirebaseException) {
                    debugPrint('[WorkerJobRepository] FirebaseException code=${e.code} message=${e.message}');
                  }
                  rethrow;
                }
              }
              debugPrint('[WorkerJobRepository] found top-level orders doc for $id assigned to worker $wid but refusing client-side top-level update');
              throw FirebaseException(plugin: 'cloud_firestore', message: 'permission-denied');
            }
          }
        }
      } catch (e) {
        debugPrint('[WorkerJobRepository] collectionGroup lookup/update failed for $id: $e');
      }

      // If we got here, no writable doc was found for this worker — deny.
      debugPrint('[WorkerJobRepository] no writable order document found for worker=$wid and order=$id');

      // Fallback: call a trusted Cloud Function to perform the update server-side.
      try {
        debugPrint('[WorkerJobRepository] attempting workerUpdateOrderStatus cloud function for order=$id status=$status');
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('workerUpdateOrderStatus');
        final result = await callable.call(<String, dynamic>{'orderId': id, 'status': status});
        debugPrint('[WorkerJobRepository] workerUpdateOrderStatus result=${result.data}');
        if (result.data != null && result.data['success'] == true) {
          return await getJobById(id);
        }
      } catch (e, st) {
        debugPrint('[WorkerJobRepository] workerUpdateOrderStatus cloud function failed: $e');
        debugPrint(st.toString());
      }

      // Last-resort: try updating the top-level orders doc directly if allowed by rules
      try {
        final topRef2 = _firestore.collection('orders').doc(id);
        final topSnap2 = await topRef2.get();
        if (topSnap2.exists) {
          final topData2 = topSnap2.data();
          if (topData2 != null && topData2['workerId'] == wid) {
            try {
              await topRef2.update({
                'status': status,
                'orderStatus': status,
                'workerId': wid,
                'updatedAt': FieldValue.serverTimestamp()
              });
              // Also try to update the user's subcollection mirror
              final userId = topData2['userId'] ?? topData2['orderOwner'];
              if (userId != null && userId is String && userId.isNotEmpty) {
                try {
                  final userOrderRef = _firestore.collection('users').doc(userId).collection('orders').doc(id);
                  await userOrderRef.update({
                    'status': status,
                    'orderStatus': status,
                    'workerId': wid,
                    'updatedAt': FieldValue.serverTimestamp()
                  });
                } catch (e) {
                  debugPrint('[WorkerJobRepository] failed to update user subcollection in last-resort: $e');
                }
              }
              return await _jobFromRef(topRef2);
            } catch (e, st) {
              debugPrint('[WorkerJobRepository] last-resort top-level update failed: $e');
              debugPrint(st.toString());
              if (e is FirebaseException) debugPrint('[WorkerJobRepository] FirebaseException code=${e.code} message=${e.message}');
            }
          }
        }
      } catch (e) {
        debugPrint('[WorkerJobRepository] last-resort top-level update attempt error: $e');
      }

      throw FirebaseException(plugin: 'cloud_firestore', message: 'permission-denied');
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
