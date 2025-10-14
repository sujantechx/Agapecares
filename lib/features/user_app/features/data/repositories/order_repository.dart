// File: lib/features/user_app/data/repositories/order_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'package:agapecares/core/services/local_database_service.dart';


/// Orchestrates saving orders locally and syncing to Firestore.
/// Why: keep offline-first UX and eventual consistency with backend.
class OrderRepository {
  final LocalDatabaseService _localDb;
  final FirebaseFirestore _firestore;

  // Guard set to avoid concurrent uploads for the same local order id.
  final Set<int> _uploadingLocalIds = {};

  OrderRepository({required LocalDatabaseService localDb, FirebaseFirestore? firestore})
      : _localDb = localDb,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> init() async {
    await _localDb.init();
  }

  /// Generate a daily order number in the format YYYYMMDD + 5-digit suffix (e.g. 2025101200100)
  /// The suffix starts at 00100 for the first order of the day and increments.
  /// Strategy: try a Firestore collectionGroup query for today's max orderNumber; fallback to local DB if remote fails.
  Future<String> generateOrderNumber() async {
    final now = DateTime.now().toUtc();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final prefix = '$y$m$d';

    // Primary approach: use a per-day counter document in Firestore to atomically
    // reserve and increment the sequence. Collection: 'order_counters', doc id = YYYYMMDD.
    try {
      final counterRef = _firestore.collection('order_counters').doc(prefix);
      final seq = await _firestore.runTransaction<int>((tx) async {
        final snap = await tx.get(counterRef);
        int current = 0;
        if (snap.exists) {
          final data = snap.data();
          if (data != null && data['seq'] is int) {
            current = data['seq'] as int;
          } else if (data != null && data['seq'] is String) {
            current = int.tryParse(data['seq'] as String) ?? 0;
          }
        }
        final next = current + 1;
        tx.set(counterRef, {'seq': next, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        return next;
      });

      // Map seq to suffix where seq==1 => suffix 00100 baseline
      final suffixNum = (seq + 99); // seq 1 -> 100
      final suffix = suffixNum.toString().padLeft(5, '0');
      return '$prefix$suffix';
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber transaction failed: $e');
      // Fall back to prior best-effort logic (collectionGroup/local)
    }

    // Fallback: query remote collectionGroup for today's max orderNumber
    try {
      final start = prefix;
      final end = '$prefix\uf8ff';
      final q = _firestore.collectionGroup('orders').where('orderNumber', isGreaterThanOrEqualTo: start).where('orderNumber', isLessThanOrEqualTo: end).orderBy('orderNumber', descending: true).limit(1);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        final last = snap.docs.first.data()['orderNumber'] as String? ?? '';
        if (last.length >= prefix.length + 1) {
          final suffixStr = last.substring(prefix.length);
          final prev = int.tryParse(suffixStr) ?? 100; // default baseline
          final next = (prev + 1);
          final suffix = next.toString().padLeft(5, '0');
          return '$prefix$suffix';
        }
      }
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber remote lookup failed: $e');
    }

    // Fallback: look in local unsynced orders for today
    try {
      final local = await _localDb.getUnsyncedOrders();
      final todays = local.where((o) => o.orderNumber.startsWith(prefix)).toList();
      if (todays.isNotEmpty) {
        // find max suffix
        final nums = todays.map((o) {
          final s = o.orderNumber;
          if (s.length <= prefix.length) return 100;
          return int.tryParse(s.substring(prefix.length)) ?? 100;
        }).toList();
        final maxPrev = nums.reduce((a, b) => a > b ? a : b);
        final next = maxPrev + 1;
        final suffix = next.toString().padLeft(5, '0');
        return '$prefix$suffix';
      }
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber local fallback failed: $e');
    }

    // Last resort: start at baseline 00100
    return '$prefix' + '00100';
  }

  /// Save order locally. Returns the saved local OrderModel (with localId set).
  Future<OrderModel> createOrder(OrderModel order, {bool uploadRemote = false}) async {
    // If caller wants to upload immediately, prefer Firestore as the single source
    // of truth: create the document remotely first and return a synced OrderModel.
    if (uploadRemote) {
      // Build upload map and ensure userId
      var uploadData = order.toFirebaseJson();
      // order.userId is non-nullable on OrderModel; trim and treat empty -> null
      final candidate = order.userId.trim();
      String? finalUserId = candidate.isNotEmpty ? candidate : null;
      if (finalUserId == null) {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final uid = fbUser.uid.trim();
          final phone = fbUser.phoneNumber?.trim();
          if (uid.isNotEmpty) {
            finalUserId = uid;
          } else if (phone != null && phone.isNotEmpty) {
            finalUserId = phone;
          }
        }
      }

      if (finalUserId == null || finalUserId.isEmpty) {
        final msg = 'Cannot create remote order: userId is empty (no authenticated user).';
        debugPrint('[OrderRepository] $msg');
        throw Exception(msg);
      }
      uploadData['userId'] = finalUserId;

      // Ensure orderNumber
      try {
        if (order.orderNumber.trim().isEmpty) {
          uploadData['orderNumber'] = await generateOrderNumber();
        } else {
          uploadData['orderNumber'] = order.orderNumber;
        }
      } catch (e) {
        debugPrint('[OrderRepository] failed to ensure orderNumber before remote create: $e');
        uploadData['orderNumber'] = order.orderNumber;
      }

      if (uploadData['createdAt'] == null) uploadData['createdAt'] = Timestamp.now();

      final userDoc = _firestore.collection('users').doc(finalUserId);
      final ordersCol = userDoc.collection('orders');

      // Ensure we don't create duplicate remote docs: try lookup by orderNumber + userId
      try {
        if (uploadData['orderNumber'] is String && (uploadData['orderNumber'] as String).isNotEmpty) {
          final on = uploadData['orderNumber'] as String;
          final q = await _firestore.collectionGroup('orders').where('orderNumber', isEqualTo: on).where('userId', isEqualTo: finalUserId).limit(1).get();
          if (q.docs.isNotEmpty) {
            final existingRef = q.docs.first.reference;
            await existingRef.set(uploadData, SetOptions(merge: true));
            final rid = q.docs.first.id;
            debugPrint('[OrderRepository] createOrder found existing remote doc id=$rid, merged data');
            return order.copyWith(id: rid, isSynced: true);
          }
        }
      } catch (e) {
        debugPrint('[OrderRepository] pre-create duplicate check failed: $e');
      }

      // Create new remote doc
      final newDoc = ordersCol.doc();
      final newRemoteId = newDoc.id;
      uploadData['remoteId'] = newRemoteId;
      try {
        await newDoc.set(uploadData);
        try {
          await newDoc.update({'remoteId': newRemoteId});
        } catch (_) {}
        debugPrint('[OrderRepository] createOrder created remote doc id=$newRemoteId');
        // Return an OrderModel representing the remote-synced order. Do not create a local sqlite row first.
        return order.copyWith(id: newRemoteId, isSynced: true);
      } catch (e) {
        debugPrint('[OrderRepository] createOrder remote create failed: $e');
        // As a last resort, fall back to saving locally so the order isn't lost.
        // Ensure we have an orderNumber before local save to reduce duplicate creation later
        if (order.orderNumber.trim().isEmpty) {
          try {
            final gen = await generateOrderNumber();
            order = order.copyWith(orderNumber: gen);
          } catch (e) {
            debugPrint('[OrderRepository] fallback: failed to generate orderNumber: $e');
          }
        }
        final saved = await _localDb.createOrder(order);
        debugPrint('[OrderRepository] createOrder falling back to local save localId=${saved.localId}');
        return saved;
      }
    }

    // Offline/default path: save locally and return the local record
    // Ensure orderNumber exists for local saves so upload later can find and merge instead of creating duplicates
    if (order.orderNumber.trim().isEmpty) {
      try {
        final gen = await generateOrderNumber();
        order = order.copyWith(orderNumber: gen);
      } catch (e) {
        debugPrint('[OrderRepository] offline save: failed to generate orderNumber: $e');
      }
    }
    final saved = await _localDb.createOrder(order);
    return saved;
  }

