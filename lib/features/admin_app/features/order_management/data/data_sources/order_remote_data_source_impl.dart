import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'order_remote_data_source.dart';

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  // Keep a getter for convenience; we primarily read orders via collectionGroup
  CollectionReference<Map<String, dynamic>> get _topLevelOrders => _firestore.collection('orders');

  Query _applyFiltersToQuery(Query base, Map<String, dynamic>? filters) {
    if (filters == null) return base;
    var q = base;
    // status handled separately due to possible field-name differences ('status' vs 'orderStatus')
    if (filters['orderOwner'] != null) {
      q = q.where('orderOwner', isEqualTo: filters['orderOwner']);
    } else if (filters['userId'] != null) {
      q = q.where('userId', isEqualTo: filters['userId']);
    }
    if (filters['workerId'] != null) {
      q = q.where('workerId', isEqualTo: filters['workerId']);
    }
    if (filters['orderNumber'] != null) {
      q = q.where('orderNumber', isEqualTo: filters['orderNumber']);
    }
    if (filters['dateFrom'] != null) {
      final df = filters['dateFrom'];
      final ts = df is DateTime ? Timestamp.fromDate(df) : (df is Timestamp ? df : null);
      if (ts != null) q = q.where('createdAt', isGreaterThanOrEqualTo: ts);
    }
    if (filters['dateTo'] != null) {
      final dt = filters['dateTo'];
      final ts = dt is DateTime ? Timestamp.fromDate(dt) : (dt is Timestamp ? dt : null);
      if (ts != null) q = q.where('createdAt', isLessThanOrEqualTo: ts);
    }
    return q;
  }

  @override
  Future<List<OrderModel>> getAllOrders({Map<String, dynamic>? filters}) async {
    final limit = filters?['limit'] as int? ?? 100;
    try {
      // Prefer top-level collection (faster & indexable). If this fails due to
      // permissions, fall back to collectionGroup which searches subcollections.
      Query baseTop = _topLevelOrders;
      // If status filter present, we will attempt using 'status' first then 'orderStatus'.
      final statusFilter = filters?['status'] as String?;

      if (statusFilter != null) {
        // Try 'status' field first
        Query topQuery = _applyFiltersToQuery(baseTop, filters);
        topQuery = topQuery.where('status', isEqualTo: statusFilter).orderBy('createdAt', descending: true).limit(limit);
        final topSnap = await topQuery.get();
        if (topSnap.docs.isNotEmpty) return topSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();

        // Fallback try using 'orderStatus' field
        topQuery = _applyFiltersToQuery(baseTop, filters);
        topQuery = topQuery.where('orderStatus', isEqualTo: statusFilter).orderBy('createdAt', descending: true).limit(limit);
        final topSnap2 = await topQuery.get();
        if (topSnap2.docs.isNotEmpty) return topSnap2.docs.map((d) => OrderModel.fromFirestore(d)).toList();

      } else {
        Query topQuery = _applyFiltersToQuery(baseTop, filters);
        topQuery = topQuery.orderBy('createdAt', descending: true).limit(limit);
        final topSnap = await topQuery.get();
        if (topSnap.docs.isNotEmpty) {
          return topSnap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
        }
      }
    } on FirebaseException catch (e) {
      // If we hit a permission error on the top-level collection, we'll
      // fall through to try collectionGroup. For other errors, rethrow.
      if (e.code != 'permission-denied') {
        throw Exception('Failed to fetch top-level orders: ${e.message}');
      }
      // else fall through to collectionGroup fallback
    } catch (e) {
      // Non-Firebase exceptions: log and try the fallback as a best-effort.
      print('[OrderRemoteDataSource] top-level orders fetch failed: $e');
    }

    try {
      // Fallback: collectionGroup to read orders under users/{uid}/orders as well as any top-level orders
      Query baseCg = _firestore.collectionGroup('orders');
      final statusFilter = filters?['status'] as String?;
      if (statusFilter != null) {
        Query cg = _applyFiltersToQuery(baseCg, filters);
        cg = cg.where('status', isEqualTo: statusFilter).orderBy('createdAt', descending: true).limit(limit);
        final snap = await cg.get();
        if (snap.docs.isNotEmpty) return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();

        cg = _applyFiltersToQuery(baseCg, filters);
        cg = cg.where('orderStatus', isEqualTo: statusFilter).orderBy('createdAt', descending: true).limit(limit);
        final snap2 = await cg.get();
        if (snap2.docs.isNotEmpty) return snap2.docs.map((d) => OrderModel.fromFirestore(d)).toList();

        return <OrderModel>[]; // no matches found
      }

      Query cg = _applyFiltersToQuery(baseCg, filters);
      cg = cg.orderBy('createdAt', descending: true).limit(limit);
      final snap = await cg.get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || (e.message?.toLowerCase().contains('permission') == true)) {
        throw Exception('Firestore permission denied when fetching orders. Check Firestore rules and ensure your account has admin access. (${e.message})');
      }
      throw Exception('Failed to fetch orders: ${e.message}');
    }
  }

  // Helper: find the first DocumentReference for an order by a stored 'remoteId' or by id match.
  Future<DocumentReference<Map<String, dynamic>>?> _findOrderDocRefById(String orderId) async {
    if (orderId.isEmpty) return null;
    // First try to find a document whose 'remoteId' equals orderId (this is set when orders are created)
    final q1 = await _firestore.collectionGroup('orders').where('remoteId', isEqualTo: orderId).limit(1).get();
    if (q1.docs.isNotEmpty) return q1.docs.first.reference;

    // Fallback: try to match documents whose document id equals orderId by scanning collectionGroup
    // Note: direct filtering by documentId in collectionGroup may not be supported in all environments; do a simple scan as last resort
    final q2 = await _firestore.collectionGroup('orders').where('orderNumber', isEqualTo: orderId).limit(1).get();
    if (q2.docs.isNotEmpty) return q2.docs.first.reference;

    // As a last fallback, try to get from top-level orders collection
    final topDoc = await _topLevelOrders.doc(orderId).get();
    if (topDoc.exists) return topDoc.reference;

    return null;
  }

  @override
  Future<void> updateOrderStatus({required String orderId, required String status}) async {
    try {
      final ref = await _findOrderDocRefById(orderId);
      if (ref == null) throw Exception('Order not found: $orderId');
      await ref.update({
        'orderStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied updating order. Are your Firestore rules allowing admins to update orders?');
      }
      rethrow;
    }
  }

  @override
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName, Timestamp? scheduledAt}) async {
    try {
      final ref = await _findOrderDocRefById(orderId);
      if (ref == null) throw Exception('Order not found: $orderId');

      String? appointmentId;
      String? userId;
      try {
        final parts = ref.path.split('/');
        final idx = parts.indexOf('users');
        if (idx != -1 && idx + 1 < parts.length) userId = parts[idx + 1];
      } catch (_) {}

      if (scheduledAt != null) {
        try {
          final apptRef = await _firestore.collection('appointments').add({
            'orderId': orderId,
            'userId': userId,
            'workerId': workerId,
            'scheduledAt': scheduledAt,
            'status': 'scheduled',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          appointmentId = apptRef.id;
        } catch (_) {
          // ignore appointment creation failure; continue with assignment
        }
      }

      final update = <String, dynamic>{
        'workerId': workerId,
        if (workerName != null) 'workerName': workerName,
        'orderStatus': 'assigned',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (scheduledAt != null) 'scheduledAt': scheduledAt,
      }..removeWhere((k, v) => v == null);

      await ref.update(update);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied assigning worker. Check Firestore rules.');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    try {
      final ref = await _findOrderDocRefById(orderId);
      if (ref == null) throw Exception('Order not found: $orderId');
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied deleting order. Check Firestore rules.');
      }
      rethrow;
    }
  }
}
