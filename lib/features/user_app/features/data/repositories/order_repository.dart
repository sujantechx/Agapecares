import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Assuming your model is in this location, adjust if necessary
import '../../../../../core/models/order_model.dart';

/// Helper to format an order number from a date and a sequence number.
/// Produces YYYYMMDDxxxxx where seq=1 maps to suffix 10000.
String formatOrderNumberFromDateAndSeq(DateTime dt, int seq) {
  final datePart = DateFormat('yyyyMMdd').format(dt);
  final suffixNumber = (10000 + seq - 1);
  final suffix = suffixNumber.toString().padLeft(5, '0');
  return '$datePart$suffix';
}

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
  Future<List<OrderModel>> fetchOrdersForUser(String userId);

  /// Fetch all orders assigned to a specific worker.
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId);

  /// Stream of orders assigned to a specific worker. Implementations should
  /// prefer per-worker mirrors (`workers/{workerId}/orders`) and fall back to
  /// collectionGroup/top-level queries when necessary.
  Stream<List<OrderModel>> streamOrdersForWorker(String workerId);

  /// Fetch orders for an admin dashboard with optional filters.
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters});

  /// Submit a rating and an optional review for a completed order.
  Future<bool> submitRatingForOrder({required OrderModel order, required double serviceRating, double? workerRating, String? review});

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
        // Preserve the human-readable order number when present so downstream
        // systems (payments, bookings, admin tools) can display and reference it.
        if (order.orderNumber.isNotEmpty) 'orderNumber': order.orderNumber,
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
    // Keep orderNumber in the payload - do not remove it so the human-friendly
    // orderNumber is stored in Firestore documents.
    data['totalAmount'] = data['total'] ?? order.total;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final docRef = await userOrdersCol.add(data);
    try { await docRef.update({'remoteId': docRef.id}); } catch (_) {}
  }

  @override
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    // Use a document id without slashes for the counter (safe as a doc id),
    // and return the human-facing order number as YYYYMMDDxxxxx (no slashes) per requirement.
    final counterDocId = DateFormat('yyyyMMdd').format(now);
    final counterDocRef = _firestore.collection('order_counters').doc(counterDocId);
    final orderDateString = DateFormat('yyyyMMdd').format(now);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterDocRef);
        int newSeq = 1;
        if (snapshot.exists) {
          // Safely get the current sequence number, defaulting to 0 if null.
          newSeq = (snapshot.data()?['seq'] as int? ?? 0) + 1;
        }
        transaction.set(counterDocRef, {'seq': newSeq, 'updatedAt': FieldValue.serverTimestamp()});

        // The requirement: 5-digit suffix starting at 10000 for the first order of the day.
        // Map sequence 1 -> 10000, seq N -> (10000 + N - 1).
        final suffixNumber = (10000 + newSeq - 1);
        final suffix = suffixNumber.toString().padLeft(5, '0');
        // Produce order number concatenated: YYYYMMDDxxxxx
        final orderNumber = '$orderDateString$suffix';
        debugPrint('[OrderRepository] generateOrderNumber reserved seq=$newSeq orderNumber=$orderNumber');
        return orderNumber;
      });
    } on FirebaseException catch (e) {
      // If the client does not have permission to update the counter (common when
      // counters are protected server-side), fall back to a client-generated order
      // number using the date + a millisecond-based suffix so ordering is still
      // reasonably unique.
      debugPrint('[OrderRepository] generateOrderNumber transaction failed: ${e.message}');
      // Ensure the fallback suffix follows the same 5-digit format starting at 10000
      // (i.e. range 10000..99999). Use a millisecond-based value reduced into the
      // allowed range to reduce collisions while keeping the required format.
      final fallbackNumber = 10000 + (now.millisecondsSinceEpoch % 90000);
      final fallbackSuffix = fallbackNumber.toString().padLeft(5, '0');
      debugPrint('[OrderRepository] generateOrderNumber using fallback suffix: $fallbackSuffix');
      return '${DateFormat('yyyyMMdd').format(now)}$fallbackSuffix';
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber unexpected error: $e');
      final fallbackNumber = 10000 + (now.millisecondsSinceEpoch % 90000);
      final fallbackSuffix = fallbackNumber.toString().padLeft(5, '0');
      return '${DateFormat('yyyyMMdd').format(now)}$fallbackSuffix';
    }
  }

  @override
  Future<String> uploadOrder(OrderModel localOrder) async {
    final userId = localOrder.userId;
    if (userId.isEmpty) throw Exception('Missing userId on order');

    // Prepare a clean payload, removing fields managed by the server/backend.
    final cleanedData = localOrder.toFirestore();
    // Keep orderNumber so the human-readable id is stored with the document.
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
      // Keep orderNumber so updates don't strip the human-readable number from docs.
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
      // 1) Preferred: Read from the per-worker mirror which is allowed by security rules for workers.
      final workerCol = _firestore.collection('workers').doc(workerId).collection('orders');
      try {
        final snap = await workerCol.orderBy('scheduledAt', descending: false).get();
        if (snap.docs.isNotEmpty) {
          debugPrint('[OrderRepository] fetched ${snap.docs.length} orders from workers/{workerId}/orders for worker=$workerId');
          return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        } else {
          debugPrint('[OrderRepository] workers/{workerId}/orders returned 0 docs for worker=$workerId');
        }
      } catch (e) {
        debugPrint('[OrderRepository] workers/{workerId}/orders read failed (may be fine if mirror not configured): $e');
      }

      // 2) Fallback: Query all `orders` documents (including those under users/{uid}/orders)
      // using a collectionGroup query to find orders where `workerId` matches.
      try {
        final cgQuery = _firestore.collectionGroup('orders').where('workerId', isEqualTo: workerId).orderBy('scheduledAt', descending: false);
        final snap = await cgQuery.get();
        if (snap.docs.isNotEmpty) {
          debugPrint('[OrderRepository] fetched ${snap.docs.length} orders from collectionGroup(users/*/orders) for worker=$workerId');
          // Map and return distinct orders by remoteId/doc id
          final mapped = snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
          return mapped;
        }
      } catch (e) {
        debugPrint('[OrderRepository] collectionGroup("orders") query for worker failed or is disallowed by rules: $e');
      }

      // 3) Final fallback: top-level `orders` collection where workerId == workerId
      try {
        final topSnap = await _firestore.collection('orders').where('workerId', isEqualTo: workerId).orderBy('scheduledAt', descending: false).get();
        if (topSnap.docs.isNotEmpty) {
          debugPrint('[OrderRepository] fetched ${topSnap.docs.length} orders from top-level orders for worker=$workerId');
          return topSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        }
      } catch (e) {
        debugPrint('[OrderRepository] top-level orders query for worker failed: $e');
      }

      // Nothing found
      return [];
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrdersForWorker failed: $e');
      return [];
    }
  }

  @override
  Stream<List<OrderModel>> streamOrdersForWorker(String workerId) async* {
    // 1) Prefer per-worker mirror stream
    try {
      final workerCol = _firestore.collection('workers').doc(workerId).collection('orders').orderBy('scheduledAt', descending: false);
      yield* workerCol.snapshots().map((snap) => snap.docs.map((d) => OrderModel.fromFirestore(d)).toList());
      return;
    } catch (e) {
      debugPrint('[OrderRepository] workers/{workerId}/orders stream failed: $e');
    }

    // 2) Fallback: collectionGroup stream
    try {
      final cgQuery = _firestore.collectionGroup('orders').where('workerId', isEqualTo: workerId).orderBy('scheduledAt', descending: false);
      yield* cgQuery.snapshots().map((snap) => snap.docs.map((d) => OrderModel.fromFirestore(d)).toList());
      return;
    } catch (e) {
      debugPrint('[OrderRepository] collectionGroup("orders") stream for worker failed: $e');
    }

    // 3) Final fallback: top-level orders collection stream
    try {
      final topRef = _firestore.collection('orders').where('workerId', isEqualTo: workerId).orderBy('scheduledAt', descending: false);
      yield* topRef.snapshots().map((snap) => snap.docs.map((d) => OrderModel.fromFirestore(d)).toList());
      return;
    } catch (e) {
      debugPrint('[OrderRepository] top-level orders stream for worker failed: $e');
    }

    // If all fail, yield empty stream
    yield [];
  }

  @override
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters}) async {
    try {
      // Admins should be able to read all orders. Prefer a collectionGroup
      // query over users/{uid}/orders so we can fetch orders that live under
      // each user's subcollection. If collectionGroup access is denied by
      // rules, fall back to top-level `orders` collection.
      final int limit = filters?['limit'] as int? ?? 500;

      // Helper to build query on a collection reference
      Query buildQueryOnCollection(CollectionReference col) {
        Query q = col as Query;
        if (filters != null) {
          if (filters['status'] != null) q = q.where('status', isEqualTo: filters['status']);
          if (filters['orderOwner'] != null) q = q.where('orderOwner', isEqualTo: filters['orderOwner']);
          if (filters['workerId'] != null) q = q.where('workerId', isEqualTo: filters['workerId']);
          if (filters['dateFrom'] != null) q = q.where('createdAt', isGreaterThanOrEqualTo: filters['dateFrom']);
          if (filters['dateTo'] != null) q = q.where('createdAt', isLessThanOrEqualTo: filters['dateTo']);
        }
        q = q.orderBy('createdAt', descending: true).limit(limit);
        return q;
      }

      // Try collectionGroup first (users/{uid}/orders)
      try {
        Query cgQuery = _firestore.collectionGroup('orders');
        if (filters != null) {
          if (filters['status'] != null) cgQuery = cgQuery.where('status', isEqualTo: filters['status']);
          if (filters['orderOwner'] != null) cgQuery = cgQuery.where('orderOwner', isEqualTo: filters['orderOwner']);
          if (filters['workerId'] != null) cgQuery = cgQuery.where('workerId', isEqualTo: filters['workerId']);
          if (filters['dateFrom'] != null) cgQuery = cgQuery.where('createdAt', isGreaterThanOrEqualTo: filters['dateFrom']);
          if (filters['dateTo'] != null) cgQuery = cgQuery.where('createdAt', isLessThanOrEqualTo: filters['dateTo']);
        }
        cgQuery = cgQuery.orderBy('createdAt', descending: true).limit(limit);
        final snap = await cgQuery.get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        }
      } catch (e) {
        debugPrint('[OrderRepository] collectionGroup("orders") failed or returned empty: $e');
      }

      // Fallback: try top-level `orders` collection
      try {
        Query colQuery = buildQueryOnCollection(_firestore.collection('orders'));
        final snap = await colQuery.get();
        return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      } catch (e) {
        debugPrint('[OrderRepository] fetchOrdersForAdmin top-level orders failed: $e');
        return [];
      }
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrdersForAdmin failed: $e');
      return [];
    }
  }

  /// Fetch a single order either from top-level `orders` or from users/{uid}/orders
  /// This will try the simplest lookup first and then fall back to searching
  /// across users using a collectionGroup query.
  Future<OrderModel?> fetchOrderById(String orderId) async {
    if (orderId.trim().isEmpty) return null;
    try {
      // Try top-level
      final topDoc = await _firestore.collection('orders').doc(orderId).get();
      if (topDoc.exists) return OrderModel.fromFirestore(topDoc);
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrderById top-level lookup failed: $e');
    }

    // Try collectionGroup: find the order in any users/{uid}/orders with remoteId or id match
    try {
      // collectionGroup cannot be queried by raw documentId using a short id value
      // (it expects a full path). Use the stored 'remoteId' field instead.
      final cgByRemote = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: orderId).limit(1).get();
      if (cgByRemote.docs.isNotEmpty) return OrderModel.fromFirestore(cgByRemote.docs.first);
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrderById collectionGroup lookup failed: $e');
    }

    return null;
  }

  /// Assign a worker to an order. Writes both top-level and user-subcollection
  /// documents where possible. This operation should be executed by admins or
  /// trusted backend services; client rules may prevent some writes.
  Future<void> assignWorkerToOrder({required String orderId, required String workerId, required String adminId}) async {
    if (orderId.trim().isEmpty) throw Exception('orderId required');
    try {
      final updateData = {
        'workerId': workerId,
        'assignedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update top-level if exists
      try {
        final topRef = _firestore.collection('orders').doc(orderId);
        final topDoc = await topRef.get();
        if (topDoc.exists) {
          await topRef.set(updateData, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[OrderRepository] assignWorkerToOrder top-level update failed: $e');
      }

      // Update any user subcollection document with matching remoteId or id
      try {
        // Prefer searching by remoteId field since collectionGroup documentId
        // filters expect a full path when used with collectionGroup queries.
        final cgByRemote = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: orderId).limit(1).get();
        if (cgByRemote.docs.isNotEmpty) {
          final docRef = cgByRemote.docs.first.reference;
          await docRef.set(updateData, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[OrderRepository] assignWorkerToOrder user-subcollection update failed: $e');
      }
    } catch (e) {
      debugPrint('[OrderRepository] assignWorkerToOrder failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> submitRatingForOrder({required OrderModel order, required double serviceRating, double? workerRating, String? review}) async {
    // Validate inputs
    if (order.id.isEmpty || order.userId.isEmpty) return false;

    // First try: call a trusted backend callable function 'submitRating' which performs
    // validation, creates rating docs and updates aggregates atomically.
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('submitRating');
      final payload = <String, dynamic>{
        'orderId': order.id,
        'orderNumber': order.orderNumber,
        'serviceRating': serviceRating,
        'workerRating': workerRating,
        'review': review ?? '',
      };
      final HttpsCallableResult result = await callable.call(payload);
      final data = result.data;
      if (data is Map && data['success'] == true) {
        debugPrint('[OrderRepository] submitRatingForOrder: submitRating callable succeeded');
        return true;
      }
      debugPrint('[OrderRepository] submitRatingForOrder: submitRating callable returned non-success: $data');
    } catch (e) {
      // Callable may not be deployed or callable failed; fall back to client-side writes.
      debugPrint('[OrderRepository] submitRatingForOrder: submitRating callable failed (falling back): $e');
    }

    // Fallback: perform client-side writes that conform to Firestore rules.
    try {
      // Prepare order update payload (merge-safe). We intentionally avoid touching
      // protected fields like workerId/status/orderNumber/paymentRef.
      final orderUpdate = <String, dynamic>{
        'serviceRating': serviceRating,
        'rating': serviceRating, // legacy compatibility
        'rated': true,
        'ratingAt': FieldValue.serverTimestamp(),
      };
      if (workerRating != null) {
        orderUpdate['workerRating'] = workerRating;
      }

      final batch = _firestore.batch();

      // 1) Update user's order doc (users/{userId}/orders/{order.id}) if it exists or create-merge.
      try {
        final userOrderRef = _firestore.collection('users').doc(order.userId).collection('orders').doc(order.id);
        batch.set(userOrderRef, orderUpdate, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[OrderRepository] submitRatingForOrder: failed to prepare user subcollection update: $e');
      }

      // 2) Update top-level orders/{order.id} (merge). This will be denied on some setups
      // for non-admins but we attempt it; failures will surface at commit time.
      try {
        final topRef = _firestore.collection('orders').doc(order.id);
        batch.set(topRef, orderUpdate, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[OrderRepository] submitRatingForOrder: failed to prepare top-level order update: $e');
      }

      // 3) Also attempt to update any users/*/orders doc that stores this order under `remoteId`.
      try {
        final cg = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: order.id).get();
        for (final d in cg.docs) {
          batch.set(d.reference, orderUpdate, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[OrderRepository] submitRatingForOrder: collectionGroup lookup for remoteId failed (non-fatal): $e');
      }

      // 4) Create service rating documents for each unique service in the order.
      final uniqueServiceIds = order.items.map((i) => i.serviceId).toSet();
      for (final sid in uniqueServiceIds) {
        try {
          final svcRatingCol = _firestore.collection('services').doc(sid).collection('ratings');
          final rdoc = svcRatingCol.doc();
          final rdata = <String, dynamic>{
            'serviceId': sid,
            'orderId': order.id,
            'orderNumber': order.orderNumber,
            'userId': order.userId,
            'rating': serviceRating,
            'review': review ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'remoteId': rdoc.id,
          };
          batch.set(rdoc, rdata);
        } catch (e) {
          debugPrint('[OrderRepository] submitRatingForOrder: failed to prepare service rating for service=$sid: $e');
        }
      }

      // 5) Create worker rating document if worker exists and workerRating provided.
      if (order.workerId != null && order.workerId!.isNotEmpty && workerRating != null) {
        try {
          final wcol = _firestore.collection('workers').doc(order.workerId).collection('ratings');
          final wdoc = wcol.doc();
          final wdata = <String, dynamic>{
            'workerId': order.workerId,
            'orderId': order.id,
            'orderNumber': order.orderNumber,
            'userId': order.userId,
            'rating': workerRating,
            'review': review ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'remoteId': wdoc.id,
          };
          batch.set(wdoc, wdata);
        } catch (e) {
          debugPrint('[OrderRepository] submitRatingForOrder: failed to prepare worker rating: $e');
        }
      }

      // Commit batch (may fail partially if rules block some writes). We let Firestore
      // throw which we catch below and surface as a boolean false result.
      await batch.commit();

      // 6) Best-effort: attempt to update aggregate counters on service and worker docs.
      // These may be restricted by rules; ignore failures but log them.
      for (final sid in uniqueServiceIds) {
        try {
          final svcDocRef = _firestore.collection('services').doc(sid);
          await svcDocRef.set({
            'ratingCount': FieldValue.increment(1),
            'ratingSum': FieldValue.increment(serviceRating),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[OrderRepository] submitRatingForOrder: failed to update service aggregate for service=$sid: $e');
        }
      }

      if (order.workerId != null && order.workerId!.isNotEmpty && workerRating != null) {
        try {
          final wRef = _firestore.collection('workers').doc(order.workerId);
          await wRef.set({
            'ratingCount': FieldValue.increment(1),
            'ratingSum': FieldValue.increment(workerRating),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[OrderRepository] submitRatingForOrder: failed to update worker aggregate: $e');
        }
      }

      debugPrint('[OrderRepository] submitRatingForOrder: fallback client-side writes committed');
      return true;
    } catch (e) {
      debugPrint('[OrderRepository] submitRatingForOrder: fallback failed: $e');
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
