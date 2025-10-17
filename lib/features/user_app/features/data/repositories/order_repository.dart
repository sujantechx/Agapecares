import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Assuming your model is in this location, adjust if necessary
import '../../../../../core/models/order_model.dart';

// -----------------------------------------------------------------------------
// ABSTRACTION (THE REPOSITORY INTERFACE)
// -----------------------------------------------------------------------------

/// Abstract interface for managing user and worker orders.
/// This contract defines the data operations required by the app, allowing the
/// underlying data source (like Firestore) to be swapped out.
abstract class OrderRepository {
  /// Create order.
  /// If `uploadRemote` is true, the implementation may upload to Firestore.
  /// When creating a top-level order, clients should pass `userId` (the order owner)
  /// so that server security rules can accept the write.
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true, String? userId});

  /// Generate a unique, daily, sequential order number (e.g., YYYYMMDD00101).
  Future<String> generateOrderNumber();

  /// Upload a local order model to the remote database.
  Future<String> uploadOrder(OrderModel localOrder);

  /// Update an existing remote order document with merge semantics.
  Future<void> updateOrder(OrderModel order);

  /// Fetch all orders for a specific user.
  /// The implementation should handle different data layouts (e.g., per-user
  /// subcollections or top-level collections with security rules).
  Future<List<OrderModel>> fetchOrdersForUser(String userId);

  /// Fetch all orders assigned to a specific worker.
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId);

  /// Fetch orders for an admin dashboard with optional filters.
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters});

  /// Submit a rating and an optional review for a completed order.
  Future<bool> submitRatingForOrder({required OrderModel order, required double rating, String? review});

  /// Administrative helper to find and remove duplicate remote orders for a
  /// given user and order number, keeping only the earliest created one.
  Future<void> dedupeRemoteOrdersForUser({required String userId, required String orderNumber});
}

// -----------------------------------------------------------------------------
// IMPLEMENTATION (FIRESTORE)
// -----------------------------------------------------------------------------

/// Firestore implementation of the [OrderRepository].
class OrderRepositoryImpl implements OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true, String? userId}) async {
    if (!uploadRemote) {
      // TODO: Handle local-only storage if needed
      return;
    }

    // The preferred approach is to create a top-level order document with an
    // explicit owner. This aligns with Firestore rules that allow clients
    // to create top-level orders when they correctly set `orderOwner`.
    if (userId != null && userId.isNotEmpty) {
      final ordersCol = _firestore.collection('orders');
      // Build a client-safe map: DO NOT include server-managed fields like
      // 'orderNumber', 'createdAt', or 'updatedAt'. Use 'totalAmount' key per rules.
      final data = <String, dynamic>{
        'orderOwner': userId,
        'userId': order.userId,
        'items': order.items.map((i) => i.toMap()).toList(),
        'addressSnapshot': order.addressSnapshot,
        'subtotal': order.subtotal,
        'discount': order.discount,
        'tax': order.tax,
        // Store both keys to satisfy legacy code and security rules which expect
        // `totalAmount` while our model uses `total`.
        'total': order.total,
        'totalAmount': order.total,
        'orderStatus': order.orderStatus.name,
        'status': order.orderStatus.name, // Keep both for compatibility
        'paymentStatus': order.paymentStatus.name,
        'scheduledAt': order.scheduledAt,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final docRef = await ordersCol.add(data);
      // Setting remoteId in a subsequent update is a separate write and is allowed by rules.
      try {
        await docRef.update({'remoteId': docRef.id});
      } catch (_) {}

      // IMPORTANT: Mirror the order into the user's subcollection so that
      // client-side reads (which may be restricted on top-level collection)
      // can still list the user's orders. This keeps a lightweight copy and
      // sets the same doc id for easy correlation.
      try {
        final userOrdersDoc = _firestore.collection('users').doc(userId).collection('orders').doc(docRef.id);
        final mirror = Map<String, dynamic>.from(data);
        mirror['remoteId'] = docRef.id;
        // Use server timestamps for created/updated on the mirror too.
        mirror['createdAt'] = FieldValue.serverTimestamp();
        mirror['updatedAt'] = FieldValue.serverTimestamp();
        await userOrdersDoc.set(mirror, SetOptions(merge: true));
      } catch (e) {
        // Non-fatal: mirroring failed (maybe rules differ). We'll continue.
        debugPrint('[OrderRepository] Failed to mirror top-level order into users/{uid}/orders: $e');
      }

      return;
    }

    // Fallback: create a per-user order document if no explicit owner `userId` is provided.
    // This is useful for scenarios where rules are stricter on the top-level collection.
    final userOrdersCol = _firestore.collection('users').doc(order.userId).collection('orders');
    final data = order.toFirestore();
    // Ensure server-managed fields are handled by the server
    data.remove('orderNumber');
    // Ensure both total keys are present for rules and backward compatibility
    data['totalAmount'] = data['total'] ?? order.total;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final docRef = await userOrdersCol.add(data);
    try {
      await docRef.update({'remoteId': docRef.id});
    } catch (_) {}
  }

