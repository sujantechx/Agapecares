// File: lib/features/user_app/data/repositories/order_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/services/local_database_service.dart';


/// Orchestrates saving orders locally and syncing to Firestore.
/// Why: keep offline-first UX and eventual consistency with backend.
class OrderRepository {
  final LocalDatabaseService _localDb;
  final FirebaseFirestore _firestore;

  OrderRepository({required LocalDatabaseService localDb, FirebaseFirestore? firestore})
      : _localDb = localDb,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> init() async {
    await _localDb.init();
  }

  /// Save order locally. Returns the saved local OrderModel (with localId set).
  Future<OrderModel> createOrder(OrderModel order, {bool uploadRemote = true}) async {
    final saved = await _localDb.createOrder(order);
    if (!uploadRemote) return saved;
    // Attempt to upload immediately and await result so the checkout flow can
    // know whether the remote document was created. If upload fails, we still
    // return the local saved order and rely on SyncService to retry.
    try {
      final remoteId = await uploadOrder(saved);
      if (remoteId != null) {
        // Return a copy that reflects remote sync status
        final updated = saved.copyWith(id: remoteId, isSynced: true);
        // Update local DB to keep local row consistent
        try {
          await _localDb.updateOrder(updated);
        } catch (_) {}
        return updated;
      }
    } catch (e) {
      debugPrint('[OrderRepository] upload attempt threw: $e');
    }
    return saved;
  }

