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

    // Prefer writing into the user's private subcollection so clients can
    // always read their own orders even when top-level `orders` reads are
    // restricted by security rules. After creating the per-user doc we'll
    // attempt to mirror it to the top-level `orders` collection if allowed.
    if (userId != null && userId.isNotEmpty) {
      final userOrdersCol = _firestore.collection('users').doc(userId).collection('orders');
      final payload = <String, dynamic>{
        'orderOwner': userId,
        'userId': order.userId,
        'items': order.items.map((i) => i.toMap()).toList(),
        'addressSnapshot': order.addressSnapshot,
        'subtotal': order.subtotal,
        'discount': order.discount,
        'tax': order.tax,
        'total': order.total,
        'totalAmount': order.total,
        'orderStatus': order.orderStatus.name,
        'status': order.orderStatus.name,
        'paymentStatus': order.paymentStatus.name,
        'scheduledAt': order.scheduledAt,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await userOrdersCol.add(payload);
      try {
        await docRef.update({'remoteId': docRef.id});
      } catch (_) {}

      // Try to mirror to top-level `orders` using the same document id so
      // admin tooling or server-side functions can find the document there.
      try {
        final topRef = _firestore.collection('orders').doc(docRef.id);
        final mirror = Map<String, dynamic>.from(payload);
        mirror['remoteId'] = docRef.id;
        mirror['mirroredFromUserSubcollection'] = true;
        mirror['createdAt'] = FieldValue.serverTimestamp();
        mirror['updatedAt'] = FieldValue.serverTimestamp();
        await topRef.set(mirror, SetOptions(merge: true));
      } catch (e) {
        // Non-fatal: top-level mirror may be denied by rules. This is OK.
        debugPrint('[OrderRepository] Top-level mirror failed (allowed when restricted): $e');
      }
      return;
    }

    // If no explicit userId passed, still write to the user's subcollection
    // discovered from order.userId. This covers cases where callers didn't
    // pass the `userId` parameter but the order already contains it.
    final userOrdersCol = _firestore.collection('users').doc(order.userId).collection('orders');
    final data = order.toFirestore();
    data.remove('orderNumber');
    data['totalAmount'] = data['total'] ?? order.total;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final docRef = await userOrdersCol.add(data);
    try { await docRef.update({'remoteId': docRef.id}); } catch (_) {}
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

    // First, write to the user's subcollection so the user can always read it.
    try {
      final userOrderCol = _firestore.collection('users').doc(userId).collection('orders');
      DocumentReference userDocRef;
      if (localOrder.id.isNotEmpty) {
        userDocRef = userOrderCol.doc(localOrder.id);
        await userDocRef.set(cleanedData, SetOptions(merge: true));
      } else {
        userDocRef = await userOrderCol.add(cleanedData);
        try { await userDocRef.update({'remoteId': userDocRef.id}); } catch (_) {}
      }

      final newId = userDocRef.id;

      // Attempt to mirror to top-level `orders` using the same id so admins/tools
      // can discover it. This may be denied by rules for non-admins — that's OK.
      try {
        final topRef = _firestore.collection('orders').doc(newId);
        final mirror = Map<String, dynamic>.from(cleanedData);
        mirror['remoteId'] = newId;
        mirror['mirroredFromUserSubcollection'] = true;
        mirror['createdAt'] = FieldValue.serverTimestamp();
        mirror['updatedAt'] = FieldValue.serverTimestamp();
        await topRef.set(mirror, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[OrderRepository] Top-level mirror failed while uploading order (non-fatal): $e');
      }

      return newId;
    } catch (e) {
      debugPrint('[OrderRepository] Failed to write user subcollection order for user=$userId: $e');
      rethrow;
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
        debugPrint('[OrderRepository] fetched ${userOrdersSnap.docs.length} orders from users/{uid}/orders for user=$userId');
        return userOrdersSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      } else {
        debugPrint('[OrderRepository] users/{uid}/orders returned 0 docs for user=$userId');
      }
    } catch (e) {
      debugPrint('[OrderRepository] Failed to fetch from users/{uid}/orders: $e');
      // If the user's private subcollection read fails it is usually a fatal
      // condition for client-side reads (bad rules or auth). Surface the
      // exception so the UI can show it instead of silently falling back.
      rethrow;
    }

    // 2. If the subcollection is empty or fails, query the top-level collection.
    try {
      final snapshot = await _firestore.collection('orders').where('orderOwner', isEqualTo: userId).orderBy('createdAt', descending: true).get();
      debugPrint('[OrderRepository] fetched ${snapshot.docs.length} orders from top-level orders for user=$userId');
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    } catch (e) {
      final errString = e.toString();
      if (errString.contains('permission-denied') || errString.contains('PERMISSION_DENIED')) {
        debugPrint('[OrderRepository] PERMISSION_DENIED on top-level fetch for user=$userId');
        // If the user's subcollection returned 0 docs and top-level is denied
        // it likely means rules prevent clients from reading the top-level
        // orders collection. Instead of silently returning an empty list we
        // throw so callers can display a helpful error and next steps.
        throw Exception('Permission denied reading top-level orders. Ensure Firestore rules allow reads on orders when filtering by orderOwner or use users/{uid}/orders for user reads.');
      } else {
        debugPrint('[OrderRepository] Top-level fetchOrdersForUser failed for user=$userId: $e');
      }
    }

    return []; // Return empty list if both attempts yield no documents (no orders)
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