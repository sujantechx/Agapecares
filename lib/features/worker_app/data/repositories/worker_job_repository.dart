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
              });
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

        // NEW: Try updating top-level /orders/{id} if it exists and is assigned to this worker
        try {
          final topRef = _firestore.collection('orders').doc(id);
          final topSnap = await topRef.get();
          if (topSnap.exists) {
            final topData = topSnap.data();
            // If this top-level order doc is a mirror of a users/{uid}/orders document
            // (mirroredFromUserSubcollection == true) then don't attempt a client-side
            // update on the top-level doc because security rules may forbid it. Instead
            // fall through to collectionGroup lookup which will find the writable
            // users/{uid}/orders or workers/{wid}/orders document and update that.
            if (topData != null && topData['workerId'] == wid) {
              if (topData['mirroredFromUserSubcollection'] == true) {
                debugPrint('[WorkerJobRepository] top-level orders doc for $id is a mirror; skipping client-side top-level update and falling back to collectionGroup');
                // Try to resolve the original per-user document path using the userId/orderOwner
                final ownerId = (topData['userId'] ?? topData['orderOwner']);
                if (ownerId != null && ownerId is String && ownerId.isNotEmpty) {
                  try {
                    final userOrderRef = _firestore.collection('users').doc(ownerId).collection('orders').doc(id);
                    debugPrint('[WorkerJobRepository] attempting update on original user subcollection path=${userOrderRef.path} for worker=$wid');
                    // Read the existing doc to ensure it's writable by this worker per rules
                    try {
                      final existing = await userOrderRef.get();
                      if (!existing.exists) {
                        debugPrint('[WorkerJobRepository] users/{uid}/orders/{id} does not exist: path=${userOrderRef.path}');
                      } else {
                        final ed = existing.data();
                        debugPrint('[WorkerJobRepository] users/{uid}/orders/{id} doc data for ${userOrderRef.path}: $ed');
                        // Safely extract workerId from the possibly-null data map
                        final Map<String, dynamic>? edMap = (ed is Map) ? Map<String, dynamic>.from(ed as Map) : null;
                        final dynamic docWorkerId = (edMap != null && edMap.containsKey('workerId')) ? edMap['workerId'] : null;

                        if (ed is Map && docWorkerId == wid) {
                          try {
                            await userOrderRef.update({
                              'status': status,
                              'orderStatus': status,
                              'workerId': wid,
                            });
                            return await _jobFromRef(userOrderRef);
                          } catch (e, st) {
                            debugPrint('[WorkerJobRepository] update on users/{uid}/orders/{id} failed during update: $e');
                            debugPrint(st.toString());
                            // fall through to collectionGroup / cloud function fallback
                          }
                        } else {
                          debugPrint('[WorkerJobRepository] users/{uid}/orders/{id} workerId mismatch or missing. doc.workerId=$docWorkerId expected=$wid');
                        }
                      }
                    } catch (e) {
                      debugPrint('[WorkerJobRepository] failed to read users/{uid}/orders/{id}: $e');
                    }
                    // Note: do NOT attempt a blind update here if the read/update above failed;
                    // fall through to the collectionGroup and cloud-function fallbacks instead.
                   } catch (e) {
                     debugPrint('[WorkerJobRepository] update on users/{uid}/orders/{id} outer failed: $e');
                   }
                } else {
                  debugPrint('[WorkerJobRepository] top-level mirror missing ownerId; cannot target users/{uid}/orders/{id}');
                }
                // Do not attempt update on the top-level mirror; collectionGroup fallback will handle it.
              } else {
                debugPrint('[WorkerJobRepository] attempting top-level update on path=${topRef.path} for worker=$wid; docData=$topData');
                await topRef.update({
                  'status': status,
                  'orderStatus': status,
                  'workerId': wid,
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

      // Next: search all `orders` subcollections (users/{uid}/orders, etc.) and top-level using collectionGroup
      // Find a document with the given id where resource.data().workerId == wid (so worker is authorized to update)
      try {
        QuerySnapshot? cgSnap;

        // Preferred: query by stored `orderId` and workerId (safe for collectionGroup)
        try {
          final q1 = _firestore.collectionGroup('orders')
              .where('workerId', isEqualTo: wid)
              .where('orderId', isEqualTo: id)
              .limit(5);
          cgSnap = await q1.get();
        } catch (_) {
          cgSnap = null;
        }

        // If not found, try remoteId (some docs use remoteId)
        if (cgSnap == null || cgSnap.docs.isEmpty) {
          try {
            final q2 = _firestore.collectionGroup('orders')
                .where('workerId', isEqualTo: wid)
                .where('remoteId', isEqualTo: id)
                .limit(5);
            cgSnap = await q2.get();
          } catch (_) {
            cgSnap = null;
          }
        }

        // Final (safe) fallback: query collectionGroup by workerId only and filter client-side.
        // This avoids using FieldPath.documentId with a single id which causes an SDK error.
        if ((cgSnap == null || cgSnap.docs.isEmpty)) {
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
              // Detailed debug logging to diagnose permission issues
              debugPrint('[WorkerJobRepository] collectionGroup candidate path=$path; workerId_in_doc=$assigned; docData=$raw');
              final Map<String, dynamic> updateMap = {
                'status': status,
                'orderStatus': status,
                'workerId': wid,
              };
              debugPrint('[WorkerJobRepository] attempting update with payload=$updateMap on path=$path');
              if (path.startsWith('workers/')) {
                debugPrint('[WorkerJobRepository] attempting update on path=${d.reference.path} for worker=$wid; docData=${d.data()}');
                await d.reference.update({
                  'status': status,
                  'orderStatus': status,
                  'workerId': wid,
                });
                return await _jobFromRef(d.reference);
              }
              if (path.contains('/users/')) {
                debugPrint('[WorkerJobRepository] attempting update on path=${d.reference.path} for worker=$wid; docData=${d.data()}');
                try {
                  await d.reference.update(updateMap);
                  return await _jobFromRef(d.reference);
                } catch (e, st) {
                  // Log full FirebaseException details to help diagnose security rule failures
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

      // Before calling the cloud function, as a last resort, try updating the top-level orders doc
      // directly even if it was marked as a mirror. Some projects allow assigned workers to update
      // top-level orders when they are the assigned worker; try that as a final client-side attempt.
      try {
        final topRef2 = _firestore.collection('orders').doc(id);
        final topSnap2 = await topRef2.get();
        if (topSnap2.exists) {
          final topData2 = topSnap2.data();
          if (topData2 != null && topData2['workerId'] == wid) {
            debugPrint('[WorkerJobRepository] last-resort attempting top-level direct update on ${topRef2.path} for worker=$wid');
            try {
              await topRef2.update({'status': status, 'orderStatus': status, 'workerId': wid});
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
