import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/models/order_model.dart';
import 'order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true, String? userId}) async {
    if (uploadRemote) {
      // If caller provided a userId, attempt to create a top-level order document
      // with an explicit owner (preferred). This aligns with the new Firestore rules
      // that allow clients to create top-level orders when they set orderOwner/userId.
      if (userId != null && userId.isNotEmpty) {
        final ordersCol = _firestore.collection('orders');
        // Build a client-safe map: do NOT include server-managed fields such as
        // 'orderNumber', 'createdAt', 'updatedAt'. Use 'totalAmount' key per rules.
        final data = <String, dynamic>{
          'orderOwner': userId,
          'userId': order.userId,
          'items': order.items.map((i) => i.toMap()).toList(),
          'addressSnapshot': order.addressSnapshot,
          'subtotal': order.subtotal,
          'discount': order.discount,
          'tax': order.tax,
          'totalAmount': order.total,
          'orderStatus': order.orderStatus.name,
          'status': order.orderStatus.name,
          'paymentStatus': order.paymentStatus.name,
          'scheduledAt': order.scheduledAt,
          // don't set createdAt/updatedAt/orderNumber here (server-managed)
        };
        final docRef = await ordersCol.add(data);
        try {
          // Setting remoteId in a subsequent update is a separate write and is allowed.
          await docRef.update({'remoteId': docRef.id});
        } catch (_) {}
        return;
      }

      // Fallback: create a per-user order document if userId not provided or empty
      final userOrdersCol = _firestore.collection('users').doc(order.userId).collection('orders');
      final data = <String, dynamic>{
        'userId': order.userId,
        'items': order.items.map((i) => i.toMap()).toList(),
        'addressSnapshot': order.addressSnapshot,
        'subtotal': order.subtotal,
        'discount': order.discount,
        'tax': order.tax,
        'totalAmount': order.total,
        'orderStatus': order.orderStatus.name,
        'paymentStatus': order.paymentStatus.name,
        'scheduledAt': order.scheduledAt,
        // Do not set 'orderNumber' or client timestamps; use server timestamp on backend
      };

      final docRef = await userOrdersCol.add(data);
      try {
        await docRef.update({'remoteId': docRef.id});
      } catch (_) {}
    }
    // TODO: Handle local storage
  }

  @override
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters}) {
    // TODO: implement fetchOrdersForAdmin
    throw UnimplementedError();
  }

  @override
  Future<List<OrderModel>> fetchOrdersForUser(String userId) async {
    // Prefer per-user subcollection first — this is the safest path for regular users
    // and avoids permission-denied when top-level `orders` is locked down for clients.
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    print('[OrderRepository] fetchOrdersForUser called for requested userId=$userId authUid=$authUid');

    // 1) Try per-user subcollection first (most likely to succeed for normal users)
    try {
      print('[OrderRepository] attempting users/{uid}/orders fetch for userId=$userId');
      final userOrdersSnap = await _firestore.collection('users').doc(userId).collection('orders').orderBy('createdAt', descending: true).get();
      final perUser = userOrdersSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      if (perUser.isNotEmpty) {
        print('[OrderRepository] fetchOrdersForUser returned ${perUser.length} orders from users/{uid}/orders for user=$userId');
        return perUser;
      }
    } catch (e) {
      // Log and continue to try top-level queries if per-user fetch fails
      print('[OrderRepository] users/{uid}/orders fetch failed for user=$userId, continuing to top-level: $e');
    }

    // 2) Try top-level orders queries (filter-only first), useful for admins and centralized datasets
    bool topLevelPermissionDenied = false;
    try {
      print('[OrderRepository] attempting top-level query with orderOwner=$userId (filter-only, no orderBy)');
      final snapshotFilterOnly = await _firestore
          .collection('orders')
          .where('orderOwner', isEqualTo: userId)
          .limit(100)
          .get();

      final listFilterOnly = snapshotFilterOnly.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      if (listFilterOnly.isNotEmpty) {
        print('[OrderRepository] fetchOrdersForUser got ${listFilterOnly.length} top-level (filter-only) orders for user=$userId');
        return listFilterOnly;
      }

      // If filter-only returned empty, try an ordered query
      print('[OrderRepository] top-level filter-only empty, trying ordered query with createdAt');
      final snapshotOrdered = await _firestore
          .collection('orders')
          .where('orderOwner', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      final listOrdered = snapshotOrdered.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      if (listOrdered.isNotEmpty) {
        print('[OrderRepository] fetchOrdersForUser got ${listOrdered.length} top-level (ordered) orders for user=$userId');
        return listOrdered;
      }

      // Try legacy userId field on top-level
      print('[OrderRepository] top-level empty, trying top-level query with userId field');
      final snapshotUserId = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();
      final listUserId = snapshotUserId.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      if (listUserId.isNotEmpty) {
        print('[OrderRepository] fetchOrdersForUser got ${listUserId.length} top-level (userId field) orders for user=$userId');
        return listUserId;
      }
    } catch (e) {
      final errString = e.toString();
      if (errString.contains('permission-denied') || errString.contains('PERMISSION_DENIED')) {
        topLevelPermissionDenied = true;
        print('[OrderRepository] top-level fetchOrdersForUser reported PERMISSION_DENIED for user=$userId');
      } else {
        print('[OrderRepository] top-level fetchOrdersForUser failed for user=$userId error=$e');
      }
    }

    // 3) Final attempt: try per-user subcollection again (in case top-level changed something), then decide
    try {
      print('[OrderRepository] final users/{uid}/orders fallback for userId=$userId');
      final userOrdersSnap2 = await _firestore.collection('users').doc(userId).collection('orders').orderBy('createdAt', descending: true).get();
      final finalPerUser = userOrdersSnap2.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      print('[OrderRepository] fetchOrdersForUser final fallback returned ${finalPerUser.length} orders for user=$userId');
      if (finalPerUser.isNotEmpty) return finalPerUser;
    } catch (e) {
      print('[OrderRepository] final per-user fallback failed for user=$userId error=$e');
    }

    // If nothing found and top-level queries were explicitly blocked, surface a permission error
    if (topLevelPermissionDenied) {
      throw FirebaseException(plugin: 'cloud_firestore', message: 'Permission denied reading top-level orders; please check Firestore rules and ensure client queries include orderOwner/userId filter or adjust rules to allow per-user reads.', code: 'permission-denied');
    }

    // Nothing available — return empty list
    return <OrderModel>[];
  }

  @override
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId) {
    // TODO: implement fetchOrdersForWorker
    throw UnimplementedError();
  }

  @override
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final datePrefix = DateFormat('yyyyMMdd').format(now);
    final counterDoc = _firestore.collection('order_counters').doc(datePrefix);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterDoc);

      int newSeq;
      if (!snapshot.exists) {
        newSeq = 1;
      } else {
        newSeq = (snapshot.data()!['seq'] ?? 0) + 1;
      }

      transaction.set(counterDoc, {'seq': newSeq, 'updatedAt': FieldValue.serverTimestamp()});

      final suffix = (newSeq + 99).toString().padLeft(5, '0');
      return '$datePrefix$suffix';
    });
  }

  @override
  Future<String> uploadOrder(OrderModel localOrder) async {
    // Upload a local order to the top-level orders collection using userId as owner when available
    final userId = localOrder.userId;
    if (userId.isEmpty) throw Exception('Missing userId on order');
    final ordersCol = _firestore.collection('orders');

    // Build a safe map for client-side creation/merge: avoid server-managed fields
    final base = <String, dynamic>{
      'orderOwner': userId,
      'userId': localOrder.userId,
      'items': localOrder.items.map((i) => i.toMap()).toList(),
      'addressSnapshot': localOrder.addressSnapshot,
      'subtotal': localOrder.subtotal,
      'discount': localOrder.discount,
      'tax': localOrder.tax,
      'totalAmount': localOrder.total,
      'orderStatus': localOrder.orderStatus.name,
      'status': localOrder.orderStatus.name,
      'paymentStatus': localOrder.paymentStatus.name,
      'scheduledAt': localOrder.scheduledAt,
    };

    print('[OrderRepository] uploadOrder userId=$userId id=${localOrder.id} total=${localOrder.total}');
    try {
      if (localOrder.id.isNotEmpty) {
        final ref = ordersCol.doc(localOrder.id);
        // Merge safe fields only
        // prefer using authenticated uid as orderOwner when available so rules match
        final authUid = FirebaseAuth.instance.currentUser?.uid;
        final mergedBase = {...base, 'orderOwner': authUid ?? userId};
        await ref.set(mergedBase, SetOptions(merge: true));
        return ref.id;
      }
      final ref = ordersCol.doc();
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final writeBase = {...base, 'orderOwner': authUid ?? userId};
      await ref.set(writeBase);
      try { await ref.update({'remoteId': ref.id}); } catch (_) {}
      return ref.id;
    } catch (e) {
      print('[OrderRepository] uploadOrder top-level write failed for user=${localOrder.userId} error=$e. Falling back to users/{uid}/orders.');
      try {
        final authUid2 = FirebaseAuth.instance.currentUser?.uid;
        final fallbackBase = {...base, 'orderOwner': authUid2 ?? localOrder.userId};
        final uref = await _firestore.collection('users').doc(localOrder.userId).collection('orders').add(fallbackBase);
        try { await uref.update({'remoteId': uref.id}); } catch (_) {}
        return uref.id;
      } catch (e2) {
        print('[OrderRepository] uploadOrder fallback also failed for user=${localOrder.userId} error=$e2');
        rethrow;
      }
    }
  }
}
