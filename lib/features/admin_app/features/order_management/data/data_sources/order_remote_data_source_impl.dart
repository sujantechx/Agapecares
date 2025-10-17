import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'order_remote_data_source.dart';

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  // Keep a getter for convenience; we primarily read orders via collectionGroup
  CollectionReference<Map<String, dynamic>> get _topLevelOrders => _firestore.collection('orders');

  @override
  Future<List<OrderModel>> getAllOrders() async {
    try {
      // Use collectionGroup to read orders stored under users/{userId}/orders as well as any top-level orders
      final snap = await _firestore.collectionGroup('orders').orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.message?.toLowerCase().contains('permission') == true) {
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
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName}) async {
    try {
      final ref = await _findOrderDocRefById(orderId);
      if (ref == null) throw Exception('Order not found: $orderId');
      await ref.update({
        'workerId': workerId,
        if (workerName != null) 'workerName': workerName,
        'orderStatus': 'assigned',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