  @override
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final datePrefix = DateFormat('yyyyMMdd').format(now);
    final counterDocRef = _firestore.collection('order_counters').doc(datePrefix);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterDocRef);
        int newSeq = 1;
        if (snapshot.exists) {
          // Safely get the current sequence number, defaulting to 0 if null.
          newSeq = (snapshot.data()?['seq'] as int? ?? 0) + 1;
        }
        transaction.set(counterDocRef, {'seq': newSeq, 'updatedAt': FieldValue.serverTimestamp()});

        // The first order of the day (seq=1) will have a suffix of 100 (1+99).
        final suffix = (newSeq + 99).toString().padLeft(5, '0');
        return '$datePrefix$suffix';
      });
    } on FirebaseException catch (e) {
      // If the client does not have permission to update the counter (common when
      // counters are protected server-side), fall back to a client-generated order
      // number using the date + a millisecond-based suffix so ordering is still
      // reasonably unique.
      debugPrint('[OrderRepository] generateOrderNumber transaction failed: ${e.message}');
      final fallbackSuffix = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
      return '$datePrefix$fallbackSuffix';
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber unexpected error: $e');
      final fallbackSuffix = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
      return '$datePrefix$fallbackSuffix';
    }
  }

  @override
  Future<String> uploadOrder(OrderModel localOrder) async {
    final userId = localOrder.userId;
    if (userId.isEmpty) throw Exception('Missing userId on order');

    // Prepare a clean payload, removing fields managed by the server/backend.
    final cleanedData = localOrder.toFirestore();
    cleanedData.remove('orderNumber');
    cleanedData.remove('assignmentHistory');
    cleanedData.remove('paymentRef');
    cleanedData.remove('remoteId');
    // Ensure both total keys are present for rules and backward compatibility
    cleanedData['totalAmount'] = cleanedData['total'] ?? localOrder.total;
    cleanedData['createdAt'] = FieldValue.serverTimestamp();
    cleanedData['updatedAt'] = FieldValue.serverTimestamp();
    cleanedData['orderOwner'] = userId;
    cleanedData['status'] = localOrder.orderStatus.name;

    try {
      final ordersCol = _firestore.collection('orders');
      DocumentReference docRef;
      if (localOrder.id.isNotEmpty) {
        docRef = ordersCol.doc(localOrder.id);
        await docRef.set(cleanedData, SetOptions(merge: true));
      } else {
        docRef = await ordersCol.add(cleanedData);
        try { await docRef.update({'remoteId': docRef.id}); } catch (_) {}
      }

      // Mirror the top-level order into the user's subcollection so reads will
      // succeed even if the client cannot read the top-level collection.
      try {
        final userOrdersDoc = _firestore.collection('users').doc(userId).collection('orders').doc(docRef.id);
        final mirror = Map<String, dynamic>.from(cleanedData);
        mirror['remoteId'] = docRef.id;
        mirror['mirroredFromTopLevel'] = true;
        // Ensure the mirror also has both total fields
        mirror['total'] = mirror['total'] ?? localOrder.total;
        mirror['totalAmount'] = mirror['totalAmount'] ?? localOrder.total;
        // Ensure timestamps are server-generated for the mirror as well.
        mirror['createdAt'] = FieldValue.serverTimestamp();
        mirror['updatedAt'] = FieldValue.serverTimestamp();
        await userOrdersDoc.set(mirror, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[OrderRepository] Failed to write mirror in users/{uid}/orders: $e');
      }

      return docRef.id;
    } catch (e) {
      debugPrint('[OrderRepository] Top-level uploadOrder failed for user=$userId: $e. Falling back to users/{uid}/orders.');
      // Fallback to writing to the user's subcollection if the top-level write fails.
      try {
        final userOrderCol = _firestore.collection('users').doc(userId).collection('orders');
        final fallbackRef = await userOrderCol.add(cleanedData);
        try { await fallbackRef.update({'remoteId': fallbackRef.id}); } catch (_) {}
        return fallbackRef.id;
      } catch (e2) {
        debugPrint('[OrderRepository] Fallback uploadOrder also failed for user=$userId: $e2');
        rethrow;
      }
    }
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    try {
      if (order.userId.isEmpty || order.id.isEmpty) return;

      final ref = _firestore.collection('orders').doc(order.id);

      // Prepare a cleaned map to avoid violating security rules
      final cleanedData = order.toFirestore();
      cleanedData.remove('orderNumber');
      cleanedData.remove('assignmentHistory');
      cleanedData.remove('paymentRef');
      cleanedData.remove('remoteId');
      // keep total fields present
      cleanedData['total'] = cleanedData['total'] ?? order.total;
      cleanedData['totalAmount'] = cleanedData['totalAmount'] ?? order.total;
      cleanedData.remove('createdAt'); // Do not overwrite creation timestamp
      cleanedData['updatedAt'] = FieldValue.serverTimestamp();
      cleanedData['orderOwner'] = order.userId;

      await ref.set(cleanedData, SetOptions(merge: true));

      // Also attempt to update the mirror in the user's subcollection so the
      // client's reads remain consistent even if top-level reads are restricted.
      try {
        final userDoc = _firestore.collection('users').doc(order.userId).collection('orders').doc(order.id);
        await userDoc.set(cleanedData, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[OrderRepository] Failed to update mirrored user order doc: $e');
      }
    } catch (e) {
      debugPrint('[OrderRepository] updateOrder failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> fetchOrdersForUser(String userId) async {
    // 1. First, attempt to fetch from the user's private subcollection.
    // This is often more secure and efficient.
    try {
      final userOrdersSnap = await _firestore.collection('users').doc(userId).collection('orders').orderBy('createdAt', descending: true).get();
      if (userOrdersSnap.docs.isNotEmpty) {
        return userOrdersSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      }
    } catch (e) {
      debugPrint('[OrderRepository] Failed to fetch from users/{uid}/orders, falling back to top-level query: $e');
    }

    // 2. If the subcollection is empty or fails, query the top-level collection.
    try {
      final snapshot = await _firestore.collection('orders').where('orderOwner', isEqualTo: userId).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    } catch (e) {
      final errString = e.toString();
      if (errString.contains('permission-denied') || errString.contains('PERMISSION_DENIED')) {
        debugPrint('[OrderRepository] PERMISSION_DENIED on top-level fetch for user=$userId — returning empty list.');
        // Don't throw here; top-level collection may be restricted to server.
        // Since we mirrored writes into users/{uid}/orders, return empty list and let
        // the caller treat it as "no client-readable top-level orders".
        return [];
      } else {
        debugPrint('[OrderRepository] Top-level fetchOrdersForUser failed for user=$userId: $e');
      }
    }

    return []; // Return empty list if both attempts fail
  }

  @override
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId) async {
    try {
      final snap = await _firestore.collection('orders').where('workerId', isEqualTo: workerId).orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrdersForWorker failed: $e');
      return [];
    }
  }

  @override
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters}) async {
    try {
      Query query = _firestore.collection('orders');
      if (filters != null) {
        if (filters['status'] != null) query = query.where('status', isEqualTo: filters['status']);
        if (filters['orderOwner'] != null) query = query.where('orderOwner', isEqualTo: filters['orderOwner']);
        if (filters['workerId'] != null) query = query.where('workerId', isEqualTo: filters['workerId']);
        if (filters['dateFrom'] != null) query = query.where('createdAt', isGreaterThanOrEqualTo: filters['dateFrom']);
        if (filters['dateTo'] != null) query = query.where('createdAt', isLessThanOrEqualTo: filters['dateTo']);
      }
      query = query.orderBy('createdAt', descending: true).limit(filters?['limit'] as int? ?? 100);
      final snap = await query.get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrdersForAdmin failed: $e');
      return [];
    }
  }

  @override
  Future<bool> submitRatingForOrder({required OrderModel order, required double rating, String? review}) async {
    try {
      if (order.id.isNotEmpty && order.userId.isNotEmpty) {
        final ref = _firestore.collection('orders').doc(order.id);
        await ref.update({'rating': rating, 'review': review ?? ''});
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[OrderRepository] submitRatingForOrder failed: $e');
      return false;
    }
  }

  @override
  Future<void> dedupeRemoteOrdersForUser({required String userId, required String orderNumber}) async {
    try {
      if (userId.trim().isEmpty || orderNumber.trim().isEmpty) return;

      final querySnapshot = await _firestore
          .collection('orders')
          .where('orderNumber', isEqualTo: orderNumber)
          .where('orderOwner', isEqualTo: userId)
          .get();

      final docs = querySnapshot.docs;
      if (docs.length <= 1) return; // No duplicates found

      // Sort documents to find the original (oldest) one
      docs.sort((a, b) {
        final aTs = a.data()['createdAt'] as Timestamp?;
        final bTs = b.data()['createdAt'] as Timestamp?;
        if (aTs != null && bTs != null) return aTs.compareTo(bTs);
        return a.id.compareTo(b.id); // Fallback to doc ID if timestamp is missing
      });

      // Delete all documents except the first one (the original)
      final toDelete = docs.skip(1);
      final batch = _firestore.batch();
      for (final doc in toDelete) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[OrderRepository] Deduplicated ${toDelete.length} orders for orderNumber: $orderNumber');
    } catch (e) {
      debugPrint('[OrderRepository] dedupeRemoteOrdersForUser failed: $e');
    }
  }
}