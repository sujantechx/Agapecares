import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/order_repository.dart';
import 'package:agapecares/core/models/order_model.dart';

/// Firestore implementation of the admin OrderRepository interface.
/// Supports collectionGroup queries across users/{uid}/orders and top-level
/// `orders` collection as a fallback.
class OrderRepositoryImpl implements OrderRepository {
  final FirebaseFirestore _firestore;
  OrderRepositoryImpl({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName}) async {
    if (orderId.trim().isEmpty) throw Exception('orderId required');
    final update = <String, dynamic>{
      'workerId': workerId,
      if (workerName != null) 'workerName': workerName,
      'status': 'assigned',
      'orderStatus': 'assigned',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Try top-level update first
    try {
      final topRef = _firestore.collection('orders').doc(orderId);
      final topSnap = await topRef.get();
      if (topSnap.exists) {
        await topRef.set(update, SetOptions(merge: true));
      }
    } catch (e) {
      // Non-fatal: continue to attempt collectionGroup updates
    }

    // Update any matching doc in users/{uid}/orders (collectionGroup). Try match by documentId and by remoteId field
    var foundAny = false;
    try {
      // Avoid querying collectionGroup by FieldPath.documentId with a short id
      // (Firestore expects a full document path when using documentId on a collectionGroup).
      // Use the stored 'remoteId' field to locate matching per-user order docs.
      try {
        final byRemote = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: orderId).get();
        for (final doc in byRemote.docs) {
          try {
            await doc.reference.set(update, SetOptions(merge: true));
            foundAny = true;
          } catch (_) {}
        }
      } catch (e) {
        // collectionGroup may be denied; fall through to per-user enumeration below
      }

      // If collectionGroup didn't find any documents (or was denied), enumerate users and attempt to update per-user docs directly
      if (!foundAny) {
        try {
          Query usersQuery = _firestore.collection('users').orderBy('__name__').limit(50);
          DocumentSnapshot? lastUser;
          while (true) {
            if (lastUser != null) usersQuery = usersQuery.startAfterDocument(lastUser);
            final usersSnap = await usersQuery.get();
            if (usersSnap.docs.isEmpty) break;
            for (final udoc in usersSnap.docs) {
              lastUser = udoc;
              try {
                final userOrdersCol = udoc.reference.collection('orders');
                // Try by document id
                try {
                  final candidate = await userOrdersCol.doc(orderId).get();
                  if (candidate.exists) {
                    await candidate.reference.set(update, SetOptions(merge: true));
                    foundAny = true;
                    return; // done
                  }
                } catch (_) {}

                // Try by remoteId field
                try {
                  final byRemote = await userOrdersCol.where('remoteId', isEqualTo: orderId).limit(1).get();
                  if (byRemote.docs.isNotEmpty) {
                    await byRemote.docs.first.reference.set(update, SetOptions(merge: true));
                    foundAny = true;
                    return;
                  }
                } catch (_) {}
              } catch (_) {
                // skip this user if we lack permission
                continue;
              }
            }
            if (usersSnap.docs.length < 50) break;
          }
        } catch (e) {
          // final fallback: nothing we can do client-side
        }
      }
    } catch (e) {
      // Ignore errors in assignWorker
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    if (orderId.trim().isEmpty) return;
    try {
      final topRef = _firestore.collection('orders').doc(orderId);
      final topSnap = await topRef.get();
      if (topSnap.exists) await topRef.delete();
    } catch (_) {}

    // Delete from any users/{uid}/orders location
    try {
      // collectionGroup queries cannot filter by documentId using a short id
      // (they require a full document path). Use the 'remoteId' field instead.
      final byRemote = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: orderId).get();
      for (final doc in byRemote.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }
      // As a final fallback, enumerate users and attempt per-user deletes
      try {
        Query usersQuery = _firestore.collection('users').orderBy('__name__').limit(50);
        DocumentSnapshot? lastUser;
        while (true) {
          if (lastUser != null) usersQuery = usersQuery.startAfterDocument(lastUser);
          final usersSnap = await usersQuery.get();
          if (usersSnap.docs.isEmpty) break;
          for (final udoc in usersSnap.docs) {
            lastUser = udoc;
            try {
              final userOrdersCol = udoc.reference.collection('orders');
              final candidate = await userOrdersCol.doc(orderId).get();
              if (candidate.exists) {
                await candidate.reference.delete();
                return;
              }
              final byRemoteLocal = await userOrdersCol.where('remoteId', isEqualTo: orderId).limit(1).get();
              if (byRemoteLocal.docs.isNotEmpty) {
                await byRemoteLocal.docs.first.reference.delete();
                return;
              }
            } catch (_) {
              continue; // skip users we can't access
            }
          }
          if (usersSnap.docs.length < 50) break;
        }
      } catch (_) {}
    } catch (_) {}
  }

