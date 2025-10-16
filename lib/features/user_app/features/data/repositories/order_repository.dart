// File: lib/features/user_app/data/repositories/order_repository.dart
// Firestore-first OrderRepository
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agapecares/core/models/order_model.dart';

class OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> init() async {}

  /// Generate a daily order number in the format YYYYMMDD + 5-digit suffix (e.g. 2025101200100)
  /// The suffix starts at 00100 for the first order of the day and increments.
  /// Strategy: try a Firestore counter document; fallback to querying the top-level 'orders' collection.
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
          if (data != null && data['seq'] is int) current = data['seq'] as int;
          else if (data != null && data['seq'] is String) current = int.tryParse(data['seq'] as String) ?? 0;
        }
        final next = current + 1;
        tx.set(counterRef, {'seq': next, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        return next;
      });

      // Map seq to suffix where seq==1 => suffix 00100 baseline
      final suffix = (seq + 99).toString().padLeft(5, '0');
      return '$prefix$suffix';
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber failed, falling back: $e');
    }

    // Fallback: query top-level 'orders' collection for today's max
    try {
      final start = prefix;
      final end = '$prefix\uf8ff';
      final q = _firestore.collection('orders').where('orderNumber', isGreaterThanOrEqualTo: start).where('orderNumber', isLessThanOrEqualTo: end).orderBy('orderNumber', descending: true).limit(1);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        final last = snap.docs.first.data()['orderNumber'] as String? ?? '';
        if (last.length >= prefix.length + 1) {
          final suffixStr = last.substring(prefix.length);
          final prev = int.tryParse(suffixStr) ?? 100;
          final next = prev + 1;
          final suffix = next.toString().padLeft(5, '0');
          return '$prefix$suffix';
        }
      }
    } catch (e) {
      debugPrint('[OrderRepository] generateOrderNumber collection fallback failed: $e');
    }

    return '${prefix}00100';
  }

  /// Create order in Firestore under top-level `orders` collection. Returns the created OrderModel (with remote id and timestamps).
  Future<OrderModel> createOrder(OrderModel order, {required String userId}) async {
    try {
      // Persist a minimal top-level order document. Include orderOwner for rules and admin queries.
      final ordersCol = _firestore.collection('orders');
      final data = <String, dynamic>{
        'orderOwner': userId,
        'userId': order.userId,
        'items': order.items.map((i) => i.toMap()).toList(),
        'addressSnapshot': order.addressSnapshot,
        'subtotal': order.subtotal,
        'discount': order.discount,
        'tax': order.tax,
        'totalAmount': order.total,
        // keep both 'orderStatus' and 'status' fields for compatibility with rules
        'orderStatus': order.orderStatus.name,
        'status': order.orderStatus.name,
        'paymentStatus': order.paymentStatus.name,
        'scheduledAt': order.scheduledAt,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final doc = await ordersCol.add(data);
      try { await doc.update({'remoteId': doc.id}); } catch (_) {}

      // Return an OrderModel built from what we know; remote fields will be populated by the backend if needed.
      return OrderModel(
        id: doc.id,
        orderNumber: order.orderNumber,
        userId: userId,
        workerId: order.workerId,
        items: order.items,
        addressSnapshot: order.addressSnapshot,
        subtotal: order.subtotal,
        discount: order.discount,
        tax: order.tax,
        total: order.total,
        orderStatus: order.orderStatus,
        paymentStatus: order.paymentStatus,
        scheduledAt: order.scheduledAt,
        createdAt: Timestamp.now(),
        updatedAt: order.updatedAt,
      );
    } catch (e) {
      debugPrint('[OrderRepository] createOrder failed: $e');
      rethrow;
    }
  }

  /// UploadOrder - writes/merges under top-level `orders` collection.
  Future<String> uploadOrder({required OrderModel order}) async {
    try {
      final userId = order.userId;
      if (userId.isEmpty) throw Exception('Missing userId on order');
      final ordersCol = _firestore.collection('orders');
      if (order.id.isNotEmpty) {
        final ref = ordersCol.doc(order.id);
        await ref.set({...order.toFirestore(), 'orderOwner': userId, 'status': order.orderStatus.name}, SetOptions(merge: true));
        return ref.id;
      }
      final ref = ordersCol.doc();
      await ref.set({...order.toFirestore(), 'orderOwner': userId, 'status': order.orderStatus.name});
      try { await ref.update({'remoteId': ref.id}); } catch (_) {}
      return ref.id;
    } catch (e) {
      debugPrint('[OrderRepository] uploadOrder failed: $e');
      rethrow;
    }
  }

  /// Update the remote copy of an order (top-level)
  Future<void> updateOrder(OrderModel order) async {
    try {
      if (order.userId.isEmpty) return;
      final ref = _firestore.collection('orders').doc(order.id);
      await ref.set(order.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[OrderRepository] updateOrder failed: $e');
      rethrow;
    }
  }

  /// Get all orders for a user by querying the root 'orders' collection and filtering by orderOwner/userId.
  Future<List<OrderModel>> getAllOrdersForUser(String userId) async {
    try {
      final snap = await _firestore.collection('orders').where('orderOwner', isEqualTo: userId).orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[OrderRepository] getAllOrdersForUser failed: $e');
      rethrow;
    }
  }

  /// Submit rating and optional review for an order. Updates Firestore document
  /// and local DB row if found. Returns true on success.
  Future<bool> submitRatingForOrder({required OrderModel order, required double rating, String? review}) async {
    try {
      if (order.id.isNotEmpty && order.userId.isNotEmpty) {
        final ref = _firestore.collection('orders').doc(order.id);
        await ref.set({'rating': rating, 'review': review ?? ''}, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      debugPrint('[OrderRepository] submitRatingForOrder failed: $e');
      return false;
    }
  }

  /// Administrative helper: find duplicate remote orders and keep a single canonical document.
  Future<void> dedupeRemoteOrdersForUser({required String userId, required String orderNumber}) async {
    try {
      if (userId.trim().isEmpty || orderNumber.trim().isEmpty) return;
      final q = await _firestore.collection('orders').where('orderNumber', isEqualTo: orderNumber).where('orderOwner', isEqualTo: userId).get();
      final docs = q.docs;
      if (docs.length <= 1) return;
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aTs = aData['createdAt'] is Timestamp ? (aData['createdAt'] as Timestamp).toDate() : null;
        final bTs = bData['createdAt'] is Timestamp ? (bData['createdAt'] as Timestamp).toDate() : null;
        if (aTs != null && bTs != null) return aTs.compareTo(bTs);
        return a.id.compareTo(b.id);
      });
      final keep = docs.first;
      final toDelete = docs.skip(1);
      for (final d in toDelete) {
        try { await d.reference.delete(); } catch (e) { debugPrint('[OrderRepository] dedupe delete failed: $e'); }
      }
    } catch (e) {
      debugPrint('[OrderRepository] dedupeRemoteOrdersForUser failed: $e');
    }
  }

  /// Get all orders assigned to a worker
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId) async {
    try {
      final snap = await _firestore.collection('orders').where('workerId', isEqualTo: workerId).orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[OrderRepository] fetchOrdersForWorker failed: $e');
      return [];
    }
  }
}