  /// Attempts to upload a single local order to Firestore.
  /// On success marks the local row as synced and updates remote id if available.
  /// Returns the Firestore document id on success, or null on failure.
  Future<String?> uploadOrder(OrderModel localOrder) async {
    try {
      // Prevent concurrent uploads for the same localId
      if (localOrder.localId != null) {
        if (_uploadingLocalIds.contains(localOrder.localId)) {
          debugPrint('[OrderRepository] uploadOrder already in progress for localId=${localOrder.localId}, skipping duplicate call');
          return localOrder.id;
        }
        _uploadingLocalIds.add(localOrder.localId!);
      }

      // Defensive: consult local DB to see if this localId is already marked synced.
      if (localOrder.localId != null) {
        try {
          final unsynced = await _localDb.getUnsyncedOrders();
          final found = unsynced.any((o) => o.localId == localOrder.localId);
          if (!found) {
            debugPrint('[OrderRepository] uploadOrder skipped: local DB shows this localId=${localOrder.localId} as already synced');
            return localOrder.id;
          }
        } catch (e) {
          // ignore and proceed with best-effort
        }
      }

      // Build upload map and ensure userId
      var uploadData = localOrder.toFirebaseJson();
      final localUserId = (localOrder.userId).trim();
      String? finalUserId = localUserId.isNotEmpty ? localUserId : null;
      if (finalUserId == null) {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final uid = fbUser.uid.trim();
          final phone = fbUser.phoneNumber?.trim();
          if (uid.isNotEmpty) {
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
      uploadData['userId'] = finalUserId;

      // Ensure orderNumber
      try {
        if (localOrder.orderNumber.trim().isEmpty) {
          uploadData['orderNumber'] = await generateOrderNumber();
        } else {
          uploadData['orderNumber'] = localOrder.orderNumber;
        }
      } catch (e) {
        debugPrint('[OrderRepository] failed to ensure orderNumber before upload: $e');
        uploadData['orderNumber'] = localOrder.orderNumber;
      }

      if (uploadData['createdAt'] == null) uploadData['createdAt'] = Timestamp.now();

      final userDoc = _firestore.collection('users').doc(finalUserId);
      final ordersCol = userDoc.collection('orders');

      // Attach localId into uploadData so remote copy can be tied back to the local row.
      if (localOrder.localId != null) uploadData['localId'] = localOrder.localId;

      // 1) Try to locate an existing remote doc by localId across all users (collectionGroup), this avoids duplicates when previous partial uploads used different parent path.
      if (localOrder.localId != null) {
        try {
          final cgByLocal = await _firestore.collectionGroup('orders').where('localId', isEqualTo: localOrder.localId).limit(1).get();
          if (cgByLocal.docs.isNotEmpty) {
            final docRef = cgByLocal.docs.first.reference;
            await docRef.set(uploadData, SetOptions(merge: true));
            final remoteId = docRef.id;
            // mark local synced and update local remote id if necessary
            if (localOrder.localId != null) {
              try {
                await _localDb.markOrderAsSynced(localOrder.localId!);
                if (localOrder.id == null || localOrder.id!.isEmpty) {
                  final updated = localOrder.copyWith(id: remoteId);
                  await _localDb.updateOrder(updated);
                }
              } catch (e) {
                debugPrint('[OrderRepository] failed to update local DB after merging existing collectionGroup doc: $e');
              }
            }
            return remoteId;
          }
        } catch (e) {
          debugPrint('[OrderRepository] collectionGroup lookup by localId failed: $e');
        }
      }

      // 2) Try locating by localOrder.id within the user's orders path
      if (localOrder.id != null && localOrder.id!.trim().isNotEmpty) {
        try {
          final candidate = ordersCol.doc(localOrder.id);
          final snap = await candidate.get();
          if (snap.exists) {
            await candidate.set(uploadData, SetOptions(merge: true));
            if (localOrder.localId != null) {
              try {
                await _localDb.markOrderAsSynced(localOrder.localId!);
              } catch (_) {}
            }
            return candidate.id;
          }
        } catch (e) {
          debugPrint('[OrderRepository] lookup by provided remote id failed: $e');
        }
      }

      // 3) Try locating by orderNumber + userId (safe guard against duplicates when localId wasn't written previously)
      try {
        if (uploadData['orderNumber'] is String && (uploadData['orderNumber'] as String).isNotEmpty) {
          final on = uploadData['orderNumber'] as String;
          final q = await _firestore.collectionGroup('orders').where('orderNumber', isEqualTo: on).where('userId', isEqualTo: finalUserId).limit(1).get();
          if (q.docs.isNotEmpty) {
            final ref = q.docs.first.reference;
            await ref.set(uploadData, SetOptions(merge: true));
            final rid = ref.id;
            if (localOrder.localId != null) {
              try {
                await _localDb.markOrderAsSynced(localOrder.localId!);
                if (localOrder.id == null || localOrder.id!.isEmpty) {
                  final updated = localOrder.copyWith(id: rid);
                  await _localDb.updateOrder(updated);
                }
              } catch (e) {
                debugPrint('[OrderRepository] failed to update local DB after merging by orderNumber: $e');
              }
            }
            return rid;
          }
        }
      } catch (e) {
        debugPrint('[OrderRepository] collectionGroup lookup by orderNumber failed: $e');
      }

      // 4) No existing doc found -- create a new doc under user/{userId}/orders with a reserved id so future attempts can update it instead of duplicating.
      final newDocRef = ordersCol.doc();
      final newRemoteId = newDocRef.id;
      uploadData['remoteId'] = newRemoteId;
      if (localOrder.localId != null) uploadData['localId'] = localOrder.localId;

      await newDocRef.set(uploadData);

      if (localOrder.localId != null) {
        try {
          await _localDb.markOrderAsSynced(localOrder.localId!);
          final updated = localOrder.copyWith(id: newRemoteId, isSynced: true);
          await _localDb.updateOrder(updated);
        } catch (e) {
          debugPrint('[OrderRepository] failed to update local DB after creating remote doc: $e');
        }
      }

      // ensure remoteId field exists
      try {
        await newDocRef.update({'remoteId': newRemoteId});
      } catch (_) {}

      return newRemoteId;
    } on FirebaseException catch (e) {
      final msg = 'Firestore upload failed: code=${e.code} message=${e.message}';
      debugPrint('[OrderRepository] $msg');
      rethrow;
    } catch (e) {
      debugPrint('[OrderRepository] uploadOrder failed: $e');
      rethrow;
    } finally {
      if (localOrder.localId != null) _uploadingLocalIds.remove(localOrder.localId);
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
    debugPrint('[OrderRepository] syncUnsynced found ${unsynced.length} unsynced orders');

    for (final o in unsynced) {
      try {
        // Conservative policy: only upload orders that are safe to publish.
        // Upload conditions:
        // - Online payment flows (e.g., razorpay) where paymentStatus == 'success'
        // - Orders that have been explicitly confirmed (orderStatus != 'pending')
        // For COD, the checkout flow should call uploadOrder when the user confirms.
        final pm = (o.paymentMethod).toLowerCase();
        final paymentOk = (o.paymentStatus).toLowerCase() == 'success';
        final orderConfirmed = (o.orderStatus).toLowerCase() != 'pending';

        final shouldUpload = paymentOk || orderConfirmed;
        if (!shouldUpload) {
          debugPrint('[OrderRepository] skipping upload for localId=${o.localId} orderNumber=${o.orderNumber} paymentMethod=$pm paymentStatus=${o.paymentStatus} orderStatus=${o.orderStatus}');
          continue;
        }

        debugPrint('[OrderRepository] attempting upload for localId=${o.localId} orderNumber=${o.orderNumber}');
        await uploadOrder(o);
      } catch (e, s) {
        debugPrint('[OrderRepository] syncUnsynced: upload failed for local order ${o.localId}: ${e.toString()}');
        try {
          debugPrint(s.toString());
        } catch (_) {}
        // continue with next order
      }
    }
  }

  /// Fetch orders for a specific user from Firestore (remote source).
  Future<List<OrderModel>> getOrdersForUser(String userId) async {
    try {
      // Prefer user-scoped collection: /users/{userId}/orders
      try {
        final userOrders = await _firestore.collection('users').doc(userId).collection('orders').orderBy('createdAt', descending: true).get();
        return userOrders.docs.map((d) {
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
            paymentStatus: data['paymentStatus'] as String? ?? 'pending',
            paymentMethod: data['paymentMethod'] as String? ?? '',
            paymentId: data['paymentId'] as String?,
            orderStatus: data['orderStatus'] as String? ?? 'pending',
            userName: data['userName'] as String? ?? '',
            userEmail: data['userEmail'] as String? ?? '',
            userPhone: data['userPhone'] as String? ?? '',
            userAddress: data['userAddress'] as String? ?? '',
            workerId: data['workerId'] as String?,
            workerName: data['workerName'] as String?,
            acceptedAt: data['acceptedAt'] is Timestamp ? data['acceptedAt'] : null,
            createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
            rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : (data['rating'] is String ? double.tryParse('${data['rating']}') : null),
            review: data['review'] as String?, orderNumber: '',
          );
        }).toList();
      } catch (e) {
        debugPrint('[OrderRepository] user-scoped orders query failed, falling back to legacy root collection: $e');
      }

      // Fallback to legacy root collection when user-scoped data is not available
      try {
        final snapshot = await _firestore.collection('orders').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).get();
        return snapshot.docs.map((d) {
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
            paymentStatus: data['paymentStatus'] as String? ?? 'pending',
            paymentMethod: data['paymentMethod'] as String? ?? '',
            paymentId: data['paymentId'] as String?,
            orderStatus: data['orderStatus'] as String? ?? 'pending',
            userName: data['userName'] as String? ?? '',
            userEmail: data['userEmail'] as String? ?? '',
            userPhone: data['userPhone'] as String? ?? '',
            userAddress: data['userAddress'] as String? ?? '',
            workerId: data['workerId'] as String?,
            workerName: data['workerName'] as String?,
            acceptedAt: data['acceptedAt'] is Timestamp ? data['acceptedAt'] : null,
            createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
            rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : (data['rating'] is String ? double.tryParse('${data['rating']}') : null),
            review: data['review'] as String?, orderNumber: '',
          );
        }).toList();
      } catch (e) {
        debugPrint('[OrderRepository] legacy root orders query failed: $e');
        return [];
      }
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
          final uid = fbUser.uid.trim();
          final phone = fbUser.phoneNumber?.trim();
          if ((uid.isNotEmpty && uid == userId) || (phone != null && phone == userId)) return true;
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

  /// Fetch incoming orders for a worker — orders placed within the last [withinHours]
  /// and not yet accepted. This queries remote firestore for recent orders with
  /// status 'Placed' (or pending) and then filters out any that already have a worker.
  Future<List<OrderModel>> getIncomingOrdersForWorker({int withinHours = 1}) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().toUtc().subtract(Duration(hours: withinHours)));
      // Use collectionGroup to query all user subcollections 'orders'
      final snapshot = await _firestore.collectionGroup('orders').where('orderStatus', isEqualTo: 'pending').where('createdAt', isGreaterThanOrEqualTo: cutoff).orderBy('createdAt', descending: true).get();
      final docs = snapshot.docs;
      final incoming = <OrderModel>[];
      for (final d in docs) {
        final data = d.data();
        final workerId = (data['workerId'] as String?) ?? '';
        if (workerId.trim().isNotEmpty) continue; // already assigned
        final itemsRaw = (data['items'] as List<dynamic>?) ?? <dynamic>[];
        final items = itemsRaw.map((e) {
          if (e is Map<String, dynamic>) return OrderModel.cartItemFromMap(e);
          if (e is Map) return OrderModel.cartItemFromMap(Map<String, dynamic>.from(e));
          return OrderModel.cartItemFromMap(null);
        }).toList();
        incoming.add(OrderModel(
          localId: null,
          isSynced: true,
          id: d.id,
          userId: data['userId'] as String? ?? '',
          items: items.cast(),
          subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
          discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
          total: (data['total'] as num?)?.toDouble() ?? 0.0,
          paymentStatus: data['paymentStatus'] as String? ?? 'pending',
          paymentMethod: data['paymentMethod'] as String? ?? '',
          paymentId: data['paymentId'] as String?,
          orderStatus: data['orderStatus'] as String? ?? 'pending',
          userName: data['userName'] as String? ?? '',
          userEmail: data['userEmail'] as String? ?? '',
          userPhone: data['userPhone'] as String? ?? '',
          userAddress: data['userAddress'] as String? ?? '',
          workerId: null,
          workerName: null,
          acceptedAt: null,
          createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
          rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : (data['rating'] is String ? double.tryParse('${data['rating']}') : null),
          review: data['review'] as String?, orderNumber: '',
        ));
      }
      return incoming;
    } catch (e) {
      debugPrint('[OrderRepository] getIncomingOrdersForWorker failed: $e');
      return [];
    }
  }

  /// Assign/accept an order for a worker. Updates Firestore and local DB if present.
  Future<bool> assignOrderToWorker({required OrderModel order, required String workerId, required String workerName}) async {
    try {
      final acceptedAt = Timestamp.now();
      if (order.id != null && order.id!.isNotEmpty) {
        // We don't know which parent user document contains the order id when using collectionGroup,
        // so attempt to update via collectionGroup query to find the document reference path.
        // First try user-scoped path if userId available
        DocumentReference? docRef;
        try {
          if (order.userId.trim().isNotEmpty) {
            final candidate = _firestore.collection('users').doc(order.userId).collection('orders').doc(order.id);
            final snap = await candidate.get();
            if (snap.exists) docRef = candidate;
          }
        } catch (_) {}
        if (docRef == null) {
          // Last resort: find the document via collectionGroup
          final q = await _firestore.collectionGroup('orders').where(FieldPath.documentId, isEqualTo: order.id).get();
          if (q.docs.isNotEmpty) {
            final path = q.docs.first.reference.path;
            docRef = _firestore.doc(path);
          }
        }
        if (docRef == null) return false;
        // Use transaction to ensure workerId is not already set (avoid double-accept)
        final docRefNonNull = docRef;
        final success = await _firestore.runTransaction<bool>((tx) async {
          final snapshot = await tx.get(docRefNonNull);
          if (!snapshot.exists) return false;
          final data = snapshot.data() as Map<String, dynamic>?;
          final existingWorker = (data?['workerId'] as String?) ?? '';
          final status = (data?['orderStatus'] as String?) ?? 'pending';
          if (existingWorker.trim().isNotEmpty || status.toLowerCase() != 'pending') {
            // Already assigned or not in pending state, fail
            return false;
          }
          tx.update(docRefNonNull, {'workerId': workerId, 'workerName': workerName, 'acceptedAt': acceptedAt, 'orderStatus': 'assigned'});
          return true;
        });
        if (!success) return false;
      }

      // Update local DB copy if exists
      final updated = order.copyWith(orderStatus: 'assigned', workerId: workerId, workerName: workerName, acceptedAt: acceptedAt);
      try {
        await _localDb.updateOrder(updated);
      } catch (_) {}
      return true;
    } on FirebaseException catch (e) {
      debugPrint('[OrderRepository] assignOrderToWorker Firestore error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[OrderRepository] assignOrderToWorker failed: $e');
      return false;
    }
  }

  /// Fetch orders assigned to a worker (accepted / in-progress / completed)
  Future<List<OrderModel>> getAssignedOrdersForWorker(String workerId) async {
    try {
      // Use collectionGroup to fetch assigned orders across all users' orders subcollections
      final snap = await _firestore.collectionGroup('orders').where('workerId', isEqualTo: workerId).orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) {
        final data = d.data();
        final itemsRaw = (data['items'] as List<dynamic>?) ?? <dynamic>[];
        final items = itemsRaw.map((e) {
          if (e is Map<String, dynamic>) return OrderModel.cartItemFromMap(e);
          if (e is Map) return OrderModel.cartItemFromMap(Map<String, dynamic>.from(e));
          return OrderModel.cartItemFromMap(null);
        }).toList();
        return OrderModel(
          localId: null,
          isSynced: true,
          id: d.id,
          userId: data['userId'] as String? ?? '',
          items: items.cast(),
          subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
          discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
          total: (data['total'] as num?)?.toDouble() ?? 0.0,
          paymentStatus: data['paymentStatus'] as String? ?? 'pending',
          paymentMethod: data['paymentMethod'] as String? ?? '',
          paymentId: data['paymentId'] as String?,
          orderStatus: data['orderStatus'] as String? ?? 'pending',
          userName: data['userName'] as String? ?? '',
          userEmail: data['userEmail'] as String? ?? '',
          userPhone: data['userPhone'] as String? ?? '',
          userAddress: data['userAddress'] as String? ?? '',
          workerId: data['workerId'] as String?,
          workerName: data['workerName'] as String?,
          acceptedAt: data['acceptedAt'] is Timestamp ? data['acceptedAt'] : null,
          createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),
          rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : (data['rating'] is String ? double.tryParse('${data['rating']}') : null),
          review: data['review'] as String?, orderNumber: '',
        );
      }).toList();
    } catch (e) {
      debugPrint('[OrderRepository] getAssignedOrdersForWorker failed: $e');
      return [];
    }
  }

  /// Mark an order as completed. Updates Firestore and local DB if possible.
  Future<bool> completeOrder(OrderModel order) async {
    try {
      if (order.id != null && order.id!.isNotEmpty) {
        // Prefer updating the user-scoped document
        DocumentReference? docRef;
        try {
          if (order.userId.trim().isNotEmpty) {
            final candidate = _firestore.collection('users').doc(order.userId).collection('orders').doc(order.id);
            final snap = await candidate.get();
            if (snap.exists) docRef = candidate;
          }
        } catch (_) {}
        if (docRef == null) {
          // Try to find the document via collectionGroup
          final q = await _firestore.collectionGroup('orders').where(FieldPath.documentId, isEqualTo: order.id).get();
          if (q.docs.isNotEmpty) {
            docRef = _firestore.doc(q.docs.first.reference.path);
          }
        }
        if (docRef != null) await docRef.update({'orderStatus': 'complete'});
      }
      final updated = order.copyWith(orderStatus: 'complete');
      try {
        await _localDb.updateOrder(updated);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('[OrderRepository] completeOrder failed: $e');
      return false;
    }
  }

  /// Submit rating and optional review for an order. Updates Firestore document
  /// and local DB row if found. Returns true on success.
  Future<bool> submitRatingForOrder({required OrderModel order, required double rating, String? review}) async {
    try {
      if (order.id != null && order.id!.isNotEmpty) {
        DocumentReference? docRef;
        try {
          if (order.userId.trim().isNotEmpty) {
            final candidate = _firestore.collection('users').doc(order.userId).collection('orders').doc(order.id);
            final snap = await candidate.get();
            if (snap.exists) docRef = candidate;
          }
        } catch (_) {}
        if (docRef == null) {
          final q = await _firestore.collectionGroup('orders').where(FieldPath.documentId, isEqualTo: order.id).get();
          if (q.docs.isNotEmpty) docRef = _firestore.doc(q.docs.first.reference.path);
        }
        if (docRef != null) {
          final updates = <String, dynamic>{'rating': rating, 'review': review ?? ''};
          // Keep orderStatus as-is; if order is still pending we won't change it here.
          await docRef.set(updates, SetOptions(merge: true));
        }
      }

      // Update local DB
      final updated = order.copyWith();
      try {
        // Since copyWith doesn't accept rating directly from older versions, create a manual copy
        final localUpdated = OrderModel(
           localId: updated.localId,
           isSynced: updated.isSynced,
           id: updated.id,
           orderNumber: updated.orderNumber,
           paymentStatus: updated.paymentStatus,
           userId: updated.userId,
           items: updated.items,
           subtotal: updated.subtotal,
           discount: updated.discount,
           total: updated.total,
           paymentMethod: updated.paymentMethod,
           paymentId: updated.paymentId,
           orderStatus: updated.orderStatus,
           userName: updated.userName,
           userEmail: updated.userEmail,
           userPhone: updated.userPhone,
           userAddress: updated.userAddress,
           workerId: updated.workerId,
           workerName: updated.workerName,
           acceptedAt: updated.acceptedAt,
           rating: rating,
           review: review,
           createdAt: updated.createdAt,
         );
         await _localDb.updateOrder(localUpdated);
       } catch (e) {
         // ignore local update failure
       }
      return true;
    } catch (e) {
      debugPrint('[OrderRepository] submitRatingForOrder failed: $e');
      return false;
    }
  }

  /// Administrative helper: find duplicate remote orders for the given user+orderNumber
  /// and keep a single canonical document (earliest createdAt), deleting the rest.
  /// Use carefully (run once during migration/cleanup).
  Future<void> dedupeRemoteOrdersForUser({required String userId, required String orderNumber}) async {
    try {
      if (userId.trim().isEmpty || orderNumber.trim().isEmpty) return;
      // Query across all users' orders subcollections for matching orderNumber + userId
      final q = await _firestore.collectionGroup('orders').where('orderNumber', isEqualTo: orderNumber).where('userId', isEqualTo: userId).get();
      final docs = q.docs;
      if (docs.length <= 1) return; // nothing to do

      // Sort by createdAt (fallback to server timestamp ordering by document id when missing)
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTs = aData['createdAt'] is Timestamp ? (aData['createdAt'] as Timestamp).toDate() : null;
        final bTs = bData['createdAt'] is Timestamp ? (bData['createdAt'] as Timestamp).toDate() : null;
        if (aTs != null && bTs != null) return aTs.compareTo(bTs);
        return a.id.compareTo(b.id);
      });

      final keep = docs.first;
      final toDelete = docs.skip(1).toList();

      debugPrint('[OrderRepository] dedupeRemoteOrdersForUser: keeping=${keep.reference.path} deleting=${toDelete.map((d) => d.reference.path).toList()}');

      // Attempt to merge localId into the kept doc if any duplicates contain localId
      try {
        final keepData = keep.data();
        for (final d in docs) {
          final dData = d.data();
          if (dData['localId'] != null && (keepData['localId'] == null || (keepData['localId'] as int) == 0)) {
            await keep.reference.set({'localId': dData['localId']}, SetOptions(merge: true));
            break;
          }
        }
      } catch (e) {
        debugPrint('[OrderRepository] dedupe merge localId failed: $e');
      }

      // Delete the duplicates
      for (final d in toDelete) {
        try {
          await d.reference.delete();
        } catch (e) {
          debugPrint('[OrderRepository] failed to delete duplicate doc ${d.reference.path}: $e');
        }
      }

      // Optionally, mark local DB row as synced if it referenced one of the deleted docs
      try {
        final keepData = keep.data();
        if (keepData['localId'] != null) {
          final loc = keepData['localId'];
          if (loc is int) {
            await _localDb.markOrderAsSynced(loc);
          } else if (loc is String) {
            final parsed = int.tryParse(loc);
            if (parsed != null) await _localDb.markOrderAsSynced(parsed);
          }
        }
      } catch (e) {
        debugPrint('[OrderRepository] dedupe post-mark sync failed: $e');
      }
    } catch (e) {
      debugPrint('[OrderRepository] dedupeRemoteOrdersForUser failed: $e');
    }
  }
}
