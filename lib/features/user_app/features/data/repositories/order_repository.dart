import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    // Pre-fetch name/phone snapshots to embed in order documents
    final userInfo = await _fetchUserNamePhone(order.userId);
    Map<String, String?> workerInfo = const {'name': null, 'phone': null};
    if (order.workerId != null && order.workerId!.isNotEmpty) {
      workerInfo = await _fetchWorkerNamePhone(order.workerId!);
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
        'userName': order.userName ?? userInfo['name'],
        'userPhone': order.userPhone ?? userInfo['phone'],
        'workerId': order.workerId,
        if (order.workerId != null && order.workerId!.isNotEmpty) ...{
          'workerName': order.workerName ?? workerInfo['name'],
          'workerPhone': order.workerPhone ?? workerInfo['phone'],
        },
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
    // Embed name/phone snapshots if missing
    data['userName'] ??= userInfo['name'];
    data['userPhone'] ??= userInfo['phone'];
    if ((order.workerId ?? '').isNotEmpty) {
      data['workerName'] ??= workerInfo['name'];
      data['workerPhone'] ??= workerInfo['phone'];
    }
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

    // Enrich with name/phone snapshots if missing
    try {
      if (cleanedData['userName'] == null || cleanedData['userPhone'] == null) {
        final u = await _fetchUserNamePhone(userId);
        cleanedData['userName'] ??= u['name'];
        cleanedData['userPhone'] ??= u['phone'];
      }
      final wid = localOrder.workerId;
      if (wid != null && wid.isNotEmpty && (cleanedData['workerName'] == null || cleanedData['workerPhone'] == null)) {
        final w = await _fetchWorkerNamePhone(wid);
        cleanedData['workerName'] ??= w['name'];
        cleanedData['workerPhone'] ??= w['phone'];
      }
    } catch (e) {
      debugPrint('[OrderRepository] uploadOrder enrichment failed: $e');
    }

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

      // Enrich with name/phone snapshots if missing
      try {
        if (cleanedData['userName'] == null || cleanedData['userPhone'] == null) {
          final u = await _fetchUserNamePhone(order.userId);
          cleanedData['userName'] ??= u['name'];
          cleanedData['userPhone'] ??= u['phone'];
        }
        final wid = order.workerId;
        if (wid != null && wid.isNotEmpty && (cleanedData['workerName'] == null || cleanedData['workerPhone'] == null)) {
          final w = await _fetchWorkerNamePhone(wid);
          cleanedData['workerName'] ??= w['name'];
          cleanedData['workerPhone'] ??= w['phone'];
        }
      } catch (e) {
        debugPrint('[OrderRepository] updateOrder enrichment failed: $e');
      }

      await ref.set(cleanedData, SetOptions(merge: true));

      // Also attempt to update the mirror in the user's subcollection so the
      // client's reads remain consistent even if top-level reads are restricted.
      try {
        final userDoc = _firestore.collection('users').doc(order.userId).collection('orders').doc(order.id);
        await userDoc.set(cleanedData, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[OrderRepository] Failed to update mirrored user order doc: $e');
      }

      // Also update the worker's mirror if assigned
      if (order.workerId != null && order.workerId!.isNotEmpty) {
        try {
          final workerDoc = _firestore.collection('workers').doc(order.workerId!).collection('orders').doc(order.id);
          await workerDoc.set(cleanedData, SetOptions(merge: true));
        } catch (e) {
          debugPrint('[OrderRepository] Failed to update mirrored worker order doc: $e');
        }
      }
    } catch (e) {
      debugPrint('[OrderRepository] updateOrder failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<OrderModel>> fetchOrdersForUser(String userId) async {
    List<OrderModel> orders = [];
    // 1. First, attempt to fetch from the user's private subcollection.
    try {
      final userOrdersSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();
      if (userOrdersSnap.docs.isNotEmpty) {
        debugPrint('[OrderRepository] fetched ${userOrdersSnap.docs.length} orders from users/{uid}/orders for user=$userId');
        orders = userOrdersSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      } else {
        debugPrint('[OrderRepository] users/{uid}/orders returned 0 docs for user=$userId');
      }
    } catch (e) {
      debugPrint('[OrderRepository] Failed to fetch from users/{uid}/orders: $e');
      rethrow;
    }

    // 2. If the subcollection is empty or fails, query the top-level collection.
    if (orders.isEmpty) {
      try {
        final snapshot = await _firestore
            .collection('orders')
            .where('orderOwner', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        debugPrint('[OrderRepository] fetched ${snapshot.docs.length} orders from top-level orders for user=$userId');
        orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      } catch (e) {
        final errString = e.toString();
        if (errString.contains('permission-denied') || errString.contains('PERMISSION_DENIED')) {
          debugPrint('[OrderRepository] PERMISSION_DENIED on top-level fetch for user=$userId');
          throw Exception('Permission denied reading top-level orders. Ensure Firestore rules allow reads on orders when filtering by orderOwner or use users/{uid}/orders for user reads.');
        } else {
          debugPrint('[OrderRepository] Top-level fetchOrdersForUser failed for user=$userId: $e');
        }
      }
    }

    // Enrich names/phones for legacy docs missing snapshots
    if (orders.isNotEmpty) {
      orders = await _populateOrderDetailsForOrders(orders);
    }
    return orders;
  }

  @override
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId) async {
    List<OrderModel> orders = [];
    try {
      // 1) Preferred: per-worker mirror
      final workerCol = _firestore.collection('workers').doc(workerId).collection('orders');
      try {
        final snap = await workerCol.orderBy('scheduledAt', descending: false).get();
        if (snap.docs.isNotEmpty) {
          debugPrint('[OrderRepository] fetched ${snap.docs.length} orders from workers/{workerId}/orders for worker=$workerId');
          orders = snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        } else {
          debugPrint('[OrderRepository] workers/{workerId}/orders returned 0 docs for worker=$workerId');
        }
      } catch (e) {
        debugPrint('[OrderRepository] workers/{workerId}/orders read failed (may be fine if mirror not configured): $e');
      }

      // 2) Fallback: collectionGroup
      if (orders.isEmpty) {
        try {
          final cgQuery = _firestore
              .collectionGroup('orders')
              .where('workerId', isEqualTo: workerId)
              .orderBy('scheduledAt', descending: false);
          final snap = await cgQuery.get();
          if (snap.docs.isNotEmpty) {
            debugPrint('[OrderRepository] fetched ${snap.docs.length} orders from collectionGroup(users/*/orders) for worker=$workerId');
            orders = snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
          }
        } catch (e) {
          debugPrint('[OrderRepository] collectionGroup("orders") query for worker failed or is disallowed by rules: $e');
        }
      }

      // 3) Final fallback: top-level
      if (orders.isEmpty) {
        try {
          final topSnap = await _firestore
              .collection('orders')
              .where('workerId', isEqualTo: workerId)
              .orderBy('scheduledAt', descending: false)
              .get();
          if (topSnap.docs.isNotEmpty) {
            debugPrint('[OrderRepository] fetched ${topSnap.docs.length} orders from top-level orders for worker=$workerId');
            orders = topSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
          }
        } catch (e) {
          debugPrint('[OrderRepository] top-level orders query for worker failed: $e');
        }
      }

      if (orders.isNotEmpty) {
        orders = await _populateOrderDetailsForOrders(orders);
      }

      return orders;
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

    // Ensure we have an authenticated user before attempting client-side writes.
    final currentUser = FirebaseAuth.instance.currentUser;

    // Try trusted backend callable first even if unauthenticated (it will fail if not allowed)
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
      debugPrint('[OrderRepository] submitRatingForOrder: submitRating callable failed (falling back): $e');
    }

    // If there's no authenticated user, do not attempt client-side writes — rules require auth and userId==auth.uid.
    if (currentUser == null) {
      debugPrint('[OrderRepository] submitRatingForOrder: no authenticated user available for fallback writes; aborting');
      return false;
    }

    // Fallback: perform client-side writes that conform to Firestore rules.
    bool anySucceeded = false; // moved here so scope covers the final checks
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

      // 1) Update user's order doc under the authenticated user's subcollection.
      final effectiveUserId = currentUser.uid;
      final userOrderRef = _firestore.collection('users').doc(effectiveUserId).collection('orders').doc(order.id);
      try {
        final userOrderSnap = await userOrderRef.get();
        if (userOrderSnap.exists) {
          try {
            await userOrderRef.set(orderUpdate, SetOptions(merge: true));
            anySucceeded = true;
            debugPrint('[OrderRepository] submitRatingForOrder: updated user subcollection order doc');
          } catch (e) {
            debugPrint('[OrderRepository] submitRatingForOrder: permission denied updating user order doc: $e');
          }
        } else {
          debugPrint('[OrderRepository] submitRatingForOrder: user subcollection order doc does not exist, skipping update');
        }
      } catch (e) {
        debugPrint('[OrderRepository] submitRatingForOrder: checking user subcollection doc failed (skipping): $e');
      }

      // 2) Create service rating documents for each unique service in the order.
      final uniqueServiceIds = order.items.map((i) => i.serviceId).toSet();
      for (final sid in uniqueServiceIds) {
        try {
          final svcRatingCol = _firestore.collection('services').doc(sid).collection('ratings');

          // Try to find existing rating by this user for this order
          DocumentReference? docRef;
          try {
            final existing = await svcRatingCol
                .where('userId', isEqualTo: currentUser.uid)
                .where('orderId', isEqualTo: order.id)
                .limit(1)
                .get();
            if (existing.docs.isNotEmpty) {
              docRef = existing.docs.first.reference;
              await docRef.update({
                'rating': serviceRating,
                'review': review ?? '',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              debugPrint('[OrderRepository] submitRatingForOrder: updated existing service rating for $sid');
            }
          } catch (e) {
            debugPrint('[OrderRepository] submitRatingForOrder: checking existing service rating failed: $e');
          }

          if (docRef == null) {
            // create new
            final rdoc = svcRatingCol.doc();
            final rdata = <String, dynamic>{
              'serviceId': sid,
              'orderId': order.id,
              'orderNumber': order.orderNumber,
              'userId': currentUser.uid,
              'rating': serviceRating,
              'review': review ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'remoteId': rdoc.id,
            };
            await rdoc.set(rdata);
            docRef = rdoc;
            debugPrint('[OrderRepository] submitRatingForOrder: created new service rating for $sid');
          }

          // Also attempt to store/update the rating inside the parent service document
          // under a nested map `ratings.<ratingId> = { userId, rating, review, createdAt }`.
          try {
            final embedded = <String, dynamic>{
              'userId': currentUser.uid,
              'rating': serviceRating,
              'review': review ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'remoteId': docRef.id,
            };
            final serviceDocRef = _firestore.collection('services').doc(sid);
            await serviceDocRef.update({'ratings.${docRef.id}': embedded});
          } catch (e) {
            debugPrint('[OrderRepository] submitRatingForOrder: failed to add embedded rating to service doc (may be restricted by rules): $e');
          }
          anySucceeded = true;
        } catch (e) {
          debugPrint('[OrderRepository] submitRatingForOrder: failed to write service rating for $sid: $e');
        }
      }

      // 3) Create worker rating document if worker exists and workerRating provided.
      if (order.workerId != null && order.workerId!.isNotEmpty && workerRating != null) {
        try {
          final wcol = _firestore.collection('workers').doc(order.workerId).collection('ratings');

          // Try to find existing worker rating by user+order
          DocumentReference? wdocRef;
          try {
            final existing = await wcol
                .where('userId', isEqualTo: currentUser.uid)
                .where('orderId', isEqualTo: order.id)
                .limit(1)
                .get();
            if (existing.docs.isNotEmpty) {
              wdocRef = existing.docs.first.reference;
              await wdocRef.update({
                'rating': workerRating,
                'review': review ?? '',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              debugPrint('[OrderRepository] submitRatingForOrder: updated existing worker rating for ${order.workerId}');
            }
          } catch (e) {
            debugPrint('[OrderRepository] submitRatingForOrder: checking existing worker rating failed: $e');
          }

          if (wdocRef == null) {
            final wdoc = wcol.doc();
            final wdata = <String, dynamic>{
              'workerId': order.workerId,
              'orderId': order.id,
              'orderNumber': order.orderNumber,
              'userId': currentUser.uid,
              'rating': workerRating,
              'review': review ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'remoteId': wdoc.id,
            };
            await wdoc.set(wdata);
            wdocRef = wdoc;
            debugPrint('[OrderRepository] submitRatingForOrder: created new worker rating for ${order.workerId}');
          }

          // Also try to add/update embedded rating into the worker's top-level document
          try {
            final embedded = <String, dynamic>{
              'userId': currentUser.uid,
              'rating': workerRating,
              'review': review ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'remoteId': wdocRef.id,
            };
            final workerDocRef = _firestore.collection('workers').doc(order.workerId);
            await workerDocRef.update({'ratings.${wdocRef.id}': embedded});
          } catch (e) {
            debugPrint('[OrderRepository] submitRatingForOrder: failed to add embedded rating to worker doc (may be restricted by rules): $e');
          }
          anySucceeded = true;
        } catch (e) {
          debugPrint('[OrderRepository] submitRatingForOrder: failed to write worker rating: $e');
        }
      }

    } catch (e) {
      debugPrint('[OrderRepository] submitRatingForOrder: fallback failed: $e');
      return false;
    }

    if (anySucceeded) {
      debugPrint('[OrderRepository] submitRatingForOrder: some writes succeeded in fallback path');
      return true;
    } else {
      debugPrint('[OrderRepository] submitRatingForOrder: no fallback writes succeeded');
      return false;
    }
  }

  @override
  Future<void> dedupeRemoteOrdersForUser({required String userId, required String orderNumber}) async {
    // Best-effort client-side dedupe: find all orders with the same orderNumber
    // for the specified user and delete duplicates, keeping the earliest createdAt.
    if (userId.trim().isEmpty || orderNumber.trim().isEmpty) return;
    try {
      // Search the user's orders subcollection first
      final userOrdersCol = _firestore.collection('users').doc(userId).collection('orders');
      final snap = await userOrdersCol.where('orderNumber', isEqualTo: orderNumber).get();
      if (snap.docs.length <= 1) {
        // nothing to dedupe
        return;
      }

      // Sort by createdAt ascending (earliest first) and keep the first
      final docs = List.of(snap.docs);
      docs.sort((a, b) {
        final aTs = a.data()['createdAt'] as Timestamp?;
        final bTs = b.data()['createdAt'] as Timestamp?;
        final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
        final bMillis = bTs?.millisecondsSinceEpoch ?? 0;
        return aMillis.compareTo(bMillis);
      });

      // Keep first, delete the rest
      for (var i = 1; i < docs.length; i++) {
        try {
          await docs[i].reference.delete();
        } catch (e) {
          debugPrint('[OrderRepository] dedupeRemoteOrdersForUser: failed to delete duplicate doc ${docs[i].id}: $e');
        }
      }

      // Also attempt to remove duplicates from top-level orders collection (if present)
      try {
        final topSnap = await _firestore.collection('orders').where('orderNumber', isEqualTo: orderNumber).where('orderOwner', isEqualTo: userId).get();
        if (topSnap.docs.length > 1) {
          final topDocs = List.of(topSnap.docs);
          topDocs.sort((a, b) {
            final aTs = a.data()['createdAt'] as Timestamp?;
            final bTs = b.data()['createdAt'] as Timestamp?;
            final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
            final bMillis = bTs?.millisecondsSinceEpoch ?? 0;
            return aMillis.compareTo(bMillis);
          });
          for (var i = 1; i < topDocs.length; i++) {
            try {
              await topDocs[i].reference.delete();
            } catch (e) {
              debugPrint('[OrderRepository] dedupeRemoteOrdersForUser: failed to delete top-level duplicate ${topDocs[i].id}: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('[OrderRepository] dedupeRemoteOrdersForUser: top-level dedupe attempt failed: $e');
      }
    } catch (e) {
      debugPrint('[OrderRepository] dedupeRemoteOrdersForUser failed: $e');
    }
  }

  /// Fetch name/phone for a user from users collection.
  Future<Map<String, String?>> _fetchUserNamePhone(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        return {
          'name': data['name'] as String?,
          'phone': data['phoneNumber'] as String? ?? data['phone'] as String?,
        };
      }
    } catch (e) {
      debugPrint('[OrderRepository] _fetchUserNamePhone failed for $uid: $e');
    }
    return {'name': null, 'phone': null};
  }

  /// Fetch name/phone for a worker, trying workers/ then users/ as fallback.
  Future<Map<String, String?>> _fetchWorkerNamePhone(String uid) async {
    try {
      var doc = await _firestore.collection('workers').doc(uid).get();
      if (!doc.exists) {
        doc = await _firestore.collection('users').doc(uid).get();
      }
      if (doc.exists) {
        final data = doc.data() ?? {};
        return {
          'name': data['name'] as String? ?? data['workerName'] as String?,
          'phone': data['phoneNumber'] as String? ?? data['phone'] as String?,
        };
      }
    } catch (e) {
      debugPrint('[OrderRepository] _fetchWorkerNamePhone failed for $uid: $e');
    }
    return {'name': null, 'phone': null};
  }

  /// Populate user and worker name/phone across a batch of orders.
  Future<List<OrderModel>> _populateOrderDetailsForOrders(List<OrderModel> orders) async {
    if (orders.isEmpty) return orders;

    // Collect ids
    final userIds = orders.map((o) => o.userId).where((id) => id.isNotEmpty).toSet();
    final workerIds = orders.map((o) => o.workerId ?? '').where((id) => id.isNotEmpty).toSet();

    // Fetch users in parallel
    final Map<String, Map<String, String?>> usersMap = {};
    await Future.wait(userIds.map((uid) async {
      usersMap[uid] = await _fetchUserNamePhone(uid);
    }));

    // Fetch workers in parallel
    final Map<String, Map<String, String?>> workersMap = {};
    await Future.wait(workerIds.map((wid) async {
      workersMap[wid] = await _fetchWorkerNamePhone(wid);
    }));

    // Apply
    return orders.map((o) {
      final u = usersMap[o.userId];
      final w = (o.workerId != null && o.workerId!.isNotEmpty) ? workersMap[o.workerId!] : null;
      return o.copyWith(
        userName: u?['name'],
        userPhone: u?['phone'],
        workerName: w?['name'],
        workerPhone: w?['phone'],
      );
    }).toList();
  }
} // end class OrderRepositoryImpl

// End of file