  @override
  Future<List<OrderModel>> getAllOrders({Map<String, dynamic>? filters}) async {
    final int limit = (filters != null && filters['limit'] is int) ? filters['limit'] as int : 500;

    // Helper to apply filters to a Query
    Query _applyFilters(Query q) {
      if (filters != null) {
        if (filters['status'] != null) q = q.where('status', isEqualTo: filters['status']);
        if (filters['orderOwner'] != null) q = q.where('orderOwner', isEqualTo: filters['orderOwner']);
        if (filters['userId'] != null) q = q.where('userId', isEqualTo: filters['userId']);
        if (filters['workerId'] != null) q = q.where('workerId', isEqualTo: filters['workerId']);
        if (filters['orderNumber'] != null) q = q.where('orderNumber', isEqualTo: filters['orderNumber']);
        if (filters['dateFrom'] != null) q = q.where('createdAt', isGreaterThanOrEqualTo: filters['dateFrom']);
        if (filters['dateTo'] != null) q = q.where('createdAt', isLessThanOrEqualTo: filters['dateTo']);
      }
      return q;
    }

    // First try collectionGroup across users/{uid}/orders
    try {
      Query cg = _firestore.collectionGroup('orders');
      cg = _applyFilters(cg);
      cg = cg.orderBy('createdAt', descending: true).limit(limit);
      final snap = await cg.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      }
    } catch (e) {
      // collectionGroup queries may be denied; fall through to other fallbacks
    }

    // If collectionGroup failed or returned empty, try top-level orders collection
    try {
      Query q = _firestore.collection('orders');
      q = _applyFilters(q);
      q = q.orderBy('createdAt', descending: true).limit(limit);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } catch (e) {
      // top-level failed; continue to robust per-user enumeration fallback
    }

    // FINAL FALLBACK: enumerate users and fetch per-user subcollection orders.
    // This is used when collectionGroup and/or top-level reads are denied.
    // It requires the admin to have permission to read `users` documents.
    try {
      final List<OrderModel> results = [];
      int remaining = limit;
      Query usersQuery = _firestore.collection('users').orderBy('__name__').limit(50);
      DocumentSnapshot? lastUser;

      while (remaining > 0) {
        if (lastUser != null) usersQuery = usersQuery.startAfterDocument(lastUser);
        final usersSnap = await usersQuery.get();
        if (usersSnap.docs.isEmpty) break;

        for (final udoc in usersSnap.docs) {
          if (remaining <= 0) break;
          lastUser = udoc;

          try {
            CollectionReference userOrders = udoc.reference.collection('orders');
            Query uq = userOrders;
            // If filters include a specific orderOwner/userId, skip other users
            if (filters != null && (filters['orderOwner'] != null || filters['userId'] != null)) {
              final filterUserId = (filters['orderOwner'] ?? filters['userId']) as String?;
              if (filterUserId != null && filterUserId != udoc.id) continue;
            }

            uq = _applyFilters(uq);
            uq = uq.orderBy('createdAt', descending: true).limit(remaining);
            final ordersSnap = await uq.get();
            for (final od in ordersSnap.docs) {
              if (remaining <= 0) break;
              results.add(OrderModel.fromFirestore(od));
              remaining--;
            }

            if (remaining <= 0) break;
          } catch (e) {
            // Skip users where we lack permissions on subcollection
            continue;
          }
        }

        // If we didn't get as many users as requested, break to avoid infinite loop
        if (usersSnap.docs.length < 50) break;
      }

      return results;
    } catch (e) {
      // If everything fails, rethrow to let caller handle it
      rethrow;
    }
  }

  @override
  Future<void> updateOrderStatus({required String orderId, required String status}) async {
    if (orderId.trim().isEmpty) throw Exception('orderId required');
    final update = <String, dynamic>{
      'status': status,
      'orderStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Try top-level
    try {
      final topRef = _firestore.collection('orders').doc(orderId);
      final topSnap = await topRef.get();
      if (topSnap.exists) {
        await topRef.set(update, SetOptions(merge: true));
      }
    } catch (_) {}

    // Update any matching user-subcollection docs
    try {
      // Prefer searching by 'remoteId' field for collectionGroup queries
      final byRemote = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: orderId).get();
      for (final doc in byRemote.docs) {
        try {
          await doc.reference.set(update, SetOptions(merge: true));
        } catch (_) {}
      }
      // If nothing found, fall back to enumerating users and updating per-user docs
      if (byRemote.docs.isEmpty) {
        try {
          Query usersQuery = _firestore.collection('users').orderBy('__name__').limit(50);
          DocumentSnapshot? lastUser;
          while (true) {
            if (lastUser != null) usersQuery = usersQuery.startAfterDocument(lastUser);
            final usersSnap = await usersQuery.get();
            if (usersSnap.docs.isEmpty) break;
            for (final udoc in usersSnap.docs) {
              lastUser = udoc;
              try {
                final userOrdersCol = udoc.reference.collection('orders');
                final candidate = await userOrdersCol.doc(orderId).get();
                if (candidate.exists) {
                  await candidate.reference.set(update, SetOptions(merge: true));
                  return;
                }
                final byRemoteLocal = await userOrdersCol.where('remoteId', isEqualTo: orderId).limit(1).get();
                if (byRemoteLocal.docs.isNotEmpty) {
                  await byRemoteLocal.docs.first.reference.set(update, SetOptions(merge: true));
                  return;
                }
              } catch (_) {
                continue;
              }
            }
            if (usersSnap.docs.length < 50) break;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