  /// Attempts to upload a single local order to Firestore.
  /// On success marks the local row as synced and updates remote id if available.
  /// Returns the Firestore document id on success, or null on failure.
  Future<String?> uploadOrder(OrderModel localOrder) async {
    try {
      // Ensure we have a non-empty userId. If the localOrder doesn't contain one
      // (possible when orders were created before auth was ready), attempt to
      // read the current FirebaseAuth user as a fallback.
      var uploadData = localOrder.toFirebaseJson();
      final localUserId = (localOrder.userId).trim();
      String? finalUserId = localUserId.isNotEmpty ? localUserId : null;
      if (finalUserId == null) {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final uid = fbUser.uid?.trim();
          final phone = fbUser.phoneNumber?.trim();
          if (uid != null && uid.isNotEmpty) {
            finalUserId = uid;
          } else if (phone != null && phone.isNotEmpty) {
            finalUserId = phone;
          }
        }
      }

      if (finalUserId == null || finalUserId.isEmpty) {
        final msg = 'Cannot upload order: userId is empty (no authenticated user).';
        debugPrint('[OrderRepository] $msg');
        throw Exception(msg);
      }

      // Ensure the map we're uploading contains the resolved userId
      uploadData['userId'] = finalUserId;

      final docRef = await _firestore.collection('orders').add(uploadData);
      final remoteId = docRef.id;
      // mark local as synced
      if (localOrder.localId != null) {
        await _localDb.markOrderAsSynced(localOrder.localId!);
        // Also update local order row with the remote id if supported
        try {
          final updated = localOrder.copyWith(id: remoteId);
          await _localDb.updateOrder(updated);
        } catch (_) {}
      }
      // write back remote id into Firestore doc as well
      await docRef.update({'remoteId': remoteId});
      return remoteId;
    } on FirebaseException catch (e) {
      // Surface detailed Firestore error to caller
      final msg = 'Firestore upload failed: ${e.code} ${e.message}';
      debugPrint('[OrderRepository] $msg');
      // Re-throw so callers (e.g. checkout) can react (show message / retry)
      throw Exception(msg);
    } catch (e) {
      debugPrint('[OrderRepository] uploadOrder failed: $e');
      throw Exception('uploadOrder failed: ${e.toString()}');
    }
  }

  /// Update the local copy of an order (e.g. set paymentId, orderStatus)
  Future<void> updateLocalOrder(OrderModel order) async {
    await _localDb.updateOrder(order);
  }

  /// Mark a local order as failed
  Future<void> markLocalOrderFailed(int localId, {String? reason}) async {
    await _localDb.markOrderAsFailed(localId, failureReason: reason);
  }

  /// Sync all unsynced orders: used by connectivity watcher/background task.
  Future<void> syncUnsynced() async {
    final unsynced = await _localDb.getUnsyncedOrders();
    for (final o in unsynced) {
      await uploadOrder(o);
    }
  }

  /// Fetch orders for a specific user from Firestore (remote source).
  Future<List<OrderModel>> getOrdersForUser(String userId) async {
    try {
      // Sometimes orders were stored using phoneNumber and sometimes using uid.
      // Try to query for both possibilities: prefer a single whereIn query when possible.
      final fbUser = FirebaseAuth.instance.currentUser;
      final phone = fbUser?.phoneNumber?.trim();
      final idsToQuery = <String>{userId};
      if (phone != null && phone.isNotEmpty) idsToQuery.add(phone);

      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (idsToQuery.length > 1) {
        try {
          snapshot = await _firestore.collection('orders').where('userId', whereIn: idsToQuery.toList()).orderBy('createdAt', descending: true).get();
        } catch (e) {
          // Some SDKs/servers may not support whereIn with orderBy on the same field; fall back to two queries and merge.
          final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final id in idsToQuery) {
            final s = await _firestore.collection('orders').where('userId', isEqualTo: id).orderBy('createdAt', descending: true).get();
            allDocs.addAll(s.docs);
          }
          // Create a fake snapshot-like object via manual mapping below
          final docsMap = allDocs;
          // We'll process docsMap instead of snapshot
          final mapped = docsMap.map((d) {
            final data = d.data();
            final itemsRaw = (data['items'] as List<dynamic>?) ?? <dynamic>[];
            final items = itemsRaw.map((e) {
              if (e is Map<String, dynamic>) return OrderModel.cartItemFromMap(e);
              if (e is Map) return OrderModel.cartItemFromMap(Map<String, dynamic>.from(e));
              return OrderModel.cartItemFromMap(null);
            }).toList();
            final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
            final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
            final total = (data['total'] as num?)?.toDouble() ?? 0.0;
            return OrderModel(
              localId: null,
              isSynced: true,
              id: d.id,
              userId: data['userId'] as String? ?? '',
              items: items.cast(),
              subtotal: subtotal,
              discount: discount,
              total: total,
              paymentMethod: data['paymentMethod'] as String? ?? '',
              paymentId: data['paymentId'] as String?,
              orderStatus: data['orderStatus'] as String? ?? 'Placed',
              userName: data['userName'] as String? ?? '',
              userEmail: data['userEmail'] as String? ?? '',
              userPhone: data['userPhone'] as String? ?? '',
              userAddress: data['userAddress'] as String? ?? '',
              createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
            );
          }).toList();
          // Sort by createdAt descending
          mapped.sort((a, b) {
            try {
              return b.createdAt.toDate().compareTo(a.createdAt.toDate());
            } catch (_) {
              return 0;
            }
          });
          return mapped;
        }
      } else {
        snapshot = await _firestore.collection('orders').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).get();
      }
      return snapshot.docs.map((d) {
        final data = d.data();
        // Map Firestore document to OrderModel; create a minimal conversion
        final itemsRaw = (data['items'] as List<dynamic>?) ?? <dynamic>[];
        final items = itemsRaw.map((e) {
          if (e is Map<String, dynamic>) return OrderModel.cartItemFromMap(e);
          if (e is Map) return OrderModel.cartItemFromMap(Map<String, dynamic>.from(e));
          return OrderModel.cartItemFromMap(null);
        }).toList();
        final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
        final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        return OrderModel(
          localId: null,
          isSynced: true,
          id: d.id,
          userId: data['userId'] as String? ?? '',
          items: items.cast(),
          subtotal: subtotal,
          discount: discount,
          total: total,
          paymentMethod: data['paymentMethod'] as String? ?? '',
          paymentId: data['paymentId'] as String?,
          orderStatus: data['orderStatus'] as String? ?? 'Placed',
          userName: data['userName'] as String? ?? '',
          userEmail: data['userEmail'] as String? ?? '',
          userPhone: data['userPhone'] as String? ?? '',
          userAddress: data['userAddress'] as String? ?? '',
          createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch both remote (Firestore) orders and any local unsynced orders for display.
  /// This helps show orders placed offline that haven't yet uploaded, plus remote orders.
  Future<List<OrderModel>> getAllOrdersForUser(String userId) async {
    try {
      debugPrint('[OrderRepository] getAllOrdersForUser userId=$userId');
      final remote = await getOrdersForUser(userId);
      debugPrint('[OrderRepository] remote orders count=${remote.length}');
      final localUnsynced = await _localDb.getUnsyncedOrders();
      debugPrint('[OrderRepository] local unsynced orders count=${localUnsynced.length}');
      // Filter local unsynced orders to this user (local DB may store multiple users)
      // Also include local orders that were saved with an empty userId but
      // belong to the current authenticated user (common when auth wasn't
      // ready at order creation). This helps surface COD/local orders immediately.
      final fbUser = FirebaseAuth.instance.currentUser;
      final localForUser = localUnsynced.where((o) {
        final oUser = (o.userId).trim();
        if (oUser.isNotEmpty && oUser == userId) return true;
        if (oUser.isEmpty && fbUser != null) {
          final uid = fbUser.uid?.trim();
          final phone = fbUser.phoneNumber?.trim();
          if ((uid != null && uid == userId) || (phone != null && phone == userId)) return true;
        }
        return false;
      }).toList();
      debugPrint('[OrderRepository] localForUser count=${localForUser.length}');

      // Merge: prefer remote entries, append local unsynced ones that don't overlap
      final merged = <OrderModel>[];
      // Use remote id or localId to detect duplicates
      final remoteIds = remote.map((r) => r.id).whereType<String>().toSet();

      merged.addAll(remote);
      for (final lo in localForUser) {
        // If local order already uploaded (has remote id), skip; otherwise include
        if (lo.id != null && remoteIds.contains(lo.id)) continue;
        merged.add(lo);
      }

      debugPrint('[OrderRepository] merged orders count=${merged.length}');
      // Sort by createdAt descending
      merged.sort((a, b) {
        try {
          final da = a.createdAt.toDate();
          final db = b.createdAt.toDate();
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });
      return merged;
    } catch (e) {
      return [];
    }
  }
}
